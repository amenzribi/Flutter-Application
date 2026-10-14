# Social data model: friends, chat and group challenges

The legacy web app (`Barakah40_Delivery/web/index.html`) had a directory,
friend requests, friendships and solo/duo/group challenges, but no chat. The
Flutter app keeps those concepts, closes the legacy security gaps, and adds
private chat and a discussion tab for group challenges.

Code: `lib/features/social/` (domain, Firestore repository, Riverpod
providers, screens). Rules: `firebase/firestore.rules`, tested by
`firebase/tests/firestore.rules.test.js`.

## Collections

| Path | Id | Who can read | Who can write |
|---|---|---|---|
| `users/{uid}` | auth uid | owner | owner |
| `profiles/{uid}` | auth uid | any signed-in user (get; list only in pages of 20 or fewer) | owner, fixed key set |
| `emailIndex/{email}` | lower-cased email | any signed-in user, `get` only | the user whose token carries that email |
| `friendRequests/{from}_{to}` | sender + recipient | the two parties | see "Invitations" below |
| `friendships/{low}_{high}` | the two uids, sorted | the two friends | created when an invite is accepted; either friend can delete |
| `conversations/{low}_{high}` | same id as the friendship | the two members | members, for `lastMessage`, `updatedAt`, `unread`, `names` only |
| `conversations/{id}/messages/{mid}` | auto | members | a member who is still a friend; immutable |
| `challenges/{cid}` | auto | members and invited friends | see "Group challenges" below |
| `challenges/{cid}/progress/{uid}` | member uid | members | that member only |
| `challenges/{cid}/messages/{mid}` | auto | members | members; immutable |

Every other path is denied.

### `profiles/{uid}`

`{uid, name, nameKey, username, createdAt, updatedAt, treeStage?, treeHealthy?}`

Written on sign-in by `socialSyncProvider`. `username` is derived from the
email's local part (`usernameOf`), lower-case `[a-z0-9._-]`. Search runs two
prefix queries (`username` and `nameKey`, 10 results each) and merges them.
`nameKey` is the name folded for search (`nameSearchKey`): lower case, Arabic
diacritics removed, and أ/إ/آ → ا, ة → ه, ى → ي, so "امينة" finds "أمينة".

### `emailIndex/{email}`

`{uid}`. Exact email search reads one document by key. It can never be
listed, so emails cannot be harvested. The legacy app stored emails in a
listable directory; that is gone.

## Invitations

One document per direction: `friendRequests/{from}_{to}`.

`status`: `pending`, `accepted`, `declined`, `cancelled`. Documents are never
deleted, so a request can be re-sent by flipping a closed one back to
`pending`.

| Action | Who | Rule |
|---|---|---|
| Send | sender | target profile exists, not already friends, no pending request the other way, not to self, server timestamps |
| Re-send | sender | the request is closed, and the same checks as sending |
| Cancel | sender | pending → cancelled |
| Decline | recipient | pending → declined |
| Accept | recipient | pending → accepted, in the same batch that creates the friendship (`existsAfter`) |

`sendFriendRequest` in the repository resolves the edge cases before it
writes:

1. Already friends: it returns `alreadyFriends` and writes nothing.
2. The other person already invited me: it accepts their invite
   (`acceptedTheirs`), so crossed invites never produce two documents.
3. My own request is already pending: it returns `alreadyPending`.
4. Otherwise it creates or re-opens my request.

Both sides watch `status == pending` queries, so pending, accepted and
cancelled states update live on both phones.

`acceptFriendRequest` re-reads the request first. If it is no longer pending
it either returns quietly (already accepted and friends, e.g. a double tap) or
reports that the invitation was cancelled or answered. If both people invited
each other at the same moment, so that both requests landed before either saw
the other's, accepting one also cancels the acceptor's own pending request in
the same batch, and lists hide any request from someone who is already a
friend, so no stale "pending" is left behind.

## Private chat

- The conversation id is the friendship id, so two friends always share one
  conversation, whoever opens it first.
- A message is `{senderId, senderName, text (1 to 2000 chars), createdAt}`,
  and `createdAt` must be the server time.
- Sending is one batch: the message, plus `lastMessage`, `updatedAt` and
  `unread.{other}` incremented on the conversation.
- Opening a chat sets `unread.{me}` to 0.
- Messages are read newest first with `limit(100)`, then shown oldest to
  newest in a reversed list anchored to the bottom.
- Delivery is never faked. A message written offline shows a clock and
  "جارٍ الإرسال" (`hasPendingWrites`) until the server accepts it. A rejected
  write puts the text back in the composer and shows the error. The tick
  means "accepted by the server", not "read".
- After an unfriend, the rules reject new messages and the composer is
  replaced by a notice. History stays readable to both members.

## Group challenges

This follows legacy behaviour: solo, duo or group, a 40-day goal, and a
progress row per member mirrored from the member's own 40-day grid. Groups
add a discussion tab.

Scoring is unchanged from legacy: a member's progress is the number of days
she has marked complete in her own 40-day grid (`days`, `percent = days/40`).
The row is a mirror of that grid, rewritten whole on every change, so marking
the same day twice can never count twice. The rules cap `days` at `goalDays`.
There is no end date or expiry, as in the legacy app; a member who reaches 40
shows 40/40.

**Invitations (new, replaces legacy direct adding).** Nobody joins a challenge
without accepting. `challenges/{cid}` carries `invited` (pending) and
`declined` (answered no) uid lists next to `members`. Challenges created before
this change have neither field and keep working.

| Action | Who |
|---|---|
| Create | anyone; the creator is the only member. A duo names one friend in `invited` |
| Invite | any member, one of **their own** friends, one at a time; 30 people at most (members + invited); a duo holds 2 |
| Accept | the invited friend: moves herself from `invited` to `members` |
| Decline | the invited friend: moves herself from `invited` to `declined`, so the others see the answer |
| Cancel an invitation | any member |
| Re-invite after a decline | any member (clears the decline) |
| Rename | owner |
| Remove a member | owner |
| Leave | any non-owner member (their own progress row is removed first) |
| Delete | owner ("leaving" as owner deletes the challenge after a confirmation). The app first deletes the progress rows and the discussion, which nobody could reach once the challenge document is gone |
| Post in discussion | members |

An invited friend can read the challenge document (name, inviter, type) to
answer the invitation, but not its progress or discussion until she accepts.
Invitations appear under "دعوات إلى تحديات" in the challenges tab, with a
badge on the tab.

## Indexes

None are needed beyond Firestore's automatic single-field indexes. Requests
use two equality filters, search uses a range on one field, and lists use
`array-contains` on one field (`members`, or `invited` for challenge
invitations).

## Known limits

- Exact-email search tells a signed-in user whether an email is registered.
  This is inherent to "find by email". Name and username search do not
  expose emails.
- A signed-in user can page through names and usernames 20 at a time. No
  emails or private state are exposed.
- `unread` counters are client-maintained. A member could tamper with the
  counters on their own conversation; that only affects badges.
- There is no blocking or reporting yet, and no push notifications for new
  messages or invites (the app must be open).
- A person appears in search only after signing in to the Flutter app once
  (that is when `profiles/{uid}` is written). There is no server function to
  create profiles for accounts that never open the app.
- The sender of a declined friend request is not told; the request simply
  leaves her "sent" list.
- Chat shows the latest 100 messages; older ones are not paged in yet.
