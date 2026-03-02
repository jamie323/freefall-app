import SwiftUI

struct GameView: View {
    @Environment(GameState.self) private var gameState

    let world: WorldDefinition
    let level: LevelDefinition
    let onQuit: () -> Void

    // Scene reference so the SwiftUI tap gesture can call scene methods directly
    @State private var sceneCoordinator: SpriteKitView.Coordinator?

    var body: some View {
        ZStack {
            SpriteKitView(level: level, world: world, coordinatorBinding: $sceneCoordinator)
                .ignoresSafeArea()

            // Full-screen tap target — sits above SpriteKit, below HUD buttons
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    sceneCoordinator?.handleTap()
                }

            // HUD — decorative label, non-interactive
            Text("L\(level.levelId)")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 16)
                .padding(.top, 16)
                .allowsHitTesting(false)

            // Pause button — top right, interactive (sits on top of tap layer)
            Button(action: {
                // Pause functionality to be added
            }) {
                Image(systemName: "pause.circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 4)
            .padding(.top, 8)
        }
        .navigationBarBackButtonHidden(true)
    }
}
