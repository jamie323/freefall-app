import SwiftUI

struct LevelSelectView: View {
    @Environment(GameState.self) private var gameState

    let world: WorldDefinition
    let onBack: () -> Void
    let onLevelSelected: (Int) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                        .padding(.top, 8)

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

                    // Progress indicator
                    let completed = gameState.completedCountForWorld(world: world.id)
                    HStack(spacing: 8) {
                        Text("\(completed)/10")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(world.primaryColor)
                        Text("LEVELS COMPLETE")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .scrollIndicators(.hidden)
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

            VStack(spacing: 2) {
                Text(world.name)
                    .font(.system(size: 22, weight: .black, design: .default))
                    .foregroundStyle(world.primaryColor)
                Text("WORLD \(world.id)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(world.primaryColor.opacity(0.5))
            }

            Spacer()

            // Balance the back button
            Spacer().frame(width: 44)
        }
        .padding(.horizontal, 24)
    }

    private func isNextLevel(_ levelId: Int) -> Bool {
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(isCompleted ? 0.05 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )

                if isCompleted {
                    VStack(spacing: 4) {
                        Text("\(levelId)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(world.primaryColor)
                    }
                } else if isUnlocked {
                    Text("\(levelId)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(world.primaryColor)
                } else {
                    VStack(spacing: 4) {
                        Text("\(levelId)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.15))
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                }
            }
            .aspectRatio(1, contentMode: .fill)
            .opacity(isUnlocked || isCompleted ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .scaleEffect(isNextToPlay && isPulsing ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
        .onAppear {
            if isNextToPlay { isPulsing = true }
        }
    }

    private var borderColor: Color {
        if isCompleted { return world.primaryColor.opacity(0.5) }
        if isNextToPlay { return world.primaryColor }
        if isUnlocked { return world.primaryColor.opacity(0.35) }
        return .white.opacity(0.12)
    }

    private var borderWidth: CGFloat {
        if isNextToPlay { return 2 }
        if isCompleted || isUnlocked { return 1.5 }
        return 1
    }
}
