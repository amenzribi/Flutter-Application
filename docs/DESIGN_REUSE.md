# Design reuse notes (Milestone: premium design + auth redesign)

## Reused
- Firebase Auth / Firestore identity flow (unchanged)
- GoRouter auth guards and route paths
- Legacy color tokens (olive / gold / ivory / charcoal)
- Welcome photography: `web/assets/pg/p_login.webp` → `assets/images/p_login.webp`
- App mark: `web/icon-192.png` → `assets/images/app_icon_192.png`
- Arabic copy tone and CTA labels from legacy welcome/auth
- UI fonts: Tajawal + Reem Kufi (OFL), bundled locally

## Redesigned
- Theme system (tokens, light/dark ThemeExtension)
- Auth screen composition (premium scaffold / cards / fields)
- Authenticated placeholder inside AppShell foundation
- Motion (entrance, press) with reduced-motion respect

## Not reused for UI chrome
- Amiri Quran (reserved for Quran ayah surfaces later)
- Dense legacy HTML card grids / emoji seasonal chrome
- Guest mode (out of scope this milestone)
- Remote Google Fonts CDN at runtime
