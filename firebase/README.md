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

- Source: `firestore.rules`
- Proposed mirror: `firestore.rules.proposed`
- Emulator tests: `npm run test:rules` via `firebase emulators:exec --only firestore` (9 passing)
- **Do not deploy until explicitly approved.**

## Console checklist before device testing

1. Authentication → Sign-in method → enable **Email/Password**.
2. Authentication → Sign-in method → enable **Google**.
3. Add Android SHA-1 / SHA-256 debug fingerprints (above).
4. Deploy approved Firestore rules (owner-only `users/{uid}`).
