import SwiftUI

struct LevelCompleteView: View {
    let world: WorldDefinition
    let level: LevelDefinition
    let completionWord: String
    let onNextLevel: () -> Void
    let onLevels: () -> Void

    @State private var showButtons = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: CGFloat = 0

    private var isLastLevel: Bool {
        level.levelId == 10
    }

    private var isLastLevelOverall: Bool {
        world.id == 4 && level.levelId == 10
    }

    var body: some View {
        ZStack {
            // Semi-transparent black background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Completion word with spring animation
                Text(completionWord)
                    .font(.system(size: 80, weight: .black, design: .condensed))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [world.primaryColor, .white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: world.primaryColor.opacity(0.4), radius: 20)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.4).delay(0.1)) {
                            scale = 1.0
                            opacity = 1.0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation(.easeIn(duration: 0.3)) {
                                showButtons = true
                            }
                        }
                    }

                Spacer()

                // Bottom buttons
                HStack(spacing: 16) {
                    Button(action: onLevels) {
                        Text("← LEVELS")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()

                    Button(action: onNextLevel) {
                        Text(isLastLevelOverall ? "YOU'RE DONE 🔥" : (isLastLevel ? "NEXT WORLD →" : "NEXT LEVEL →"))
                            .font(.system(size: 16, weight: .heavy, design: .condensed))
                            .foregroundStyle(world.primaryColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .border(world.primaryColor, width: 1)
                            .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .opacity(showButtons ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ZStack {
        Color.black

        LevelCompleteView(
            world: WorldLibrary.allWorlds[0],
            level: LevelDefinition(
                worldId: 1,
                levelId: 1,
                launchPosition: CGPoint(x: 0.1, y: 0.5),
                launchVelocity: CGVector(dx: 150, dy: 0),
                goalPosition: CGPoint(x: 0.85, y: 0.5),
                goalRadius: 35,
                initialGravityDown: true,
                parFlips: 3,
                obstacles: []
            ),
            completionWord: "CLEAN",
            onNextLevel: {},
            onLevels: {}
        )
    }
}
