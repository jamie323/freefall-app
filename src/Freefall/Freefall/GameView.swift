import SwiftUI

struct GameView: View {
    @Environment(GameState.self) private var gameState

    let world: WorldDefinition
    let level: LevelDefinition
    let onQuit: () -> Void
    let onNextLevel: (Int) -> Void

    @State private var proxy = SceneProxy()
    @State private var showLevelComplete = false
    @State private var completionWord = "CLEAN"
    @State private var speedBonus = 0

    private var isLastLevelInWorld: Bool { level.levelId == 10 }
    private var isLastLevelOverall: Bool { world.id == 4 && level.levelId == 10 }

    private func wireLevelCompleteCallback() {
        if let scene = proxy.coordinator?.scene {
            scene.levelCompleted = { [self] in
                self.completionWord = scene.lastCompletionWord
                self.speedBonus = scene.lastSpeedBonus
                DispatchQueue.main.async {
                    withAnimation(.easeIn(duration: 0.2)) {
                        self.showLevelComplete = true
                    }
                }
            }
        } else {
            // Scene not ready yet — retry on next frame
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                wireLevelCompleteCallback()
            }
        }
    }

    var body: some View {
        ZStack {
            SpriteKitView(level: level, world: world, proxy: proxy)
                .ignoresSafeArea()

            // Full-screen tap target — SpriteKit gesture handler
            Color.white.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    proxy.handleTap()
                }

            // HUD — level label (non-interactive)
            Text("L\(level.levelId)")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 16)
                .padding(.top, 16)
                .allowsHitTesting(false)

            // Pause button
            Button(action: { }) {
                Image(systemName: "pause.circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 4)
            .padding(.top, 8)

            // Level complete overlay
            if showLevelComplete {
                LevelCompleteView(
                    world: world,
                    level: level,
                    completionWord: completionWord,
                    collectiblesCollected: proxy.coordinator?.scene.collectiblesCollectedThisAttempt ?? 0,
                    speedBonus: speedBonus,
                    onNextLevel: {
                        showLevelComplete = false
                        if isLastLevelOverall {
                            onQuit()
                        } else if isLastLevelInWorld {
                            // Go back to world select for next world
                            onQuit()
                        } else {
                            onNextLevel(level.levelId + 1)
                        }
                    },
                    onLevels: {
                        showLevelComplete = false
                        onQuit()
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Wire immediately — proxy.coordinator is set synchronously in makeCoordinator
            // Retry loop handles edge case where scene isn't ready yet
            wireLevelCompleteCallback()
        }
    }
}
