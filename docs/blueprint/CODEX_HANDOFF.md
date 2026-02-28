CODEX HANDOFF — Machine-Readable Specification
This section is written for an AI coding agent. Every instruction is explicit. No ambiguity.
### 5.1 Screen Inventory
|#|Screen Name |Purpose |Navigate TO From
|Navigate FROM To |Nav Type |
|-|-----------------|---------------------------------------------------------|---------------------------|-----------------
--------------------------------------------------------------|-------------------------|
|1|MainMenuView |Entry point. Title + play button. |App launch
|WorldSelectView (tap PLAY), SettingsView (tap gear) |Root |
|2|WorldSelectView |Choose which world to play. |MainMenuView (tap
PLAY) |LevelSelectView (tap unlocked world), MainMenuView (tap back) |Push
|
|3|LevelSelectView |Choose which level in a world. |WorldSelectView (tap
world)|GameView (tap unlocked level), WorldSelectView (tap back) |Push
|
|4|GameView |The actual gameplay. SpriteKit scene embedded in
SwiftUI.|LevelSelectView (tap level)|LevelCompleteView (on goal), LevelSelectView (tap
pause → quit) |Full screen cover ||5|LevelCompleteView|Shows trail art + completion word. |GameView (on goal
reached) |GameView with next level (tap NEXT LEVEL), LevelSelectView (tap back to
levels)|Modal overlay on GameView|
|6|SettingsView |Music / SFX / haptics toggles. |MainMenuView (tap gear)
|MainMenuView (tap back / dismiss) |Sheet |
|7|IntermissionView|Arcade dodge mode, fires after levels 5+10 of each world.|GameView (auto after level 5/10 complete)|GameView next level (auto on death)|Full screen cover|
### 5.2 Per-Screen UI Specification
#### Screen 1: MainMenuView
```
ROOT VIEW
├── Background: Color.black, ignoresSafeArea
├── VStack (centre aligned, spacing: 0)
│ ├── Spacer (flex)
│ ├── Text "FREEFALL"
│ │ ├── Font: custom heavy/black condensed, 64pt
│ │ ├── Colour: #00D4FF (cyan)
│ │ ├── Shadow: cyan glow, radius 20, opacity 0.4
│ │ └── Slight spray-paint texture overlay (optional — can be plain at MVP)
│ ├── Spacer (40pt)
│ ├── Button "PLAY"
│ │ ├── Font: custom heavy condensed, 28pt
│ │ ├── Colour: #00D4FF
│ │ ├── Border: 1pt cyan outline, corner radius 8
│ │ ├── Padding: 16pt horizontal, 12pt vertical
│ │ ├── Tap: navigate to WorldSelectView
│ │ └── Haptic: .light on tap
│ ├── Spacer (flex)
│ └── HStack (bottom, full width, padding horizontal 24)
│ ├── Button (gear icon — SF Symbol "gearshape")
│ │ ├── Colour: #00D4FF, opacity 0.6
│ │ ├── Size: 24pt
│ │ └── Tap: present SettingsView as sheet
│ ├── Spacer
│ └── Button (speaker icon — SF Symbol "speaker.wave.2" / "speaker.slash")
│ ├── Colour: #00D4FF, opacity 0.6
│ ├── Size: 24pt
│ └── Tap: toggle music on/off immediately
└── End
```
States: Only one state — always shows title + play. No loading, no empty, no error.
#### Screen 2: WorldSelectView
```
ROOT VIEW├── Background: Color.black, ignoresSafeArea
├── VStack (spacing: 16, padding: 24)
│ ├── Back button (top left, SF Symbol "chevron.left", cyan, tap → pop to MainMenuView)
│ ├── Spacer (20pt)
│ ├── ForEach world in [1, 2, 3, 4]:
│ │ └── WorldCard
│ │ ├── Height: ~120pt
│ │ ├── Full width (minus padding)
│ │ ├── Corner radius: 12
│ │ ├── Border: 2pt, world primary colour
│ │ ├── Background: world background image (subtle texture) at 10% opacity
│ │ ├── Content:
│ │ │ ├── Text: world name (THE BLOCK / NEON YARD / UNDERGROUND /
STATIC)
│ │ │ │ ├── Font: custom heavy condensed, 28pt
│ │ │ │ └── Colour: world primary colour
│ │ │ └── IF locked: lock icon (SF Symbol "lock.fill", white, opacity 0.5) aligned right
│ │ ├── IF unlocked: tap → navigate to LevelSelectView for this world
│ │ ├── IF locked: tap → do nothing (no alert, no popup, no "complete previous world"
message — the lock icon is enough)
│ │ └── IF locked: entire card opacity 0.4 (visually dimmed)
│ └── Spacer (flex)
└── End
```
World unlock state: World 1 always unlocked. World N+1 unlocks when all 10 levels of World
N are complete. Read from GameState.
#### Screen 3: LevelSelectView
```
ROOT VIEW
├── Background: Color.black, ignoresSafeArea
├── VStack
│ ├── HStack (top bar)
│ │ ├── Back button (chevron.left, world primary colour)
│ │ ├── Spacer
│ │ └── Text: world name, world primary colour, 22pt heavy condensed
│ ├── Spacer (20pt)
│ ├── LazyVGrid (columns: 2, spacing: 16, padding horizontal: 24)
│ │ └── ForEach level in 1...10:
│ │ └── LevelCell
│ │ ├── Aspect ratio: 1:1 (square)
│ │ ├── Corner radius: 8
│ │ ├── IF completed:
│ │ │ ├── Background: trail art thumbnail (stored as image data in UserDefaults —
OR — regenerated from saved path points)
│ │ │ ├── Overlay: level number (bottom left, 14pt, white, slight shadow)│ │ │ └── Tap → load this level in GameView
│ │ ├── IF unlocked (next to play):
│ │ │ ├── Background: black
│ │ │ ├── Border: 2pt, world primary colour, pulsing opacity animation (0.5 → 1.0,
1.5s loop)
│ │ │ ├── Text: level number, centre, world primary colour, 24pt
│ │ │ └── Tap → load this level in GameView
│ │ ├── IF locked:
│ │ │ ├── Background: black
│ │ │ ├── Border: 1pt, white, opacity 0.15
│ │ │ ├── Text: level number, centre, white, opacity 0.2, 20pt
│ │ │ └── Tap → do nothing
│ └── Spacer (flex)
└── End
```
Level unlock state: Level 1 of each world is always unlocked once the world is unlocked.
Level N+1 unlocks when level N is complete.
Trail art thumbnails: At MVP, don’t store trail art images. It adds significant storage
complexity. Instead, completed levels show a small coloured checkmark or filled circle in the
world’s primary colour. Trail art thumbnails can be added post-launch.
#### Screen 4: GameView
```
ROOT VIEW (full screen, no safe area insets)
├── SpriteKitView (fills entire screen)
│ └── GameScene (SKScene)
│ ├── Background: world background image node, full screen
│ ├── Obstacles: loaded from level JSON, positioned, physics bodies attached
│ ├── Goal ring: positioned from JSON, pulsing animation
│ ├── Player sphere: positioned at launch point
│ ├── Trail system: rendering layer behind sphere, above background
│ ├── HUD (SpriteKit overlay, not SwiftUI):
│ │ ├── Level number: top left, 16pt, white, opacity 0.5
│ │ └── Pause button: top right, SF Symbol "pause.circle", white, opacity 0.5
│ │ └── Tap → pause game, show pause overlay
│ ├── STATE: Ready
│ │ ├── Sphere at launch position, stationary
│ │ ├── "TAP TO START" text, centre bottom, white, opacity 0.3, 14pt
│ │ ├── Tap anywhere (except pause) → STATE: Playing
│ │ └── On transition to Playing: apply launch velocity to sphere, start trail recording
│ ├── STATE: Playing
│ │ ├── Sphere moving under gravity + momentum
│ │ ├── Trail rendering active
│ │ ├── Tap anywhere (except pause) → flip gravity
│ │ ├── Sphere contacts obstacle → STATE: Dead│ │ ├── Sphere exits screen bounds → STATE: Dead
│ │ └── Sphere enters goal trigger → STATE: Complete
│ ├── STATE: Dead
│ │ ├── Sphere replaced with particle burst (neon fragments, 0.3s)
│ │ ├── Trail fades out (0.3s)
│ │ ├── After 0.3s → automatically transition to STATE: Ready (same level)
│ │ └── No "retry" button. No dialog. Instant.
│ ├── STATE: Complete
│ │ ├── Goal ring flash animation (white, 0.2s)
│ │ ├── Goal celebration particles (cyan burst outward, 0.5s)
│ │ ├── Sphere fades out (0.3s)
│ │ ├── Trail remains visible
│ │ ├── After 0.8s → notify SwiftUI via GameState to present LevelCompleteView
│ │ └── Update GameState: mark level as complete, unlock next level
│ └── STATE: Paused
│ ├── Pause physics
│ ├── Dim game scene (overlay black at 50% opacity)
│ ├── Show: "RESUME" button (centre), "QUIT" button (below)
│ ├── RESUME → unpause physics, remove overlay
│ └── QUIT → dismiss GameView, return to LevelSelectView
└── End
```
#### Screen 5: LevelCompleteView
```
MODAL OVERLAY on GameView
├── Background: transparent (trail art visible behind)
├── VStack (centre aligned)
│ ├── Spacer (flex)
│ ├── Text: completion word (CLEAN / FRESH / DOPE / NICE)
│ │ ├── Font: custom heavy condensed, 56pt
│ │ ├── Colour: white with world-primary-colour gradient
│ │ ├── Spray-paint texture overlay
│ │ ├── Entrance animation: scale from 0.5 → 1.0, opacity 0 → 1, spring easing, 0.4s
│ │ └── SFX: spray-can hiss + bass drop on appearance
│ ├── Spacer (flex)
│ └── HStack (bottom, padding 24)
│ ├── Button "LEVELS" (left aligned)
│ │ ├── Font: 14pt, white, opacity 0.5
│ │ └── Tap → dismiss GameView, return to LevelSelectView
│ ├── Spacer
│ └── Button "NEXT LEVEL →" (right aligned)
│ ├── Font: 16pt heavy, world primary colour
│ ├── Border: 1pt, world primary colour, corner radius 6
│ ├── Tap → dismiss this overlay, load next level in GameView (STATE: Ready)
│ ├── IF this was level 10 of a world:
│ │ ├── Button text changes to "NEXT WORLD →"│ │ └── Tap → dismiss GameView, return to WorldSelectView (next world now
unlocked)
│ └── IF this was level 40 (final level):
│ ├── Button text changes to "FIN"
│ └── Tap → return to MainMenuView (maybe with a special animation —
post-MVP)
└── End
```
Completion word selection logic:
- Count total gravity flips during the level attempt
- If flips ≤ expected minimum (defined in level JSON as `parFlips`): “FRESH” (25% of the
time) or “CLEAN” (75%)
- If trail has >5 self-crossings (path crossed itself): “DOPE” (60%) or “CLEAN” (40%)
- Default / all other cases: weighted random — CLEAN 40%, FRESH 25%, DOPE 20%,
NICE 15%
- Never show the same word twice in a row
#### Screen 6: SettingsView
```
SHEET (presented from MainMenuView)
├── Background: Color.black
├── VStack (padding: 24, spacing: 24)
│ ├── HStack (top)
│ │ ├── Text "SETTINGS", 22pt heavy condensed, cyan
│ │ ├── Spacer
│ │ └── Button "✕" (SF Symbol "xmark"), cyan, tap → dismiss sheet
│ ├── Divider (cyan, opacity 0.2)
│ ├── SettingsRow "Music" — Toggle (bound to GameState.musicEnabled)
│ ├── SettingsRow "Sound Effects" — Toggle (bound to GameState.sfxEnabled)
│ ├── SettingsRow "Haptics" — Toggle (bound to GameState.hapticsEnabled)
│ ├── Divider (cyan, opacity 0.2)
│ ├── Text "FREEFALL v1.0", 12pt, white, opacity 0.3, centre aligned
│ └── Spacer
└── End
```
SettingsRow is a reusable component: HStack with label (left, 16pt, white) and Toggle (right,
tinted world primary colour).
### 5.3 Navigation Flow — All User Journeys
**First-time user:**
App launch → MainMenuView → tap PLAY → WorldSelectView (World 1 unlocked, 2-4
locked) → tap THE BLOCK → LevelSelectView (Level 1 pulsing, 2-10 locked) → tap Level 1→ GameView (Ready state) → tap to launch → play → [complete or die and retry] →
LevelCompleteView → tap NEXT LEVEL → GameView Level 2 → …
**Returning user (mid-progress):**
App launch → MainMenuView → tap PLAY → WorldSelectView → tap unlocked world →
LevelSelectView → tap next unlocked level → GameView → play
**Completing a world:**
GameView Level 10 → LevelCompleteView (“NEXT WORLD →”) → WorldSelectView (next
world now unlocked, card lights up)
**Quitting mid-level:**
GameView → tap pause → QUIT → LevelSelectView (no progress saved for incomplete
level)
**Toggling settings:**
MainMenuView → tap gear → SettingsView (sheet) → toggle music/sfx/haptics → dismiss
→ MainMenuView
**Quick music toggle:**
MainMenuView → tap speaker icon → music toggles immediately (no navigation)
### 5.4 Data Model
**GameState (@Observable class — single source of truth)**
```
Properties:
- completedLevels: Set<String> // Format: "W1L3" (World 1, Level 3)
- musicEnabled: Bool // Default: true
- sfxEnabled: Bool // Default: true
- hapticsEnabled: Bool // Default: true
- currentWorldId: Int? // Set when entering a world
- currentLevelId: Int? // Set when entering a level
- gameplayState: GameplayState // .ready, .playing, .dead, .complete, .paused
Computed properties:
- func isLevelUnlocked(world: Int, level: Int) -> Bool
// Level 1 always unlocked if world is unlocked
// Level N unlocked if "W{world}L{N-1}" is in completedLevels
- func isWorldUnlocked(world: Int) -> Bool
// World 1 always unlocked
// World N unlocked if all 10 levels of World N-1 are in completedLevels
- func completedCountForWorld(world: Int) -> Int
Persistence:
- completedLevels: stored in UserDefaults as JSON-encoded [String]
- musicEnabled, sfxEnabled, hapticsEnabled: stored as individual UserDefaults bools- currentWorldId, currentLevelId, gameplayState: NOT persisted (runtime only)
```
**LevelDefinition (struct — loaded from JSON)**
```
Properties:
- worldId: Int
- levelId: Int
- launchPosition: CGPoint // Normalised 0-1
- launchVelocity: CGVector // Points per second
- goalPosition: CGPoint // Normalised 0-1
- goalRadius: CGFloat // Points
- initialGravityDown: Bool
- parFlips: Int // Expected minimum flips for "optimal" solution
- obstacles: [ObstacleDefinition]
ObstacleDefinition:
- type: String // "rect", "circle", "polygon", "line"
- position: CGPoint // Normalised 0-1
- size: CGSize // Normalised (for rect)
- radius: CGFloat? // For circle
- points: [CGPoint]? // For polygon
- rotation: CGFloat // Degrees
- style: String // "neon_outline", "textured", "pulsing", "abstract"
```
**WorldDefinition (struct — hardcoded or from JSON)**
```
Properties:
- id: Int
- name: String // "THE BLOCK", "NEON YARD", etc.
- primaryColour: Color // hex
- secondaryColour: Color
- accentColour: Color
- trailStartColour: Color
- trailEndColour: Color
- musicFileName: String
- backgroundImageName: String
```
### 5.5 Design System
**Colours:**
|Token |Hex |Usage |
|---------------|-------------|----------------------------------||background |#000000 |All screen backgrounds |
|world1Primary |#00D4FF |World 1 UI elements, text, borders|
|world1Secondary|#1A1A2E |World 1 background tint |
|world1Accent |#FF1493 |World 1 trail end colour |
|world2Primary |#39FF14 |World 2 UI elements |
|world2Secondary|#1A1A0A |World 2 background tint |
|world2Accent |#FFE600 |World 2 trail end |
|world3Primary |#FF6600 |World 3 UI elements |
|world3Secondary|#1A0A00 |World 3 background tint |
|world3Accent |#CC0000 |World 3 trail end |
|world4Primary |#8B00FF |World 4 UI elements |
|world4Secondary|#0A000A |World 4 background tint |
|world4Accent |#FFFFFF |World 4 trail end |
|textPrimary |#FFFFFF |Primary text |
|textSecondary |#FFFFFF @ 50%|Secondary / hint text |
|sphere |#FFFFFF |Player sphere core |
|goalRing |#00FFFF |Goal ring |
**Typography:**
|Usage |Font |Size|Weight |
|-------------------------------|-------------------------------------|----|-------|
|Game title (FREEFALL) |System condensed or custom (see note)|64pt|Black |
|World names on cards |Same |28pt|Heavy |
|Level complete word (CLEAN etc)|Same |56pt|Black |
|PLAY button |Same |28pt|Heavy |
|Screen titles |Same |22pt|Heavy |
|Body text / labels |System |16pt|Regular|
|Level numbers (select grid) |System |24pt|Bold |
|In-game HUD (level number) |System monospaced |16pt|Medium |
|Small labels / captions |System |12pt|Regular|
**Font note:** The ideal font is a heavy condensed sans-serif — think Impact, Anton, Oswald
Black, or Barlow Condensed Black. At MVP, use the system `.title` with `.condensed` width
design. Post-launch, license or find a free condensed black font that has more street energy.
The font choice is cosmetic, not architectural — easy to swap later.
**Spacing:**
- Base unit: 8pt
- Standard padding: 24pt (3 units)
- Card spacing: 16pt (2 units)
- Button padding: 16pt horizontal, 12pt vertical
- Corner radius (cards): 12pt
- Corner radius (buttons): 8pt
- Corner radius (level cells): 8pt
**Haptics:**|Event |Generator |Style |
|-------------|-------------------------------|--------|
|Gravity flip |UIImpactFeedbackGenerator |.medium |
|Goal reached |UINotificationFeedbackGenerator|.success|
|Player death |UIImpactFeedbackGenerator |.soft |
|UI button tap|UIImpactFeedbackGenerator |.light |
### 5.6 Reusable Components
**WorldCard** — Used on WorldSelectView
- Props: worldId, name, primaryColour, isUnlocked, completedCount
- Appearance: horizontal card, 120pt height, full width, border in primaryColour, world name
text, lock icon if locked, dimmed if locked
- Behaviour: tap navigates to LevelSelectView if unlocked
**LevelCell** — Used on LevelSelectView
- Props: worldId, levelId, primaryColour, isCompleted, isUnlocked, isNextToPlay
- Appearance: square cell, 3 visual states (completed with checkmark, unlocked with pulsing
border, locked dim)
- Behaviour: tap loads level if unlocked
**SettingsRow** — Used on SettingsView
- Props: label (String), isOn (Binding<Bool>), tintColour (Color)
- Appearance: HStack with label and toggle
**NeonText** — Used for titles and completion words
- Props: text, fontSize, colour, glowRadius
- Appearance: text with outer shadow/glow in the specified colour
### 5.7a Parallax Background System (for Codex)

**What it is:** The background image drifts slowly as the sphere moves, creating depth. The background moves at 20% of the sphere's velocity in the opposite direction. This makes the world feel alive rather than a static wallpaper behind the gameplay.

**Implementation in SpriteKit:**
- The background is an `SKSpriteNode` sized at 120% of the screen (wider and taller than the viewport)
- It starts centred on screen
- Every physics frame: `backgroundNode.position.x -= sphere.velocity.dx * 0.20 * dt`
- Every physics frame: `backgroundNode.position.y -= sphere.velocity.dy * 0.20 * dt`
- Clamp the background position so it never reveals black edges: `backgroundNode.position.x = max(min(backgroundNode.position.x, maxX), minX)` where maxX/minX are calculated from the size difference between background and screen
- On death/restart: smoothly lerp background position back to centre over 0.3s (same duration as trail fade)
- The parallax effect is subtle — the background should feel like it's breathing, not sliding. 20% velocity multiplier is the target; adjust during playtesting.

**Background assets:** One PNG per world, stored in `assets/images/worlds/`. Use the APPROVED-worldN-bg.png files. Scale to fill 120% of screen width/height.

---

### 5.7b Audio System — Updated Spec (8 tracks, 2 per world)

**Why 8 tracks:** Each world has 2 music tracks:
- **Track A (levels 1-5 of that world):** Chill, relaxed, player is learning. Lower energy.
- **Track B (levels 6-10 of that world):** Same sub-genre but more intense — heavier drums, faster energy, signals that difficulty is rising.

This creates natural audio progression that mirrors the difficulty curve without the player consciously noticing.

**Music file naming convention:**
```
assets/audio/music/world1-the-block/world1-track-a.mp3   (levels 1-5)
assets/audio/music/world1-the-block/world1-track-b.mp3   (levels 6-10)
assets/audio/music/world2-neon-yard/world2-track-a.mp3
assets/audio/music/world2-neon-yard/world2-track-b.mp3
assets/audio/music/world3-underground/world3-track-a.mp3
assets/audio/music/world3-underground/world3-track-b.mp3
assets/audio/music/world4-static/world4-track-a.mp3
assets/audio/music/world4-static/world4-track-b.mp3
```

**Track selection logic (in GameState):**
```
func musicTrackFor(world: Int, level: Int) -> String {
    let suffix = level <= 5 ? "track-a" : "track-b"
    return "world\(world)-\(suffix)"
}
```

**Crossfade on track switch:**
- When player moves from level 5 to level 6 within a world: crossfade from track-a to track-b over 2 seconds
- When player moves to a new world: crossfade from previous world's track to new world's track-a over 2 seconds
- Use two `AVAudioPlayer` instances simultaneously, fade out one while fading in the other
- Music loops continuously. Use `numberOfLoops = -1` on AVAudioPlayer.
- Music continues playing across death/restart without interruption — do NOT stop/restart the music on death. The music is the thread that keeps the player in flow state.

**SFX files:**
```
assets/audio/sfx/flip.mp3          — gravity flip (played on every tap during gameplay)
assets/audio/sfx/death.mp3         — sphere death (particle burst moment)
assets/audio/sfx/goal.mp3          — goal reached (celebration hit)
assets/audio/sfx/level-complete.mp3 — level complete word appears
assets/audio/sfx/ui-tap.mp3        — menu/button taps
assets/audio/sfx/world-unlock.mp3  — world unlock moment (world select screen)
```

Use `SKAction.playSoundFileNamed` for SFX (fire-and-forget). Use `AVAudioPlayer` for music (persistent, looping, crossfadeable).

**Settings bindings:**
- `GameState.musicEnabled = false` → pause both AVAudioPlayer instances immediately
- `GameState.sfxEnabled = false` → skip all SKAction sound plays
- `GameState.hapticsEnabled = false` → skip all UIImpactFeedbackGenerator calls
- These are checked at the point of play, not pre-filtered — always check the setting before triggering audio/haptic

---

### 5.7c Collectibles System

**What it is:** Small glowing orbs scattered along the level path. The sphere passing through them triggers a satisfying SFX ping, a colour burst on the trail, and a haptic. They are NOT required for completion — purely additive juice. They cannot be "missed" in a punishing way; failing to collect them has no consequence.

**Visual design:**
- Small circle, radius 6pt
- Colour: world accent colour (e.g. World 1 = #FF1493 hot pink — contrasts with the cyan trail)
- Soft outer glow (same colour, radius 12pt, additive blend)
- Idle animation: gentle pulse (scale 0.8→1.0, 1.2s loop)
- On collection: brief burst expand (scale to 2.0 over 0.15s, opacity to 0 over 0.15s) then remove

**Quantity per level:** 3-5 collectibles per level, defined in level JSON as `collectibles: [{x, y}]` (normalised 0-1 coords, same as obstacles)

**Level JSON addition:**
```json
"collectibles": [
  { "x": 0.35, "y": 0.4 },
  { "x": 0.55, "y": 0.6 },
  { "x": 0.75, "y": 0.45 }
]
```

**Collision detection:**
- Collectible has a physics body: sensor (no collision response, contact only), radius 10pt (generous hitbox)
- On contact with sphere: trigger collection sequence
- Physics category: `collectible = 16`
- Sphere contact mask includes collectible category

**Collection sequence (all happen simultaneously):**
1. Visual burst: scale 2.0 + fade out over 0.15s, remove node
2. Trail colour burst: at the moment of collection, inject a single bright flash segment into the trail (white or bright accent for 2 frames, then resume normal gradient)
3. SFX: play `sfx/collect.mp3` (short, high-pitched ping — feels like a percussion hit in the music)
4. Haptic: `UIImpactFeedbackGenerator(.light)` — lighter than the gravity flip haptic
5. Track collected count in GameScene (for potential post-launch scoring features)

**State management:**
- `collectedCount: Int` — tracked per level attempt
- Resets to 0 on death/restart
- Does NOT affect completion word selection at MVP
- Does NOT persist between sessions at MVP (post-launch feature)

**SFX file:** `assets/audio/sfx/collect.mp3` — short percussive ping, 0.1-0.2s, high frequency, sounds like a hi-hat accent or xylophone tap

---

### 5.7d Beat-Reactive Background System

**What it is:** The background and obstacle outlines pulse subtly in sync with the music's BPM. The game world breathes with the beat. This is driven by a timer (not audio analysis) — we know each world's BPM in advance, so we sync a repeating animation to match.

**World BPMs:**
- World 1 (THE BLOCK): 88bpm (Track A) / 95bpm (Track B)
- World 2 (NEON YARD): 172bpm (Track A) / 174bpm (Track B)
- World 3 (UNDERGROUND): 160bpm (Track A) / 165bpm (Track B)
- World 4 (STATIC): 132bpm (Track A) / 138bpm (Track B)

**Beat interval calculation:**
```swift
let bpm: Double = 88 // from world/track definition
let beatInterval: TimeInterval = 60.0 / bpm // seconds per beat
```

**What pulses on the beat:**

1. **Background brightness pulse:**
   - On beat: briefly increase background node alpha by +0.08 (from base 1.0 to 1.08, clamped)
   - Decay back to 1.0 over 60% of the beat interval
   - Implementation: SKAction sequence (fadeAlpha to 1.0+flash over 0.05s → fadeAlpha to 1.0 over beatInterval*0.6)
   - Subtle — like the room breathing. Should not be distracting.

2. **Obstacle outline glow pulse:**
   - On beat: briefly increase obstacle glow width from base (3pt) to peak (6pt)
   - Decay back to 3pt over 40% of the beat interval
   - Implementation: iterate all obstacle nodes, run SKAction to animate glowWidth
   - Note: SKShapeNode.glowWidth IS animatable via SKAction.customAction

3. **Goal ring pulse amplification:**
   - The goal ring already pulses (opacity 0.7→1.0, 0.8s). On beat, boost the peak opacity to 1.0 briefly regardless of where the pulse cycle is.
   - Creates a visual "kick" on the goal ring that draws the eye on the beat.

**Starting the beat timer:**
```swift
// In GameScene, when music starts playing (on entering .playing state)
func startBeatTimer(bpm: Double) {
    let beatInterval = 60.0 / bpm
    let beatAction = SKAction.sequence([
        SKAction.run { [weak self] in self?.onBeat() },
        SKAction.wait(forDuration: beatInterval)
    ])
    run(SKAction.repeatForever(beatAction), withKey: "beatTimer")
}

func stopBeatTimer() {
    removeAction(forKey: "beatTimer")
}
```

**When to start/stop:**
- Start: when state transitions from .ready → .playing
- Stop: when state transitions to .dead or .complete
- On .dead → .ready: restart beat timer when .playing resumes
- The beat timer does NOT run during .ready state (too distracting while player is reading the level)

**BPM source:** Add `bpmA: Double` and `bpmB: Double` to `WorldDefinition`. Select based on current level (1-5 = A, 6-10 = B). Pass to GameScene when loading a level.

**Performance note:** The beat timer runs on the main thread via SKAction. Do not perform heavy operations in `onBeat()` — only SKAction animations on existing nodes. Max 10 obstacle nodes to animate = trivial cost.

---

### 5.7 Paint Trail Technical Spec (for Codex)
**Rendering approach:**
Option A (recommended): Use `SKShapeNode` with a `CGMutablePath`. Every physics
frame, append the sphere’s position to the path. Set the path’s `strokeColor` using a gradient
(approximate by creating multiple path segments with different colours). Set `lineWidth` with
random variation. Add `SKEmitterNode` particles at the current position for spray effect.
Option B (performance fallback): Render trail to an `SKTexture` at intervals. Every N frames,
render the current trail to a bitmap texture and replace the path with this texture. This caps
the node count but adds rendering complexity.
**Trail colour interpolation:**- Track total distance travelled by the sphere during the level
- Map distance to a 0→1 parameter `t`
- Trail colour = lerp(worldTrailStartColour, worldTrailEndColour, t)
- At the beginning of a level the trail is the start colour. By the time the player reaches the
goal, it’s the end colour. Death resets `t` to 0.
**Spray-paint scatter effect:**
- At the sphere’s current position each frame, spawn 1-3 tiny `SKSpriteNode` circles (radius
1-3pt)
- Offset each by a random vector within 8-12pt of the trail centre
- Opacity: 0.15-0.35 (random)
- Colour: same as current trail colour
- These nodes do NOT fade — they persist like the trail
- Performance note: these accumulate. Cap at 2000 scatter nodes per level attempt. After
cap, stop spawning new scatter but trail path continues.
**On death:**
- All trail nodes (path + scatter) fade opacity to 0 over 0.3 seconds
- Then remove all trail nodes
- Reset trail colour parameter `t` to 0
**On level complete:**
- Trail remains visible
- Optional: slight camera zoom-out (scale game scene to 0.85 over 0.5 seconds) to reveal
more of the trail composition
- The trail IS the art. Do not obscure it with UI elements except the completion word (which
overlays on top) and the NEXT LEVEL button (small, bottom corner)
### 5.8 Build Order (for Codex)
Execute in this exact order. Do not skip ahead.
```
Step 1: Project setup
→ Create Xcode project, SwiftUI app, add SpriteKit framework
→ Deployment target: iOS 17.0
→ Devices: iPhone + iPad
→ No third-party packages
Step 2: GameState model
→ @Observable class with all properties from section 5.4
→ UserDefaults persistence for completedLevels, settings
→ Requires: Step 1Step 3: LevelDefinition model + JSON loading
→ Struct definitions from section 5.4
→ JSON decoder for level files
→ Create 1 test level JSON file (World 1, Level 1)
→ Requires: Step 1
Step 4: GameScene (SpriteKit) — sphere + gravity
→ SKScene subclass
→ Sphere node with physics body
→ Gravity toggling on touch
→ Haptic feedback on flip
→ Requires: Steps 1, 3
Step 5: Obstacle loading + rendering
→ Read obstacles from LevelDefinition
→ Create SKShapeNode or SKSpriteNode for each obstacle
→ Attach physics bodies (static)
→ Style per world (start with neon_outline only)
→ Requires: Steps 3, 4
Step 6: Collision detection
→ Sphere contacts obstacle → death
→ Sphere exits screen bounds → death
→ Sphere enters goal trigger → complete
→ Requires: Steps 4, 5
Step 7: Death sequence
→ Particle burst (SKEmitterNode)
→ Trail fade + clear
→ Auto-restart to Ready state
→ Requires: Step 6
Step 8: Paint trail system (basic)
→ SKShapeNode with CGPath
→ Colour gradient based on distance
→ Width variation
→ Requires: Step 4
Step 9: Paint trail spray effect
→ Scatter particles along trail
→ Edge bleed emitters
→ Performance cap at 2000 scatter nodes
→ Requires: Step 8
Step 10: Level complete sequence
→ Goal celebration (ring flash + particles)
→ Trail remains visible
→ Completion word selection logic→ Notify GameState
→ Requires: Steps 6, 8
Step 11: SwiftUI ↔ SpriteKit bridge
→ SpriteView embedding GameScene
→ GameState shared between SwiftUI and SpriteKit
→ SwiftUI observes gameplayState changes
→ Requires: Steps 2, 4
Step 12: MainMenuView
→ Layout per section 5.2
→ Navigation to WorldSelectView and SettingsView
→ Requires: Step 2
Step 13: WorldSelectView
→ Layout per section 5.2
→ World cards with lock state
→ Navigation to LevelSelectView
→ Requires: Steps 2, 12
Step 14: LevelSelectView
→ Layout per section 5.2
→ Level cells with 3 states
→ Navigation to GameView
→ Requires: Steps 2, 13
Step 15: GameView (SwiftUI wrapper)
→ Full screen cover presenting SpriteKitView
→ Observes GameState for level complete / quit
→ Requires: Steps 11, 14
Step 16: LevelCompleteView
→ Modal overlay on GameView
→ Completion word with animation
→ NEXT LEVEL / NEXT WORLD / LEVELS navigation
→ Requires: Steps 10, 15
Step 17: SettingsView
→ Sheet with toggles
→ Bound to GameState settings
→ Requires: Steps 2, 12
Step 4c: Collectibles system
→ CollectibleNode: SKShapeNode circle, radius 6pt, world accent colour, glow 12pt, pulse animation
→ Loaded from level JSON `collectibles` array (normalised coords)
→ Physics body: sensor, radius 10pt, category = 16
→ Collection sequence: visual burst + trail flash + SFX + haptic
→ collectedCount tracked per attempt, reset on death
→ Requires: Steps 3, 4

Step 4d: Beat-reactive background system
→ Add bpmA/bpmB to WorldDefinition
→ beatInterval = 60.0 / bpm
→ SKAction repeatForever beat timer, key "beatTimer"
→ onBeat(): background brightness +0.08 pulse, obstacle glowWidth 3→6pt pulse, goal ring opacity boost
→ Start on .ready→.playing, stop on .dead/.complete
→ Requires: Steps 4, 5

Step 4b: Parallax background system
→ Background SKSpriteNode at 120% screen size
→ Drifts at 20% of sphere velocity, opposite direction
→ Clamped so black edges never show
→ Lerps back to centre on death/restart
→ Requires: Step 4

Step 18: Audio engine (8 tracks + SFX)
→ Two AVAudioPlayer instances for crossfading
→ 8 music tracks: world1-track-a/b through world4-track-a/b
→ Track A for levels 1-5, Track B for levels 6-10 per world
→ 2-second crossfade on track switch and world transition
→ Music never stops on death — continues through restart
→ SKAction.playSoundFileNamed for all SFX
→ Settings bindings: check musicEnabled/sfxEnabled before every play
→ Requires: Step 2Step 19: Level content — all 40 levels
→ Design and create JSON for worlds 1-4, levels 1-10 each
→ Follow difficulty curve from engagement science section
→ Requires: Steps 5, 6, 8 (need full engine to playtest)
Step 20: World visual themes
→ Background images per world
→ Obstacle styles per world (outline → texture → glow → abstract)
→ Trail colours per world
→ Requires: Steps 5, 8, 19
Step 21: iPad adaptive layout
→ Test all SwiftUI screens on iPad
→ Test game scene scaling on iPad aspect ratios
→ Adjust safe areas, padding, font sizes if needed
→ Requires: All previous steps
Step 21b: Scoring system
→ currentLevelScore, worldScores, totalScore in GameState
→ Points for collectibles (+50), level complete (+200), speed bonus (0-300)
→ parTime field in LevelDefinition JSON
→ Score HUD counter in GameScene (top right, always visible)
→ Score breakdown on LevelCompleteView
→ Persistent worldScores + totalScore in UserDefaults
→ Animated score tick-up (SKAction counter)
→ Requires: Steps 19, 16

Step 21c: IntermissionScene + IntermissionView
→ IntermissionScene: SKScene, ball fixed Y, obstacles scroll down, left/right dodge
→ Speed starts 400pt/s, +8% every 3 seconds, uncapped
→ Score accumulates in real time (speed × 0.1 per frame), ×1.5 at 15s, ×2.0 at 30s
→ Trigger: GameState.shouldTriggerIntermission(world:level:) — fires after levels 5 + 10
→ IntermissionView: SwiftUI wrapper, score HUD, timer, no pause/quit
→ "INTERMISSION" voice drop SFX + dubstep music track
→ On death: hard music cut, "SURVIVED X SECONDS" screen, auto-advance to next level
→ Integrate with scoring system: intermission score added to world total
→ Requires: Steps 21b, 15, 18

Step 22: Polish pass
→ Animations, transitions, particle tuning
→ Performance profiling (60fps target)
→ Accessibility: VoiceOver labels on all interactive elements
→ Requires: All previous steps
Step 23: App Store preparation
→ App icon (1024×1024)
→ Screenshots (6.7" and 6.1" iPhone, iPad)
→ App Store description, keywords, category
→ Privacy policy URL (required — can be a simple static page)
→ Requires: All previous steps
```
---

### 5.10 Intermission Mode — Full Spec

**What it is:** After every 5 levels (levels 5, 10, 15, 20, 25, 30, 35, 40), the game interrupts with a completely different arcade challenge. It fires automatically — no menu, no skip, no choice. You die → it ends → game continues to next level automatically.

**Trigger logic:**
```swift
// In GameState, after marking a level complete:
func shouldTriggerIntermission(world: Int, level: Int) -> Bool {
    // Fires after level 5 and level 10 of every world
    return level == 5 || level == 10
}
```
So intermission fires 8 times total across all 40 levels.

**Transition sequence (entering intermission):**
1. LevelCompleteView dismisses as normal
2. Full screen flash to black (0.3s)
3. Screen is black. Silence for 0.5s.
4. Voice drop plays: "INTERMISSION" — deep, processed, distorted male voice (see audio spec below)
5. Beat drops immediately after voice
6. IntermissionScene loads and gameplay begins instantly

**The IntermissionScene — gameplay spec:**
- Player is a glowing sphere (same as main game)
- Camera perspective: ball is centred, screen scrolls DOWNWARD — ball falls into a dark tunnel at high speed
- Obstacles: rectangular walls protruding from left OR right side of the tunnel — never both simultaneously. Player must dodge left or right.
- Controls: tap LEFT half of screen = dodge left; tap RIGHT half = dodge right
- The ball drifts back to centre automatically when not tapping (spring physics)
- Speed: starts at a comfortable pace, increases every 3 seconds by 8%
- Speed cap: uncapped — it literally becomes impossible. That's intentional.
- Obstacles: start sparse (1 per ~400pt), get denser as speed increases
- Visual: dark tunnel walls, neon edges (world primary colour), motion blur on obstacles at high speed
- No gravity flip in this mode — pure left/right dodge

**Scoring during intermission:**
- Score accumulates at rate of: `currentSpeed * 0.1` points per frame
- Bonus: surviving past 15 seconds = ×1.5 multiplier kicks in
- Bonus: surviving past 30 seconds = ×2.0 multiplier
- On death: score is frozen, added to world total score

**Death in intermission:**
- Same particle burst as main game
- Screen flash white → fades to black (0.3s)
- Text appears: "SURVIVED [X] SECONDS" + points earned, white, centred, 0.5s
- After 1.5s: automatically transition to next level (no tap required)

**IntermissionScene — SpriteKit implementation:**
```swift
class IntermissionScene: SKScene {
    var scrollSpeed: CGFloat = 400  // pts/sec, increases over time
    var timeAlive: TimeInterval = 0
    var score: Int = 0
    
    // Tunnel: two SKShapeNode walls, left edge and right edge
    // Ball: centred horizontally, fixed Y position (camera moves, not ball)
    // Obstacles: spawned above screen, scroll down at scrollSpeed
    // Camera: SKCameraNode that moves downward at scrollSpeed
    // OR: spawn obstacles and scroll everything downward, keep ball Y fixed
    
    // Recommended approach: keep ball at fixed Y (~30% from bottom)
    // Move obstacle nodes downward each frame
    // Ball moves only on X axis (left/right dodge)
}
```

**Audio for intermission:**
- Voice drop: `assets/audio/sfx/intermission-voice.mp3` — "INTERMISSION" spoken deep and distorted
- Music: `assets/audio/music/intermission/intermission-track.mp3` — heavy dubstep/amen break, ~140bpm
- Music starts immediately after voice drop (0.5s delay)
- Music loops for duration of intermission
- On death: music cuts to silence instantly (no fade — hard cut for impact)
- After "SURVIVED X SECONDS" screen: silence → then next world's music crossfades in as next level loads

**IntermissionView — SwiftUI wrapper:**
```
FULL SCREEN (same as GameView)
├── SpriteKitView (IntermissionScene)
├── HUD overlay:
│   ├── Current score (top centre, large, white)
│   ├── Timer (top right, monospaced, white, opacity 0.5)
│   └── Speed indicator (optional — subtle, bottom right)
└── No pause button. No quit. Intermission cannot be escaped.
```

**Navigation integration:**
- GameState gets new property: `isIntermissionActive: Bool`
- After LevelCompleteView confirms level 5 or 10 complete → set `isIntermissionActive = true`
- ContentView/GameView detects this → presents IntermissionView as full screen cover
- On intermission death → `isIntermissionActive = false`, `intermissionScore` saved to GameState
- Next level loads automatically

---

### 5.11 Points & Scoring System — Full Spec

**Design principle:** Score NEVER goes down. Every action earns points. This creates positive reinforcement only — players always feel rewarded.

**Points sources:**

| Event | Points |
|---|---|
| Collecting a collectible | +50 |
| Completing a level | +200 |
| Level speed bonus (under par time) | +0 to +300 (linear, based on how far under par) |
| Intermission survival: per second alive | +`currentSpeed * 0.1` per frame |
| Intermission bonus (15s survived) | ×1.5 multiplier on intermission score |
| Intermission bonus (30s survived) | ×2.0 multiplier on intermission score |

**Par time:** Each level JSON gets a `parTime: TimeInterval` field (e.g. 8.0 seconds). If player completes level in under parTime, speed bonus = `(parTime - actualTime) / parTime * 300` clamped to 300 max.

**Score structure in GameState:**
```swift
// Per-level score (runtime, resets on death — accumulated across attempts in one session)
var currentLevelScore: Int = 0

// Per-world score (persisted)
var worldScores: [Int: Int] = [:]  // worldId → total score

// Total all-time score (persisted) 
var totalScore: Int = 0

// Intermission score (runtime, saved after intermission ends)
var lastIntermissionScore: Int = 0
var lastIntermissionSurvivalTime: TimeInterval = 0
```

**World Final Score:**
When player completes all 10 levels of a world (including both intermissions at levels 5 and 10):
- World score = sum of all level scores + all collectibles collected + both intermission scores
- Displayed on WorldSelectView card as a number (bottom right of card, small, world primary colour)
- Can be beaten — player can replay any level or intermission to improve their world score

**Score display:**
- In-game HUD: running score counter (top right, monospaced font, always visible during gameplay)
- Starts at 0 each level, ticks up in real time as collectibles are grabbed
- Does NOT show world total or all-time total during gameplay — only current level score
- LevelCompleteView: shows level score breakdown (base + collectibles + speed bonus)
- After intermission death screen: shows intermission score
- WorldSelectView card: shows world total score (persistent best)

**Score persistence:**
- `worldScores` and `totalScore` stored in UserDefaults
- Never decremented — only ever updated if new score > stored score
- Wait: actually store CUMULATIVE score not best-per-world — it always goes up as you play more

**Score counter animation:**
- Numbers tick up rapidly when points are awarded (not instant)
- Collectible collect: +50 animates over 0.3s
- Level complete base: +200 animates over 0.5s  
- Speed bonus: ticks up over 1.0s (dramatic)
- Use `SKAction` sequence with custom counter node in SpriteKit, or SwiftUI `withAnimation` on the HUD number

---

### 5.9 Tech Constraints (non-negotiable — repeat from context doc)
- SwiftUI only — no UIKit (except for haptic generators which require UIKit import)
- SpriteKit for all physics and game rendering
- @Observable for all state management (not ObservableObject/@Published)
- async/await for any async operations
- iOS 17+ minimum deployment target
- iPad layout required (adaptive, not just scaled iPhone)
- 2D only — no SceneKit, no Metal custom shaders, no 3D rendering
- No third-party packages without human approval first
- No backend, no API calls, fully offline
- Dark mode only (no light mode variant)
- Portrait orientation only
- Target: 60fps on iPhone 12 and above with full trail rendering
-----*End of blueprint. This document contains everything needed to go from zero to App Store
submission. Build Phase 1 first. If the flip + trail doesn’t feel incredible, stop and iterate.
Everything else is decoration on top of that core feel.*