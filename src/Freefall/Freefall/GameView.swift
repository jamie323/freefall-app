import SwiftUI

struct GameView: View {
    @Environment(GameState.self) private var gameState

    let world: WorldDefinition
    let level: LevelDefinition
    let onQuit: () -> Void

    // SceneProxy is a plain class — @State holds it stable across re-renders,
    // but mutations to proxy.coordinator don't trigger SwiftUI updates.
    @State private var proxy = SceneProxy()

    var body: some View {
        ZStack {
            SpriteKitView(level: level, world: world, proxy: proxy)
                .ignoresSafeArea()

            // Full-screen invisible tap target — SwiftUI owns all taps,
            // routes them directly into the scene via proxy.
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    proxy.handleTap()
                }

            // HUD — level label, decorative only
            Text("L\(level.levelId)")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 16)
                .padding(.top, 16)
                .allowsHitTesting(false)

            // Pause button — sits above tap layer in ZStack, gets priority
            Button(action: {
                // Pause to be wired
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
