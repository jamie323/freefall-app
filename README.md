# Freefall

> Premium iOS gravity-flip puzzle game. Tap to flip gravity. Navigate obstacles. Leave a trail of spray-paint art. £2.99, no ads, no IAP, no lives.

**Status:** Stage 3 complete — assets being generated, build starting soon.

---

## Repo Structure

```
freefall-app/
├── assets/
│   ├── images/
│   │   ├── icon/              ← App icon (1024×1024 + variants)
│   │   ├── splash/            ← Launch screen
│   │   ├── worlds/
│   │   │   ├── world1-the-block/
│   │   │   ├── world2-neon-yard/
│   │   │   ├── world3-underground/
│   │   │   └── world4-static/
│   │   ├── ui/
│   │   │   ├── menu/
│   │   │   ├── world-select/
│   │   │   ├── level-select/
│   │   │   └── level-complete/
│   │   ├── player/            ← Sphere reference art
│   │   ├── obstacles/         ← Obstacle style references per world
│   │   └── goal/              ← Goal ring reference
│   └── audio/
│       ├── music/
│       │   ├── world1-the-block/
│       │   ├── world2-neon-yard/
│       │   ├── world3-underground/
│       │   └── world4-static/
│       └── sfx/               ← Gravity flip, death, goal, UI sounds
├── docs/
│   └── blueprint/
│       ├── BLUEPRINT.md       ← Full Opus Stage 3 blueprint
│       ├── CODEX_HANDOFF.md   ← Machine-readable spec for Codex
│       └── BRIEF.md           ← Stage 2 product brief
├── levels/
│   ├── world1/                ← Level JSON files (w1l01.json etc)
│   ├── world2/
│   ├── world3/
│   └── world4/
└── src/                       ← Xcode project (added in Stage 4)
```

---

## Build Stack
- Swift + SpriteKit + SwiftUI
- iOS 17+ / iPadOS 17+
- Portrait only
- No backend, no third-party packages, fully offline

## The 4 Worlds
| World | Name | Colour | Music | Levels |
|-------|------|--------|-------|--------|
| 1 | THE BLOCK | Cyan #00D4FF | Classic boom bap hip hop | 1-10 |
| 2 | NEON YARD | Green #39FF14 | Liquid drum & bass | 11-20 |
| 3 | UNDERGROUND | Orange #FF6600 | Classic jungle / breakbeat | 21-30 |
| 4 | STATIC | Purple #8B00FF | Dark minimal electronic | 31-40 |

## Price
£2.99 / $2.99 one-time. No ads. No IAP. No subscription. No lives. No energy.
