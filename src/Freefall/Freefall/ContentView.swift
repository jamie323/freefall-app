import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var gameScene: GameScene?
    @State private var hasLoadedLevel = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let scene = gameScene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
            } else {
                Text("Loading Freefall...")
                    .foregroundStyle(Color.cyan)
            }
        }
        .onAppear {
            setupGameScene()
        }
    }

    private func setupGameScene() {
        guard !hasLoadedLevel else { return }
        hasLoadedLevel = true

        let scene = GameScene(size: CGSize(width: 375, height: 812))
        scene.scaleMode = .resizeFill

        do {
            let level = try LevelLoader().loadLevel(world: 1, level: 1)
            scene.levelDefinition = level
        } catch {
            print("Failed to load level: \(error)")
        }

        scene.hapticsEnabled = true
        scene.levelCompleted = {
            print("LEVEL COMPLETE")
        }

        gameScene = scene
    }
}

#Preview {
    ContentView()
}
