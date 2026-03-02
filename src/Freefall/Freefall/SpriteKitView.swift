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

    func makeCoordinator() -> Coordinator {
        let c = Coordinator(gameState: gameState)
        proxy.coordinator = c   // plain assignment — no binding, no state mutation
        return c
    }

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.backgroundColor = .clear
        view.ignoresSiblingOrder = true
        view.isUserInteractionEnabled = false
        context.coordinator.configureIfNeeded(with: view)
        context.coordinator.update(level: level, world: world)
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        context.coordinator.configureIfNeeded(with: uiView)
        context.coordinator.update(level: level, world: world)
    }

    final class Coordinator {
        let scene: GameScene
        private var cachedLevelID: String?
        private var cachedWorldID: Int?

        init(gameState: GameState) {
            scene = GameScene(size: UIScreen.main.bounds.size, gameState: gameState)
            scene.scaleMode = .resizeFill
        }

        func configureIfNeeded(with view: SKView) {
            let boundsSize = view.bounds.size
            if boundsSize != .zero {
                scene.size = boundsSize
            }
            if view.scene !== scene {
                view.presentScene(scene)
            }
        }

        func update(level: LevelDefinition, world: WorldDefinition) {
            guard cachedLevelID != level.id || cachedWorldID != world.id else { return }
            scene.loadLevel(level, world: world)
            cachedLevelID = level.id
            cachedWorldID = world.id
        }

        func handleTap() {
            scene.handleTap()
        }
    }
}
