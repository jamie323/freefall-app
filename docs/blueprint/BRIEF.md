# BRIEF.md — Freefall
*Stage 2 | Generated: 2026-03-xx | Model: Sonnet | Taurus*

---

## What Is It

A premium, one-touch iOS physics puzzle game. Tap to flip gravity on a small geometric shape and navigate it through handcrafted obstacle courses to reach the goal. No ads. No IAP. No lives. No subscriptions. Buy once, play forever.

---

## Core Mechanic ⚠️ LOCKED — copy verbatim into every doc

> **The player taps anywhere on a portrait screen to instantly flip gravity on a small geometric shape, navigating it through handcrafted static obstacle courses to reach a glowing goal point — one mechanic, no time pressure, no energy, no ads.**

This is a puzzle-first gravity flip game. Not an auto-runner. Not a sandbox. Levels are spatial puzzles where the player finds the right sequence of gravity flips to thread through obstacles. Precision and observation over speed and reflexes.

---

## Who It's For

- Casual iOS players tired of being monetised
- Fans of Alto's Adventure, Monument Valley, Orbit who want a clean premium experience
- People who want 10 minutes of genuinely chill, satisfying gameplay with no interruptions
- The "why can't I just buy a game anymore" audience — and they're loud on Reddit

---

## Why We're Building This

316 bad reviews scraped from direct competitors. Every complaint points at the same thing: ads, subscriptions, energy systems, IAP popups. Nobody in this space is offering a clean £2.99 premium experience. Alto's Adventure proved the model works. We're applying it to a physics puzzle game with a unique identity.

See: `competitor_pain_intel.md` and `research_stage1.md` for the full evidence chain.

---

## Monetisation

- **Price:** £2.99 / $2.99 one-time purchase
- **No ads. No IAP. No subscription. No lives. No energy.**
- Revenue relies on: organic App Store discovery, Apple editorial potential, word of mouth
- Secondary: "Freefall 2" or themed level packs as separate paid apps (not IAP within this one)

---

## 🔐 Locked MVP Features (non-negotiable — Opus may build on top, cannot remove)

### 1. Single-tap gravity flip
The ONLY input. Tap anywhere → gravity reverses on the player shape. No swipes, no drag, no multi-touch required. Portrait, one thumb, works lying on a sofa. This is the whole game.

**Why locked:** It's the core mechanic. If this isn't polished and satisfying, nothing else matters. Must feel snappy, responsive, with good haptic feedback on flip.

### 2. 40 handcrafted levels at launch
Designed by hand, not procedurally generated. Grouped into 4 worlds of 10 levels each, with escalating complexity and a distinct visual theme per world.

**Why locked:** Orbit's #1 complaint was "only 45 levels." We need at least 40 tight, well-designed levels to justify the premium price and land good reviews. Quality over quantity — every level must feel intentional.

### 3. Neon/glow aesthetic with abstract fantasy world themes
Dark backgrounds, glowing geometric shapes, neon trail effects. Trip-hop Japan zen vibes — relaxing, cool, visually satisfying. Players should want to leave it on just for the aesthetic. NOT traffic cones, NOT city streets, NOT anything stale or corporate. Each world (10 levels) gets a completely different abstract/fantasy environment.

**Why locked:** This is the identity. The "relaxed hours of play" experience Jamie described is entirely dependent on the feel being right. The visual + audio vibe IS the product as much as the mechanic. Art direction must be locked before Codex touches a pixel.

### 4. Satisfying audio layer
Custom SFX on gravity flip (satisfying snap/whoosh). Ambient lo-fi / trip-hop style background music per world. Goal-hit audio celebration. Music on/off toggle in settings (competitors were roasted for no audio controls). The audio should make players feel "fulfilled" as they traverse the course.

**Why locked:** Jamie specifically called out audio as non-negotiable. This is part of what makes the game worth leaving open. A physics puzzle with bad audio is a different product.

---

## Scope Fence — MVP (do NOT build these at v1.0)

- ❌ Endless / procedural mode (skip for v1)
- ❌ Level editor or share levels
- ❌ Multiplayer or leaderboards
- ❌ IAP of any kind
- ❌ Ads of any kind
- ❌ Energy or lives system
- ❌ Online requirement
- ❌ 3D art or 3D environments
- ❌ Landscape mode (portrait-only at launch)
- ❌ Social login or account system
- ❌ Any backend / API calls
- ❌ Push notifications

---

## Feature Baseline (from Stage 1 research — drawn from Competitor Feature Mining)

### Table Stakes
*(Every competitor has these — context only, not a checklist)*
- Physics engine with realistic object behaviour
- Level progression (numbered, locked until prior complete)
- Retry on death
- Sound effects + music

### Best From Competitors (worth taking / improving)
- **One-mechanic discovery** (Alto, Dune): level 1 teaches by playing — no tutorial screen needed
- **Satisfying completion moment** (Cut the Rope): audio + visual pop on goal
- **Cohesive visual identity** (Alto, World of Goo): every screen feels like the same world
- **Meditative pacing** (Alto): no pressure, calm, the opposite of Angry Birds energy

### Differentiation Opportunities
- Premium, no ads — literally nobody in this space does this
- Offline first — competitors break offline; ours never requires internet
- Portrait one-thumb — Orbit users begged for this
- 40 levels at launch — Orbit's 45-level complaint is a low bar; we match or beat it with better quality
- Geometric/minimal 2D art — users despise 3D remasters

### Potential Additions (Opus decides — none locked)
- iCloud sync for progress
- Haptic feedback on gravity flip
- Daily challenge level
- Ghost replay (see your best run)
- Endless mode post-launch

*These are suggestions drawn from research. Opus should challenge, cut, add to, or rethink any of these. We want your best thinking — not a rubber stamp on ours.*

---

## Competitor Pain INCLUDE/EXCLUDE

*(From competitor_pain_intel.md — 316 bad reviews scraped)*

### ✅ INCLUDE
1. One-time purchase, no subscription, no energy
2. Offline play — zero network dependency
3. Clean 2D minimalist art — users prefer it over 3D remasters
4. Audio controls — at minimum, music on/off toggle
5. Enough levels — 40 high-quality at launch
6. Stable build — no loading bugs, no iCloud sync failures
7. Fair progression — difficulty earned through skill, not spending
8. Zero IAP prompts — never ask for money mid-session

### ❌ EXCLUDE
1. Interstitial ads between levels — instant 1-star trigger
2. Lives / energy system
3. Subscriptions of any kind
4. IAP popup prompts during sessions
5. Fake RNG / fortune wheel monetisation
6. Online requirement for single-player
7. Ugly 3D art on a 2D-native game
8. Creative modes locked behind IAP

---

## 🎯 Pain Wedge

**Every physics game worth playing has been monetised into oblivion — ours is £2.99, offline, no ads, no lives, and the App Store reviews write themselves.**

---

## Dream Version (post-v1 — context only)

- 80-100 levels across 8-10 worlds
- Endless procedural mode
- Level editor + level sharing
- Soundtrack available as separate purchase
- Apple Design Award nomination
- iOS + iPadOS (iPad adaptive layout)

---

## Tech Stack

- Swift + SpriteKit
- SwiftUI for menus/UI chrome
- @Observable state management
- async/await
- iOS 17+ minimum
- Portrait only at launch
- No third-party dependencies
- No backend

---

## Build Estimate

~4-5 weeks solo (see research_stage1.md for breakdown)

---

*This BRIEF is input for Opus — not a spec. Locked features must stay. Scope fence must hold. Everything else: Opus decides.*
