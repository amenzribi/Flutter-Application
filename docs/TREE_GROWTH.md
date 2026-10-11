# The achievements tree (شجرة الإنجازات)

The rules are an exact port of the legacy web app (`TREE_PTS`, `TREE_TH`,
`computeTreePoints`, `cappedStage`, `prayerWiltNow`, `treeDisplay`,
`treeHintFor`). Code: `lib/features/tree/domain/tree_growth_service.dart`.
Tests: `test/tree_growth_service_test.dart`.

## Points

Points are cumulative over the account's lifetime:

| Source | Points |
|---|---|
| Each prayer marked done, any day | 10 |
| Each 40-day challenge day marked complete | 15 |
| Reading position in Al-Baqarah (last ayah or audio position, out of 286) | up to 40 |
| Adhkar counted (first 400) | 0.4 each |
| Tasbih count (first 600) | 0.15 each |

## Stages

There are 20 stages, `grow1.webp` to `grow20.webp`. A stage is reached at
these point thresholds:

`0, 5, 12, 21, 32, 46, 62, 82, 105, 132, 162, 196, 234, 276, 322, 372, 426, 484, 546, 612`

The bar under the tree shows progress from the current threshold to the next.

## What the tree shows today

1. **Growth is gradual.** The shown stage climbs towards the earned stage by
   at most 1 stage a day. On a very active day (4 or more prayers, or a
   challenge day completed today) it can climb 2.
2. **First open.** An account that already has points shows its earned stage
   directly.
3. **Missed prayer, wilted.** If today's prayer times are known and a prayer
   window has closed without the prayer being marked, the same stage is shown
   wilted (`wiltN.webp`). Marking the prayer restores it. No growth is lost.
   Without today's prayer times the tree never wilts.
4. **A whole day without activity, dry seed.** If yesterday had no activity
   (prayer, reading, adhkar or tasbih) and none is logged yet today, the tree
   becomes a dry seed (wilted stage 1). The next activity wakes it, and it
   regrows from the seed at the normal daily pace.

Activity is recorded by the user-state controller when the user marks a
prayer, completes a challenge day, saves a reading bookmark or counts adhkar.
It is stored under the legacy `activity` and `tree` keys of `users/{uid}`, in
the same shape the web app used.

## Motion

The card keeps the cinematic photographs and adds restrained motion:

- a slow breathing scale on the photo (about 1.5% over 8 seconds);
- the legacy warm-glow pulse from above (5 seconds);
- a few golden motes drifting up through the light (only while healthy);
- a 1.2-second crossfade when the stage image changes, and the progress bar
  easing to its new value.

All of it stops when the system asks for reduced motion
(`MediaQuery.disableAnimations`).
