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
| `challenges/{cid}` | auto | members | see "Group challenges" below |
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

| Action | Who |
|---|---|
| Create | anyone; duo only with a friend |
| Add a member (groups) | any member, one of **their own** friends, one at a time, 30 members at most |
| Rename | owner |
| Remove a member | owner |
| Leave | any non-owner member (their own progress row is removed first) |
| Delete | owner ("leaving" as owner deletes the challenge after a confirmation) |
| Post in discussion | members |

Adding is direct, with no acceptance step, as in the legacy app.

## Indexes

None are needed beyond Firestore's automatic single-field indexes. Requests
use two equality filters, search uses a range on one field, and lists use
`array-contains` on one field.

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
