import SwiftUI

struct GameView: View {
    @Environment(GameState.self) private var gameState

    let world: WorldDefinition
    let level: LevelDefinition
    let onQuit: () -> Void

    var body: some View {
        SpriteKitView(level: level, world: world)
            .ignoresSafeArea()
            .overlay(alignment: .topLeading) {
                // Level label — top left corner, decorative only
                Text("L\(level.levelId)")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.leading, 16)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                // Pause button — top right corner, interactive
                Button(action: {
                    // Pause functionality to be added
                }) {
                    Image(systemName: "pause.circle")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(12)
                }
                .padding(.trailing, 4)
                .padding(.top, 8)
            }
            .navigationBarBackButtonHidden(true)
    }
}
