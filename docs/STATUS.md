# Project status and test report

Last updated: 12 October 2026. Branch: `claude/project-thread-820u55`
(built on PR branch `claude/project-thread-u834d2`, not pushed).

## Where the project stands

Done and verified: sign-up, sign-in, profiles and search, friend
invitations, private chat, group challenges with discussion, challenge
invitations, the 40-day challenge grid, Quran reader, prayer tracking, the
achievements tree, adhkar (morning/evening), duas, qibla with tasbih and
mosque duas, journal and daily intention, settings (name, password, sign
out, delete account, help/about/privacy/terms/contact, restart), and the
Firestore security rules for all of it. No screen says "قريباً" any more.

Not migrated from the legacy app (deliberately left for after first users):
achievement stories, themes, English, profile photos, adhan audio,
reminders/push notifications, backup export/import.

**Blocking production use of the social features:** the live project
`barakah-40-a5dac` still runs the old owner-only rules. Until
`firebase deploy --only firestore:rules --project barakah-40-a5dac` is run
by the owner, search, invitations, chat and challenges are refused in
production. See `firebase/README.md`.

**Next milestone:** first users (checklist below), then reminders and push
notifications for invites and messages.

## Ready for first users: checklist

Owner actions, in order:

1. `firebase login`, then
   `firebase deploy --only firestore:rules --project barakah-40-a5dac`.
2. Firebase Console → Authentication → Sign-in method: Email/Password and
   Google enabled; Authentication → Settings → Authorized domains include
   the domain the web app is served from.
3. Firebase Console → Authentication → Templates: check the sender name of
   the "verify email" message (users must confirm their email before their
   progress syncs; unconfirmed progress stays on the device).
4. Build and publish: `flutter build web --release` (host the `build/web`
   folder, e.g. Firebase Hosting), or `flutter build apk --release` for
   Android testers.
5. With two of your own accounts on the live app, run tests 1–15 of the
   table below once.
6. Invite a small group; ask them to report problems through "تواصل معنا".

Known limits to tell testers: no notifications (keep the app open to see
new messages), the compass needs a phone (computers show the angle only),
and adhkar counters do not reset daily (legacy behaviour, pending decision).

## Second round (adhkar, qibla, settings)

| Problem | Cause | Fix |
|---|---|---|
| Qibla pointed the wrong way for cities chosen by name (Tripoli: 64° instead of 109°) | The legacy lookup, Aladhan `timingsByCity` metadata, now returns placeholder coordinates for every city | City coordinates from Open-Meteo geocoding; prayer times by city still come from Aladhan, checked identical |
| Deleting an account left its email lookup entry | Re-confirming the password refreshed the user, which republished the profile mid-delete | Social identity compares by value, so a refresh is a no-op; retested: everything removed |
| Qibla buttons announced as checkboxes to screen readers | Material chips | Plain outlined buttons |

Executed in the browser against the emulators (account B, then throwaway
accounts D and E): adhkar counting with cap and "−", Quranic adhkar text
loading, sync to the cloud (checked in DB); qibla by city (corrected
coordinates checked in DB); tasbih count saved (checked in DB); duas list;
intention and journal saved; name change reaching the search profile
(checked in DB); account deletion removing user data, profile, email lookup,
login, and cancelling the account's pending invitation (checked in DB).
Not executed: compass rotation (needs a phone), change password, restart
challenge in the browser (both covered by unit tests or code review only),
Android build.

## Fixes in this round

| Problem | Cause | Fix |
|---|---|---|
| A "pending" invitation stayed behind after two people invited each other at the same moment | Accepting one request left the other side's request open | Accepting also cancels the acceptor's own pending request in the same batch; lists hide requests from existing friends |
| Tapping "قبول" twice showed an error although the friendship was made | The second write hit an already-accepted request | Accept re-reads the request: quiet if already accepted, clear message if cancelled |
| A member could store any number as her challenge progress | The rules did not check the progress row | Rules require the legacy shape and cap `days` at the challenge goal |
| Friends were put into challenges without being asked | Legacy behaviour (direct adding) | Invitations: invited friends accept or decline; members can cancel; decline is visible to the others |
| Deleting a challenge left its discussion and progress behind, unreachable | Only the challenge document was deleted | The owner's delete clears progress and messages first |
| Email/password accounts never synced progress to the cloud | The legacy rule (confirm email before syncing) was ported, but the confirmation step was not | Home screen shows the legacy "confirm your email" notice with "send link" and "I've confirmed"; a link is sent at sign-up; held-back progress syncs as soon as the email is confirmed |
| Uncaught error in the browser console at start-up | Google Sign-In plugin was created on web without a client id | Created only on Android/iOS; web uses the Firebase popup |
| An emulator test build could send sign-ins to the real project after a page reload | The Firebase JS SDK refreshed the stored session against the real endpoint before the app switched to the emulator, which then never connected | Emulator builds on web start without a stored session (sign in again after reloading while testing) |
| Accepting a challenge invitation did not open the challenge | The row was gone before navigation | Navigation captured before the write |

## Automated results

| Suite | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 259 passed (includes adhkar/duas content, qibla maths and city matching, tasbih, journal, restart; earlier new tests for crossed and repeated invitations, challenge invite/accept/decline/cancel, owner delete clean-up, email-confirmation flag) |
| Firestore rules (`firebase/tests`) on the emulator | 41 passed (new: challenge invitations, duo size, progress bounds, owner clean-up, old challenges still work, crossed accept) |

## Manual run (executed)

Environment: local Auth and Firestore emulators, the web build served on three
ports so each Chrome tab is a separate signed-in account. Accounts: A
"اختبار أمينة" (registered through the sign-up screen), B "اختبار هدى",
C "اختبار سارة". A–B and B–C became friends; A–C are not friends.
"Checked in DB" means the result was read back from the emulator database,
not just seen on screen.

| ID | Feature | Accounts | Steps | Expected | Actual | Result |
|---|---|---|---|---|---|---|
| 1 | Register, login, session | A, B | Submit empty sign-up; sign up A; log in B with a wrong then the right password; reload | Validation and error messages in Arabic; home opens; still signed in after reload | Messages shown ("كلمة المرور غير صحيحة"); home opened. After a full reload in emulator mode the session is dropped on purpose (see fixes) | Pass (sign-up/login). Reload: not tested against production |
| 2 | Search | A, B, C | Search "اختبار هد", "@test.hu", "TEST.Amina@…" (mixed case), "اختبار ساره" (ه for ة), own email | Matching user with name and @username only; no emails; self never listed | All found; only name and @username shown; own email gave "no results" | Pass |
| 3 | Send and receive an invitation | A → B | A taps "إضافة" | A sees "طلبات مرسلة (1)"; B's tab badge updates without reload | Request stored as pending (checked in DB); B's badge "المجتمع، 1 جديد" appeared live | Pass |
| 4 | Accept, both friend lists | B | B taps "قبول" twice quickly | One friendship; both lists show it | B "صديقاتي (1)", A's row changed to "صديقة" live; no error from the double tap | Pass |
| 5 | Decline and cancel | C → A | C sends, then cancels; C sends again, A declines | A's incoming list empties on cancel; C's sent list empties on decline | Both happened live on the other tab | Pass |
| 6 | Self and duplicate | C; unit/rules | Search own email; duplicate sends covered by tests | No self result; no second request | Self excluded live; duplicates and simultaneous invites pass in unit and rules tests | Pass (duplicate/simultaneous: automated) |
| 7 | Messages both ways | A, B | A sends; B replies with a 249-character message | Real-time on both; "أُرسلت" after server accepts; correct order | Both arrived live in order; B saw unread "1" and preview first | Pass |
| 8 | Persistence | A | Full page reload, reopen chat | Messages still there | Both messages present after reload | Pass |
| 9 | Third user and private chat | C | Open A–B chat link; direct database read/write as C | Refused | App shows "لا يمكن فتح هذه المحادثة"; database read and write both 403 | Pass |
| 10 | Challenge invite and accept | A → B | A creates a duo with B; B accepts | B joins only after accepting; both progress rows created | Pending invite then member (checked in DB); badge on B's challenges tab | Pass |
| 11 | Progress for both | B, A | B marks day 1 in the 40-day grid | A sees B at 1/40 | Row days=1 (checked in DB); A's progress tab "اختبار هدى 1/40" | Pass |
| 12 | Decline and cancel a challenge | A, B | A creates a second duo, B declines; A invites B to a group, cancels, re-invites | Both see the same state | A's list showed "اعتذرت اختبار هدى عن التحدّي"; cancel and re-invite reflected on both | Pass |
| 13 | Group messages | A, B, C | B joins group, invites her friend C; C joins; A and C post | Live for all members | Messages arrived live in both tabs | Pass |
| 14 | Non-member access | C | While only invited, and after leaving: read and post messages directly | Refused | Invited: challenge header readable, messages and progress 403. After leaving: header, messages and posting all 403 | Pass |
| 15 | Tree and activity persistence | B | Mark day 1; reload; confirm email | Points kept; synced to cloud after confirmation | Tree 15 points, stage 3 before and after reload; after confirming, status "تمّت المزامنة" and the cloud copy holds the day and tree (checked in DB) | Pass |
| 16 | Arabic/RTL, mobile, errors, connection | all | 430×860 viewport throughout | RTL layout, Arabic messages | Arabic and RTL text throughout at phone width; error messages in Arabic. Offline send/recovery and other screen sizes not exercised | Partly tested |

## Not verified here

- Anything against the live project: the rules are not deployed, and this
  computer is not signed in to the Firebase CLI.
- Session persistence after reload in production (only the emulator case
  was run, where it is dropped on purpose).
- Offline sending and reconnection (the code shows a clock until the server
  accepts, but no outage was simulated).
- Android emulator or device runs; pixel-level comparison with the legacy
  screens (the browser pane available for testing was too small for
  meaningful screenshots).
- Google sign-in.
