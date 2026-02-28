import SwiftUI

struct GameView: View {
    @Environment(GameState.self) private var gameState

    let world: WorldDefinition
    let level: LevelDefinition
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            SpriteKitView(level: level, world: world)
                .ignoresSafeArea()

            VStack(alignment: .leading) {
                HStack(spacing: 16) {
                    // Level number (top left)
                    Text("L\(level.levelId)")
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Spacer()
                    
                    // Pause button (top right)
                    Button(action: {
                        // Pause functionality will be added in audio engine step
                    }) {
                        Image(systemName: "pause.circle")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(16)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationBarBackButtonHidden(true)
    }
}
