import SwiftUI

struct CosmeticsView: View {
    let cosmeticsManager: CosmeticsManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .accessibilityLabel("Close customization")
                    Spacer()
                    Text("CUSTOMIZE")
                        .font(.system(size: 22, weight: .black, design: .default))
                        .foregroundStyle(.white)
                    Spacer()
                    // Balance spacer
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Tab picker
                HStack(spacing: 0) {
                    tabButton("TRAILS", index: 0)
                    tabButton("BALL", index: 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Content
                ScrollView {
                    if selectedTab == 0 {
                        trailGrid
                    } else {
                        ballSkinGrid
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index } }) {
            Text(title)
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Rectangle()
                        .fill(selectedTab == index ? .white.opacity(0.08) : .clear)
                )
                .overlay(
                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(selectedTab == index ? .white : .clear),
                    alignment: .bottom
                )
        }
    }

    // MARK: - Trail Grid

    private var trailGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(CosmeticsLibrary.trails) { trail in
                trailCard(trail)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private func trailCard(_ trail: TrailStyle) -> some View {
        let isUnlocked = cosmeticsManager.isTrailUnlocked(trail.id)
        let isSelected = cosmeticsManager.selectedTrailId == trail.id
        let progress = cosmeticsManager.unlockProgress(for: trail.unlockRequirement)

        return Button(action: {
            if isUnlocked {
                cosmeticsManager.selectTrail(trail.id)
            }
        }) {
            VStack(spacing: 8) {
                // Trail preview — gradient line
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.04))
                        .frame(height: 60)

                    if trail.id == "default" {
                        // Show "WORLD" indicator — uses level's own colors
                        Text("AUTO")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    } else {
                        // Gradient preview line
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [trail.startColor, trail.endColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 6)
                            .padding(.horizontal, 16)
                            .opacity(isUnlocked ? 1 : 0.3)
                    }

                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }

                // Name + unlock status
                Text(trail.name)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(isUnlocked ? .white : .white.opacity(0.3))

                if !isUnlocked {
                    Text("\(progress.current)/\(progress.target)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? .white : .white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .opacity(isUnlocked ? 1 : 0.6)
        }
        .disabled(!isUnlocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trailAccessibilityLabel(trail, isUnlocked: isUnlocked, isSelected: isSelected, progress: progress))
        .accessibilityAddTraits(isUnlocked ? .isButton : [])
        .accessibilityHint(isUnlocked ? (isSelected ? "Currently selected" : "Double tap to select") : "")
    }

    private func trailAccessibilityLabel(_ trail: TrailStyle, isUnlocked: Bool, isSelected: Bool, progress: (current: Int, target: Int)) -> String {
        if isUnlocked {
            return "\(trail.name) trail\(isSelected ? ", selected" : "")"
        }
        return "\(trail.name) trail, locked, \(progress.current) of \(progress.target)"
    }

    // MARK: - Ball Skin Grid

    private var ballSkinGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(CosmeticsLibrary.ballSkins) { skin in
                ballSkinCard(skin)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private func ballSkinCard(_ skin: BallSkin) -> some View {
        let isUnlocked = cosmeticsManager.isBallSkinUnlocked(skin.id)
        let isSelected = cosmeticsManager.selectedBallSkinId == skin.id
        let progress = cosmeticsManager.unlockProgress(for: skin.unlockRequirement)

        return Button(action: {
            if isUnlocked {
                cosmeticsManager.selectBallSkin(skin.id)
            }
        }) {
            VStack(spacing: 8) {
                // Ball preview
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.04))
                        .frame(height: 60)

                    Circle()
                        .fill(skin.usesWorldColor ? .white : skin.color)
                        .frame(width: 28, height: 28)
                        .shadow(color: (skin.usesWorldColor ? .cyan : skin.glowColor).opacity(0.6), radius: 12)
                        .opacity(isUnlocked ? 1 : 0.3)

                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }

                Text(skin.name)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(isUnlocked ? .white : .white.opacity(0.3))

                if !isUnlocked {
                    Text("\(progress.current)/\(progress.target)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? .white : .white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .opacity(isUnlocked ? 1 : 0.6)
        }
        .disabled(!isUnlocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ballAccessibilityLabel(skin, isUnlocked: isUnlocked, isSelected: isSelected, progress: progress))
        .accessibilityAddTraits(isUnlocked ? .isButton : [])
        .accessibilityHint(isUnlocked ? (isSelected ? "Currently selected" : "Double tap to select") : "")
    }

    private func ballAccessibilityLabel(_ skin: BallSkin, isUnlocked: Bool, isSelected: Bool, progress: (current: Int, target: Int)) -> String {
        if isUnlocked {
            return "\(skin.name) ball\(isSelected ? ", selected" : "")"
        }
        return "\(skin.name) ball, locked, \(progress.current) of \(progress.target)"
    }
}
