# Firebase configuration notes (Barakah 40 Flutter)

## Project

- Display name: Barakah 40
- Project ID: `barakah-40-a5dac`
- Legacy project `barakah-40` is not used.

## Platform apps

| Platform | Application ID | Firebase App Id |
|---|---|---|
| Android | `com.nosa.barakah40` | `1:777586757700:android:4558ff671c6186d9102c11` |
| iOS | `com.nosa.barakah40` | `1:777586757700:ios:3d8af7e32253426c102c11` |
| Web | Flutter web | `1:777586757700:web:380e658c6813f1ca102c11` |

## Android debug SHA (from `./gradlew signingReport`)

Package: `com.nosa.barakah40`

- SHA-1: `98:F6:05:22:20:21:BD:CE:9C:93:94:3B:A6:CF:BD:82:13:F2:15:2F`
- SHA-256: `D8:45:E0:15:2D:C5:4B:6A:96:40:B3:A4:B6:07:02:75:A1:05:06:C1:02:33:30:7E:E9:08:DE:11:4B:7A:0F:2D`

Add under: **Project settings → General → Your apps → Android app (`com.nosa.barakah40`) → SHA certificate fingerprints**.

## Rules

- Source: `firestore.rules` (mirror: `firestore.rules.proposed`).
- Covers private user state plus profiles, email lookup, friend requests,
  friendships, direct conversations and challenges. See
  `docs/SOCIAL_DATA_MODEL.md`.
- No composite indexes are needed.
- Emulator tests (35 passing), from the repo root:

  ```
  firebase emulators:exec --only firestore --project demo-barakah \
    "cd firebase && npm run test:rules"
  ```

- **The deployed project still has the old owner-only rules, so friends,
  chat and challenges are denied in production until these rules are
  deployed.** Deploy only after explicit approval:

  ```
  firebase login
  firebase deploy --only firestore:rules --project barakah-40-a5dac
  ```

  Rules apply to new requests only. They do not touch existing data, so no
  migration or backup is needed. To roll back, redeploy the previous file
  from git (`git show barakah:firebase/firestore.rules`).

## Running the app against local emulators

Nothing reaches the real project in this mode.

```
firebase emulators:start --only auth,firestore --project barakah-40-a5dac
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

Auth runs on port 9099 and Firestore on 8085 (see `firebase.json`). The flag
is ignored in release builds. Create test accounts from the app's sign-up
screen; they live only in the emulator.

## Console checklist before device testing

1. Authentication → Sign-in method → enable **Email/Password**.
2. Authentication → Sign-in method → enable **Google**.
3. Add Android SHA-1 / SHA-256 debug fingerprints (above).
4. Deploy the approved Firestore rules (see Rules above).
