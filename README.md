# FREEFALL

> Premium iOS gravity-flip arcade game. Tap to flip gravity. Navigate obstacles. Collect items. Chase high scores across 8 worlds. No ads, no IAP, no lives.

## Game Overview

Players control a glowing sphere that moves horizontally at a fixed speed. The only input is **tap to flip gravity** — the sphere alternates between falling down and falling up. Navigate through obstacle-filled levels, collect items for bonus points, and reach the goal circle at the end.

**Core loop:** Launch → dodge obstacles → collect items → reach goal → earn stars → unlock next level.

**Content:** 8 worlds × 10 levels = 80 levels, with logarithmic difficulty scaling based on flow theory. Each world has unique physics that fundamentally changes how the game feels. Estimated 30+ minutes of content for a skilled player, hours for completionists chasing 3 stars.

**Price:** One-time purchase. No ads. No IAP. No subscription. No lives. No energy.

---

## Tech Stack

- **Swift + SwiftUI** — Navigation, menus, overlays, settings
- **SpriteKit** — 2D physics engine, rendering, particle effects
- **AVFoundation** — Music crossfading, SFX playback
- **UserDefaults** — Score persistence, progression, settings
- **iOS 17+** — `@Observable` macro (Observation framework)
- No third-party packages. Fully offline.

---

## Architecture

```
FreefallApp (entry point)
  └── ContentView (NavigationStack coordinator)
        ├── MainMenuView
        ├── WorldSelectView → LevelSelectView
        │     └── GameView (SwiftUI overlay layer)
        │           └── SpriteKitView (UIViewRepresentable)
        │                 └── GameScene (SKScene — physics, rendering, effects)
        ├── LevelCompleteView
        ├── IntermissionView → IntermissionScene
        └── SettingsView
```

**Key architectural decisions:**
- SpriteKit embedded in SwiftUI via `UIViewRepresentable` with a `Coordinator` pattern
- `SceneProxy` holds a stable reference to the SpriteKit scene without triggering SwiftUI redraws
- `@Observable` GameState is the single source of truth for all progression data
- Level definitions are JSON files loaded at runtime via `LevelLoader`
- World physics configs are compile-time constants in `WorldDefinition.swift`

---

## Project Structure

```
Freefall/
├── FreefallApp.swift              # App entry point
├── ContentView.swift              # Navigation coordinator + AppDestination enum
├── GameState.swift                # Observable state: scores, completion, persistence
│
├── Game Engine
│   ├── GameScene.swift            # Main SpriteKit scene (~1000 lines)
│   ├── GameScenePhysics.swift     # SKPhysicsContactDelegate (collisions)
│   ├── SpriteKitView.swift        # UIViewRepresentable bridge
│   ├── GameView.swift             # SwiftUI overlay: HUD, pause, transitions
│   ├── IntermissionScene.swift    # Bonus dodge-challenge minigame
│
├── Definitions
│   ├── WorldDefinition.swift      # 8 worlds + PhysicsConfig structs
│   ├── LevelDefinition.swift      # JSON level parser + LevelLoader
│
├── Scene Nodes
│   ├── ObstacleNode.swift         # Rect/circle/polygon/line obstacles
│   ├── CollectibleNode.swift      # Pulsing collectible items
│   ├── TrailNode.swift            # Gradient path trail behind sphere
│   ├── TrailSprayNode.swift       # Particle scatter effect
│
├── UI Views
│   ├── MainMenuView.swift         # Main menu with ambient animations
│   ├── WorldSelectView.swift      # World cards with lock/unlock
│   ├── LevelSelectView.swift      # 3-column level grid with stars
│   ├── LevelCompleteView.swift    # Animated results screen
│   ├── SettingsView.swift         # Toggles + scoring guide
│   ├── IntermissionView.swift     # Bonus challenge wrapper
│
├── Audio
│   ├── AudioManager.swift         # Music + SFX with crossfading
│
├── Utilities
│   ├── Color+Hex.swift            # Color.hex("#FF0000") extension
│
├── Assets.xcassets/
│   ├── AppIcon.appiconset/        # App icons
│   └── world{1-8}-bg.imageset/    # Background images per world
│
├── audio/
│   ├── music/
│   │   ├── menu/                  # Menu music
│   │   ├── intermission/          # Bonus challenge music
│   │   └── world{1-8}-*/          # 2 tracks per world (A: L1-5, B: L6-10)
│   └── sfx/
│       ├── flip.wav               # Gravity flip sound
│       ├── death.wav              # Collision sound
│       ├── collectible.wav        # Item pickup
│       ├── close-call.wav         # Near miss
│       ├── level-start.wav        # Level begins
│       ├── level-complete.wav     # Goal reached
│       ├── all-collected.wav      # All items collected
│       └── record-scratch.mp3     # Completion screen reveal
│
└── levels/
    └── world{1-8}/
        └── w{X}l{01-10}.json     # 80 level definitions total
```

---

## Game Mechanics

### Gravity Flip (Core Mechanic)

Tap anywhere to invert gravity direction.

- **Momentum carry:** 30% of current vertical velocity carries into the new direction (pendulum feel)
- **Flip impulse:** Instant velocity boost in the new gravity direction (world-specific: 30-60)
- **Vertical damping:** Per-frame friction on vertical velocity (world-specific: 0.0-0.04)
- **Max velocity:** Hard cap prevents runaway speed (world-specific: 120-240)
- **Horizontal velocity:** Constant per level (120-250), never changes during play

### Scoring System

| Source | Points | Notes |
|--------|--------|-------|
| Level complete | +200 | Flat bonus |
| Speed bonus | 0-300 | Based on par time ratio |
| Collectibles | +50 each | With combo multiplier (×1.0, ×1.5, ×2.0) |
| All collected | +100 | Bonus for getting all 3 |
| Close call | +25 | Near-miss within 20pt of obstacle |
| Trail distance | ~1/unit | Passive distance scoring |

### Star Rating

| Stars | Requirement |
|-------|------------|
| 0★ | Not completed |
| 1★ | Level completed (any score) |
| 2★ | 350+ points |
| 3★ | 550+ points |

Maximum: 240 stars (8 worlds × 10 levels × 3 stars).

### Progression

- Levels unlock sequentially within a world
- Completing all 10 levels in a world unlocks the next world
- Best scores persist per level via UserDefaults
- Intermission bonus challenges appear after levels 5 and 10

### Close Call System

- Triggers when sphere passes within 3-20pt of an obstacle edge
- One-time per obstacle per attempt
- Awards +25 points + yellow spark particles + haptic feedback

### Combo System

- Each collectible increments combo counter
- Multiplier: ×1.0 (1st), ×1.5 (2nd), ×2.0 (3rd)
- More particles spawn at higher combos

---

## The 8 Worlds

| # | Name | Physics Feel | Gravity | Impulse | Max Vel | Damping | Color |
|---|------|-------------|---------|---------|---------|---------|-------|
| 1 | THE BLOCK | Floaty, forgiving | 50 | 35 | 140 | 0.020 | Cyan #00D4FF |
| 2 | NEON YARD | Snappy, twitchy | 65 | 48 | 180 | 0.008 | Lime #39FF14 |
| 3 | UNDERGROUND | Heavy, sluggish | 75 | 32 | 130 | 0.030 | Orange #FF6600 |
| 4 | STATIC | Wild, precise | 70 | 42 | 200 | 0.005 | Purple #8B00FF |
| 5 | GLASS | Slippery, momentum | 40 | 30 | 220 | 0.000 | Ice blue #A0E7FF |
| 6 | FURNACE | Explosive, short hops | 95 | 60 | 120 | 0.040 | Red #FF2200 |
| 7 | VOID | Inverted gravity start | 60 | 38 | 170 | 0.012 | Magenta #CC00FF |
| 8 | MAINFRAME | Brutal precision | 85 | 45 | 240 | 0.003 | Neon green #00FF88 |

Each world has its own color palette, background art, two music tracks (A for levels 1-5, B for levels 6-10), and unique physics config.

**World 5 (GLASS):** Zero damping means the ball never slows vertically. Momentum carries. Ice-skating feel — you overshoot constantly and must learn to flip early.

**World 6 (FURNACE):** Extreme gravity (95) pulls hard, but huge impulse (60) launches you. Short explosive hops. Very deliberate — every flip is a committed move.

**World 7 (VOID):** All levels start with gravity pointing UP (`initialGravityDown: false`). Same mechanic, but mentally disorienting. Forces you to re-learn everything.

**World 8 (MAINFRAME):** Near-max gravity (85) + near-zero damping (0.003) + highest max velocity (240) = the ball moves fast and reacts violently. Expert-only.

---

## Difficulty Curve

Difficulty scales logarithmically across all 80 levels using flow theory:

```
t = ln(level_index + 1) / ln(80)    # 0.0 at level 1, 1.0 at level 80
```

| Parameter | W1L01 (easiest) | W4L10 (mid) | W8L10 (hardest) |
|-----------|----------------|-------------|-----------------|
| Obstacles | 1 | 5 | 8 |
| Velocity (dx) | 120 | 200 | 250 |
| Goal radius | 44 | 34 | 28 |
| Max rotation | 0° | 25° | 35° |
| Par flips | 2 | 6 | 9 |
| Par time | 3.2s | 1.8s | 1.2s |

Early levels ramp noticeably (each feels harder). Later levels ramp slower (player mastery keeps pace with difficulty increase).

---

## Visual Effects

- **Trail system** — Gradient-colored path following the sphere with scatter particles
- **Beat-reactive visuals** — Background pulses, sphere glows, obstacles breathe on the BPM
- **Death effect** — 14-particle burst + screen shake (8pt) + error haptic
- **Completion celebration** — White flash → shockwave ring → 60-particle explosion → 7 firework bursts (48 particles each) → triple haptic chain. 1.4-second spectacle.
- **Close call sparks** — 6 yellow particles on near-misses
- **Collectible burst** — Ring expansion + particle spray, scaling with combo multiplier
- **Background parallax** — Background tracks sphere movement at 20% speed

---

## Audio System

- **16 world music tracks** — 2 per world (A for levels 1-5, B for levels 6-10), looping
- **Menu + intermission tracks** — Dedicated music for non-gameplay screens
- **2-second crossfading** — Smooth transitions between tracks
- **Same-track deduplication** — Music doesn't restart between levels in the same world
- **8 SFX** — Deep, bassy sound design (gravity flip, death, collectible, close call, level start/complete, all collected, record scratch)
- **Beat timer** — BPM-driven visual pulses synced to each world's music tempo

---

## Level Format

Levels are JSON files using normalized coordinates (0.0-1.0 relative to screen size):

```json
{
  "worldId": 1,
  "levelId": 1,
  "launchPosition": { "x": 0.08, "y": 0.5 },
  "launchVelocity": { "dx": 120, "dy": 0 },
  "goalPosition": { "x": 0.9, "y": 0.5 },
  "goalRadius": 44,
  "initialGravityDown": true,
  "parFlips": 2,
  "parTime": 3.2,
  "obstacles": [
    {
      "id": "obs-1",
      "type": "rect",
      "position": { "x": 0.5, "y": 0.5 },
      "size": { "width": 0.04, "height": 0.18 },
      "rotation": 0,
      "style": "solid"
    }
  ],
  "collectibles": [
    { "position": { "x": 0.35, "y": 0.35 } }
  ]
}
```

Obstacle types: `rect`, `circle`, `polygon`, `line`. All levels include top-bar (y=0.06) and bottom-bar (y=0.94) boundary obstacles.

All obstacle/collectible placements are mathematically validated: minimum gaps of 2× ball diameter, no impossible routes, collectibles in open space with clearance.

---

## State & Persistence

**Persisted (UserDefaults):**
- `completedLevels` — Set of "W{X}L{Y}" strings
- `levelBestScores` — Dictionary of "W{X}L{Y}" → best score
- `worldScores` — Per-world cumulative scores
- `totalScore` — Global cumulative score
- `musicEnabled`, `sfxEnabled`, `hapticsEnabled` — Settings toggles

**Runtime:**
- `currentLevelScore` — Score in current level attempt
- `currentAttemptScore` — Tracks current attempt's contribution (for rollback on death)
- `gameplayState` — ready | playing | dead | complete | paused
- `isIntermissionActive` — Whether bonus challenge is showing

---

## Building

1. Open `src/Freefall/Freefall.xcodeproj` in Xcode 16+
2. Select an iOS 17+ simulator or device
3. Build and run (Cmd+R)

The `audio/` and `levels/` folders are included as folder references in Xcode — new files in these directories are automatically picked up on clean rebuild (Cmd+Shift+K then Cmd+B).

---

## Key Implementation Notes

- `opacity(0)` in SwiftUI does NOT disable hit testing — must use `.allowsHitTesting(false)`
- SpriteKit scene size is 0 on initial load — level setup deferred to `didChangeSize()`
- Music track deduplication prevents restarting same track on level transitions within a world
- Per-attempt score rollback on death prevents inflation of cumulative scores
- Seeded RNG (seed = worldId × 100 + levelId) ensures reproducible level generation
- `audio/` folder is a folder reference in Xcode (not individual file references) — new audio files appear on rebuild without manual adding
