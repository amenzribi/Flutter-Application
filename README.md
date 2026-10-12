# Barakah 40 (Flutter)

Flutter rebuild of the Barakah 40 web app: a 40-day Al-Baqarah reading
challenge with prayer tracking, an achievements tree, friends, private chat
and group challenges. Arabic, right-to-left.

## Run

```
flutter pub get
flutter run
```

Firebase project: `barakah-40-a5dac` (see `firebase/README.md`). To develop
without touching it, run against the local emulators:

```
firebase emulators:start --only auth,firestore --project barakah-40-a5dac
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

## Test

```
flutter analyze
flutter test
firebase emulators:exec --only firestore --project demo-barakah "cd firebase && npm run test:rules"
```

## Docs

- `docs/SOCIAL_DATA_MODEL.md`: friends, invitations, chat, group challenges
  and their security rules.
- `docs/TREE_GROWTH.md`: how the achievements tree grows and wilts.
- `docs/DESIGN_REUSE.md`: reused design assets from the legacy app.
- `firebase/README.md`: project ids, rules deployment, console checklist.
