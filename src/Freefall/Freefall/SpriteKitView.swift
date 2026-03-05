import SpriteKit
import SwiftUI

/// Reference box so GameView can hold a stable pointer to the scene
/// without triggering SwiftUI state updates.
final class SceneProxy {
    var coordinator: SpriteKitView.Coordinator?
    func handleTap() { coordinator?.handleTap() }
}

struct SpriteKitView: UIViewRepresentable {
    @Environment(GameState.self) private var gameState

    let level: LevelDefinition
    let world: WorldDefinition
    let proxy: SceneProxy
    var audioManager: AudioManager?

    func makeCoordinator() -> Coordinator {
        let c = Coordinator(gameState: gameState, audioManager: audioManager)
        proxy.coordinator = c
        return c
    }

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.backgroundColor = .clear
        view.ignoresSiblingOrder = true
        view.isUserInteractionEnabled = false

        // Store pending level — will load once scene has real size
        context.coordinator.pendingLevel = level
        context.coordinator.pendingWorld = world

        // Present scene now; level loads when didChangeSize fires with real size
        context.coordinator.presentScene(in: view)
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        // Re-present only if scene was evicted
        if uiView.scene !== context.coordinator.scene {
            context.coordinator.presentScene(in: uiView)
        }
        // Queue level update — coordinator will apply once size is valid
        context.coordinator.queueLevelIfNeeded(level: level, world: world)
    }

    final class Coordinator {
        let scene: GameScene
        var pendingLevel: LevelDefinition?
        var pendingWorld: WorldDefinition?
        private var cachedLevelID: String?
        private var cachedWorldID: Int?

        init(gameState: GameState, audioManager: AudioManager?) {
            // Use screen size as initial hint; resizeFill will correct it
            let screenSize = UIScreen.main.bounds.size
            scene = GameScene(size: screenSize, gameState: gameState)
            scene.audioManager = audioManager
            // Do NOT use resizeFill — it sets scene size to zero before layout
            scene.scaleMode = .resizeFill
            // Notify us when size is set so we can load the level
            scene.onSizeReady = { [weak self] in
                self?.applyPendingLevel()
            }
        }

        func presentScene(in view: SKView) {
            view.presentScene(scene)
        }

        func queueLevelIfNeeded(level: LevelDefinition, world: WorldDefinition) {
            guard cachedLevelID != level.id || cachedWorldID != world.id else { return }
            pendingLevel = level
            pendingWorld = world
            // Apply immediately if scene already has valid size
            if scene.size.width > 0 && scene.size.height > 0 {
                applyPendingLevel()
            }
        }

        func applyPendingLevel() {
            guard let level = pendingLevel,
                  let world = pendingWorld,
                  scene.size.width > 0,
                  scene.size.height > 0 else { return }
            guard cachedLevelID != level.id || cachedWorldID != world.id else { return }
            scene.loadLevel(level, world: world)
            cachedLevelID = level.id
            cachedWorldID = world.id
            pendingLevel = nil
            pendingWorld = nil
        }

        func handleTap() {
            scene.handleTap()
        }
    }
}
