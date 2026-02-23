# Stage 1: Validation Research — Freefall
*Generated: 2026-02-22 | Model: Sonnet | Taurus*

---

## Greenlight Rationale

Physics puzzle games are a proven, massive category. Every top title — Angry Birds 2, Cut the Rope, World of Goo — has been aggressively monetised with ads, energy systems, or subscription paywalls. The genre is full of users but empty of quality premium options. Alto's Adventure ($4.99, no ads, no IAP) proved that iOS users pay for quality — 30M+ downloads, ~$3K/day revenue years after launch. The gap is not subtle. There is no clean, premium, offline-first physics puzzle game in the Top Charts right now. This idea was approved because the complaint volume is enormous, the wedge is obvious, and the build is squarely in Jamie's stack.

---

## Core Mechanic Statement ⚠️ LOCKED — carry into all future documents

> **The player taps anywhere on a portrait screen to instantly flip gravity on a small geometric shape, navigating it through handcrafted static obstacle courses to reach a glowing goal point — one mechanic, no time pressure, no energy, no ads.**

This is a puzzle-first gravity flip game. Not an auto-runner (that's Gravity Guy). Not a sandbox (that's Orbit). Levels are spatial puzzles where the player finds the right sequence of gravity flips to thread through obstacles. Precision and observation over speed and reflexes.

---

## Market Analysis

### Category Size
- **Puzzle games** = $12.2 billion global revenue in 2024, **+14% YoY** (devtodev, Jan 2025)
- Puzzle + Simulation = **20% of total App Store downloads** (asomobile, 2024)
- Physics puzzle is a sub-genre of puzzle — conservative slice estimate: 3-5% of category = **$365M–$610M/year** addressable

### Premium Game Opportunity
- Alto's Adventure: **$4.99 iOS, no ads, no IAP** — ~30M downloads, $1M+ in first weeks on iOS alone, still ~$3K/day years later
- Alto's Odyssey: **$1M+ revenue in first weeks** post-launch
- Premium one-time paid games consistently outperform F2P on iOS for quality indie titles with Apple editorial support
- **Every direct competitor we found is free.** Zero premium physics puzzle games in the top results.

### Trend Signal
- Subreddit r/iosgaming Feb 2024 thread: hundreds of upvotes asking for "casual iOS games you just buy once" — Tiny Bubbles (physics puzzle) is their #1 recommendation
- Reddit consistently surfaces "no energy, no ads, buy once" as the #1 desired feature in physics games
- World of Goo Remastered at ★2.97 — the backlash against subscription/paywall models is accelerating, not slowing

---

## Top Competitor Analysis

| App | Stars | Reviews | Price | Main Weakness |
|-----|-------|---------|-------|---------------|
| Cut the Rope: Physics Puzzle | ★4.76 | 276,923 | Free (ads) | Ad-heavy, energy system |
| Angry Birds 2 | ★4.63 | 1,498,447 | Free (F2P) | Predatory IAP, pay-to-win, ad walls |
| Orbit - Playing with Gravity | ★4.85 | 7,162 | Free + $2.99 unlock | IAP popups, not enough levels, sandbox locked |
| Dune! (Voodoo) | ★4.54 | 540,914 | Free (ads) | Pure hypercasual, no depth |
| World of Goo Remastered | ★2.97 | 209 | Free (Netflix sub req.) | Requires Netflix subscription, rage everywhere |
| Cut the Rope Remastered | ★4.19 | 504 | Free (sub) | Crashes, ugly 3D art, broken iCloud saves |
| Gravity Guy (Miniclip, 2010) | N/A | Legacy | Free | Abandoned, auto-runner not puzzle, dated |

### Critical Observation
**Orbit - Playing with Gravity is the most direct competitor.** It's a gravity mechanic game, ★4.85, 7,162 reviews, free with a $2.99 unlock. Its bad reviews are telling: IAP popups, only 45 levels (too easy), sandbox locked behind IAP, no landscape on iPad. This is exactly our entry point — a premium version of what Orbit does badly.

---

## Competitor Feature Mining — What They Get RIGHT

| App | Feature Worth Taking / Beating |
|-----|-------------------------------|
| Cut the Rope (original) | One mechanic, consistent visual identity, satisfying completion animation |
| Alto's Adventure | Premium price point works, minimal UI, meditative pacing, Apple editorial relationship |
| Orbit | Gravity mechanic validated with real users (★4.85 on F2P = would easily hold ★4.8 as premium) |
| Dune! | Frictionless onboarding — no tutorial, player discovers mechanic by playing |
| World of Goo (original) | Tactile physics feel, cohesive art direction, memorable UI sounds |

---

## Feature Baseline

### Table Stakes (every competitor has this — context only, not requirements)
- Physics engine with realistic object behaviour
- Level progression (numbered levels, locked until previous complete)
- Retry on death
- Sound effects + music

### Best Features Worth Taking / Improving
- **One-mechanic discovery** (Alto, Dune): no tutorial screen — level 1 teaches the mechanic by playing it
- **Satisfying completion moment** (Cut the Rope): audio + visual pop when you hit the goal
- **Cohesive visual identity** (Alto, World of Goo): every screen feels like the same world
- **Meditative pacing** (Alto): no pressure, calm, the opposite of Angry Birds frantic energy

### Differentiation Opportunities (competitors do this badly)
- **Premium, no ads** — literally nobody in this space is doing it right now
- **Offline first** — Cut the Rope Remastered breaks offline; ours never requires internet
- **Portrait + one-thumb** — Orbit users beg for this and it's already broken
- **60+ levels at launch** — Orbit's 45-level complaint is a low bar to clear
- **Geometric/minimal 2D art** — Users despise the 3D remasters, want original aesthetic

### Potential Additions (Opus can take or leave any of these)
- Endless mode (after completing all levels — infinite procedural generation)
- Level creator / share levels (could be a later version feature)
- iCloud sync for level progress
- Haptic feedback on gravity flip
- Daily challenge level
- Ghost replay (see your best run as a ghost)

*These are suggestions drawn from research. Opus should challenge, cut, add to, or rethink any of this. We want your best thinking — not a rubber stamp on ours.*

---

## Revenue Scenarios

**Model:** $2.99 one-time purchase on iOS (no ads, no IAP, no subscription)
*Comparable: Alto's Adventure $4.99 — we go lower to reduce friction at launch, can raise to $3.99 post-reviews*

| Scenario | Downloads/Month | Monthly Revenue | Annual Revenue | Trigger |
|----------|----------------|-----------------|----------------|---------|
| **Conservative** | 500 | ~$1,050 (after Apple 30%) | ~$12,600 | Organic only, no feature |
| **Moderate** | 2,500 | ~$5,250 | ~$63,000 | Some ASO traction, word-of-mouth |
| **Optimistic** | 15,000+ | ~$31,500 | ~$378,000 | Apple editorial feature (Today tab) |
| **Spike (Apple feature)** | 50,000 in 1 week | ~$105,000 | — | "Game of the Day" or Design Award nomination |

**Apple Feature Probability:** Higher than most indie games because:
1. Premium paid = Apple loves (they highlight paid games in editorials)
2. No ads, no IAP = fits Apple's preferred narrative for quality
3. Geometric minimal art = Apple Design Award aesthetic
4. Made-for-iPhone portrait = demonstrates iOS-native thinking

---

## Build Estimate

**Stack:** Swift + SpriteKit, no third-party dependencies

| Component | Estimate |
|-----------|----------|
| Core gravity flip mechanic + collision | 3-5 days |
| Level design system (JSON/plist levels) | 2-3 days |
| 40 levels (design + implement) | 10-14 days |
| Art + UI (geometric minimal style) | 4-5 days |
| Sound design (flip SFX, goal SFX, ambient) | 2-3 days |
| Polish, haptics, screen transitions | 2-3 days |
| TestFlight + App Store submission | 2-3 days |
| **Total** | **~4-5 weeks solo** |

**Risk factors:**
- Physics tuning can be a rabbit hole — time-box it (1 week max on feel)
- Level design is deceptively time-consuming — 40 levels = real work
- App Review: games go through faster lane, usually 1-3 days

---

## Biggest Risk

**Discoverability.** Premium paid apps get no algorithmic push — no "free" hook for casual browsers. Mitigation: App Store search ads on "physics puzzle no ads", "gravity game premium", "puzzle game one time" keywords + pitch Apple directly for editorial (they respond to premium indie devs). TikTok virality angle: "The physics game with no ads that actually respects you" — this kind of content spreads.

---

## GO / MAYBE / NO

# ✅ GO

- Market is enormous and growing
- Every competitor monetised themselves into user hatred
- Premium model is proven and unoccupied in this specific niche
- Build is squarely in Jamie's stack (SpriteKit, Swift, no backend)
- Apple editorial is a real pathway given premium + no-ads model
- Pain Intel is devastating — 316 bad reviews basically write our App Store description for us
