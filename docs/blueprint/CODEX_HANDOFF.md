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
Step 18: Audio engine
→ AVAudioPlayer for music (looping, per-world tracks)
→ SKAction for SFX
→ Crossfade on world transition
→ Respect musicEnabled / sfxEnabled settings
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