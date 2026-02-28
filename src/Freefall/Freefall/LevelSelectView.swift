import SwiftUI

struct LevelSelectView: View {
    @Environment(GameState.self) private var gameState

    let world: WorldDefinition
    let onBack: () -> Void
    let onLevelSelected: (Int) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                header
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(1...10, id: \.self) { levelId in
                        LevelCellView(
                            levelId: levelId,
                            world: world,
                            isCompleted: gameState.completedLevels.contains("W\(world.id)L\(levelId)"),
                            isUnlocked: gameState.isLevelUnlocked(world: world.id, level: levelId),
                            isNextToPlay: isNextLevel(levelId),
                            onTap: {
                                if gameState.isLevelUnlocked(world: world.id, level: levelId) {
                                    gameState.currentLevelId = levelId
                                    onLevelSelected(levelId)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .padding(.top, 24)
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(world.primaryColor)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(world.primaryColor.opacity(0.3), lineWidth: 1))
            }
            
            Spacer()
            
            Text(world.name)
                .font(.system(size: 22, weight: .black, design: .condensed))
                .foregroundStyle(world.primaryColor)
            
            Spacer()
            
            Spacer().frame(width: 44)
        }
        .padding(.horizontal, 24)
    }

    private func isNextLevel(_ levelId: Int) -> Bool {
        // Find the first unlocked level
        for level in 1...10 {
            if gameState.isLevelUnlocked(world: world.id, level: level) &&
               !gameState.completedLevels.contains("W\(world.id)L\(level)") {
                return level == levelId
            }
        }
        return false
    }
}

private struct LevelCellView: View {
    let levelId: Int
    let world: WorldDefinition
    let isCompleted: Bool
    let isUnlocked: Bool
    let isNextToPlay: Bool
    let onTap: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )

                // Completed state: show checkmark
                if isCompleted {
                    VStack {
                        HStack {
                            Text("\(levelId)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(world.primaryColor)
                        }
                        .padding(12)
                        
                        Spacer()
                    }
                } else {
                    // Unlocked (next to play) or locked state
                    VStack(spacing: 8) {
                        Spacer()
                        
                        Text("\(levelId)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(isUnlocked ? world.primaryColor : .white.opacity(0.2))
                        
                        if !isUnlocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        
                        Spacer()
                    }
                }
            }
            .aspectRatio(1, contentMode: .fill)
            .opacity(isUnlocked || isCompleted ? 1 : 0.3)
        }
        .buttonStyle(.plain)
        .modifier(PulsingBorderModifier(isActive: isNextToPlay && isPulsing))
        .onAppear {
            if isNextToPlay {
                startPulsing()
            }
        }
    }

    private var borderColor: Color {
        if isCompleted {
            return world.primaryColor.opacity(0.5)
        } else if isNextToPlay {
            return world.primaryColor
        } else if isUnlocked {
            return world.primaryColor.opacity(0.3)
        } else {
            return .white.opacity(0.15)
        }
    }

    private var borderWidth: CGFloat {
        if isCompleted {
            return 1.5
        } else if isNextToPlay {
            return 2
        } else if isUnlocked {
            return 1.5
        } else {
            return 1
        }
    }

    private func startPulsing() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

private struct PulsingBorderModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content
                .opacity(0.5 + (0.5 * (isActive ? 1 : 0)))
        } else {
            content
        }
    }
}
