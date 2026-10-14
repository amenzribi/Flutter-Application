# Stage 1 audit (14 October 2026)

Branch `claude/project-thread-820u55`, 8 commits ahead of `barakah`, not
pushed. Only uncommitted changes: the generated plugin registrant files for
Linux/macOS/Windows (produced by `flutter pub get`, left untouched).

## Environments

| | Project | Used for |
|---|---|---|
| Live | `barakah-40-a5dac` (the app's `firebase_options.dart`) | Nothing in this audit. The Firebase CLI on this computer is not signed in, so the deployed rules could not be read or changed. |
| Test | Local Auth + Firestore emulators (ports 9099 / 8085), same project id, current `firebase/firestore.rules` | All tests below. Test accounts exist only here. |

## How things were checked

1. `flutter analyze`: no issues.
2. `flutter test`: 259 passed (unit and widget tests, in-memory database).
3. Firestore rules tests (`firebase/tests`, emulator): 41 passed.
4. **New end-to-end suite** `e2e/social_e2e_main.dart`: the app's own social
   code in Chrome against the emulators with the real rules, three
   separately signed-in users created fresh per run. Final run
   (`run 1791988176984`): **10 passed, 0 failed**.
5. Earlier in-browser runs of the real app screens (12–13 October) and
   database reads of the results, recorded in `docs/STATUS.md`.
6. Side-by-side look at the original `Barakah40_Delivery` web app and the
   Flutter app (screenshots, 420 px wide).

## Requirements checklist

| # | Requirement | Implemented | How verified | Status |
|---|---|---|---|---|
| 1 | Registration | Email/password sign-up with name; Google sign-in; email confirmation link sent | In-app sign-up with validation errors (12 Oct); unit tests | Verified (Google sign-in not tested) |
| 2 | Login, wrong password, logout | Arabic error messages; logout from home and settings | In-app (12 Oct); unit tests | Verified |
| 3 | Session after refresh | Firebase local persistence (production); emulator builds deliberately start signed-out | Emulator only: by design not persisted. Production refresh not tested | **Not tested (live)** |
| 4 | User profile | `profiles/{uid}` (name, search key, @username, no email) written on sign-in; name edit in settings updates it | e2e #1; in-app name change checked in DB (13 Oct) | Verified |
| 5 | Search | Exact email, @username prefix, Arabic-normalised name prefix; self excluded; email never returned; email index cannot be listed | e2e #1 | Verified |
| 6 | Send / receive invitation | `friendRequests/{from}_{to}`, live on both sides | e2e #2 (receipt via live listener) | Verified |
| 7 | Accept; both friend lists | Accept + friendship in one batch; double tap harmless | e2e #2 | Verified |
| 8 | Decline / cancel | Status changes, other side updates live, re-send allowed | e2e #3 | Verified |
| 9 | Duplicate / self / third-party | Duplicate → "already pending"; self refused; a third user cannot accept or read the request (app check and rules) | e2e #2 | Verified |
| 10 | Simultaneous invitations | One friendship, nothing left pending | e2e #4 — **failed first, fixed** (see below) | Verified after fix |
| 11 | Private chat, real time, persistence | One conversation per pair; live both ways; long text; order; unread/preview; history in a new session; offline shows a clock until sent | e2e #5; in-app (12 Oct) | Verified (offline send not tested) |
| 12 | Chat privacy | Non-participant cannot read, post or open the conversation | e2e #5; REST check (12 Oct) | Verified |
| 13 | Group channels | Group challenges with discussion; members invite their own friends; accept/decline/cancel; leave; owner removes/deletes | e2e #8 | Verified |
| 14 | Group privacy | Invited-but-not-joined and former members cannot read or post (checked against the server) | e2e #8 | Verified |
| 15 | Friend challenges | Duo invite → accept/decline/cancel; shared 40-day progress; same view for both; repeated submissions do not double-count; rules cap progress at 40 and forbid writing another's row | e2e #6, #7 | Verified |
| 16 | Challenge results / expiry | Progress per member (days/40). The original app has no end date, expiry or winner; none was invented | Code review against the original | Verified (as original) |
| 17 | Spiritual activities → tree | Quran days, prayers, adhkar, tasbih record activity and points (legacy rules); syncs to the cloud after email confirmation | In-app + DB (12–13 Oct); 22 tree unit tests | Verified |
| 18 | Tree look and animation | 20 legacy stage images (stone planter, warm light), breathing photo, golden motes, cross-fade, reduced-motion respected | Screenshot (13 Oct); code review | Verified (visual) |
| 19 | Adhkar, duas, qibla, tasbih, journal, settings, account deletion | Built 12–13 Oct | In-app + DB; e2e #10 (deletion) | Verified (compass rotation needs a phone) |
| 20 | Private user data | `users/{uid}` owner-only | e2e #9 | Verified |
| 21 | Original design | Colours, fonts (Reem Kufi, Tajawal, Amiri), photos, cards, period backgrounds, tree images kept | Side-by-side screenshots | **Partly** — see design differences |
| 22 | Arabic / RTL | App locked to Arabic, right-to-left | Every screen used in testing; code (`app.dart`) | Verified |
| 23 | Responsive screens | Phone-width layouts | Tested at 400–532 px wide only | **Partly tested** (no small 320–360 px phone, no tablet) |
| 24 | Firebase rules | Current file covers all features; 41 rule tests + e2e | Emulator | Verified locally; **not deployed** |
| 25 | Indexes | None needed: equality-only and single-field queries | Code review; emulator does not enforce indexes | Not verifiable until live |
| 26 | Firebase config / access | One project for web, Android, iOS (`firebase_options.dart`, `google-services.json`) | Code review | Unchanged; CLI not signed in |

## Defects found in this audit

| Defect | Cause | Fix | Re-check |
|---|---|---|---|
| If two people press "إضافة" for each other at the same instant, one of them got an error ("لم يُسمح بهذا الإجراء") | The second write is correctly refused by the rules because a request the other way already exists; the app reported the refusal instead of resolving it | On that refusal the app looks again and accepts the other person's invitation (`firestore_social_repository.dart`) | e2e #4 passes; 259 unit tests pass |

The other failures seen while building the e2e suite were in the test
harness, not the app (cached first readings, a deleted challenge being
unreadable to everyone, timer throttling in a hidden browser tab).

## Design differences from the original (decision needed)

The look (colours, typography, photography, cards, tree) matches. The
structure differs in two places, which predate this audit:

1. **Bottom navigation.** Original: 7 tabs — الرئيسية، التحدّي، القراءة،
   الأذكار، الصلاة، القبلة، الأدعية. Flutter: 5 tabs — الرئيسية، التحدّي،
   القراءة، الصلاة، المجتمع. Adhkar, qibla and duas are reached from the home
   grid.
2. **Home page.** Original: day-period greeting, a large 40-day progress ring
   with "تمت قراءة اليوم", the quick grid, "تأمّل اليوم", a second grid
   (friends, stories, journal) and "ادعي صديقاتك". Flutter: the tree card at
   the top, an account card, a 40-day card, the grid, then summary cards
   (streak, Quran, last reading, prayers, adhkar).

## Remaining blockers and limits

- **Live rules not deployed** (needs your `firebase login` + deploy). Until
  then friends, chat and challenges are refused on the live project.
- Not tested: session persistence and anything else on the live project;
  Google sign-in; offline sending; compass rotation; screens narrower than
  400 px; Android/iOS builds.
- No push notifications; achievement stories, themes, English, adhan audio
  not migrated; adhkar counters never reset (original behaviour, your
  decision pending).
