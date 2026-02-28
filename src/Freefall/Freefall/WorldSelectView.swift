import SwiftUI
import UIKit

struct WorldSelectView: View {
    @Environment(GameState.self) private var gameState

    let worlds: [WorldDefinition]
    let onBack: () -> Void
    let onWorldSelected: (WorldDefinition) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    ForEach(worlds) { world in
                        WorldCardView(
                            world: world,
                            isUnlocked: gameState.isWorldUnlocked(world: world.id),
                            completedCount: gameState.completedCountForWorld(world: world.id),
                            onUnlockedTap: {
                                gameState.currentWorldId = world.id
                                onWorldSelected(world)
                            }
                        )
                    }
                    Spacer().frame(height: 12)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.hex("#00D4FF"))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.hex("#00D4FF").opacity(0.3), lineWidth: 1)
                    )
            }
            Spacer()
            Text("SELECT A WORLD")
                .font(.system(.title2, design: .rounded, weight: .black))
                .foregroundStyle(Color.hex("#00D4FF"))
            Spacer()
            Spacer().frame(width: 44)
        }
    }
}

private struct WorldCardView: View {
    let world: WorldDefinition
    let isUnlocked: Bool
    let completedCount: Int
    let onUnlockedTap: () -> Void

    @State private var shakeTrigger: CGFloat = 0

    var body: some View {
        Button(action: handleTap) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(world.primaryColor.opacity(0.7), lineWidth: 2)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black)
                            .shadow(color: world.primaryColor.opacity(0.35), radius: 18, x: 0, y: 12)
                    )
                    .overlay(gradientOverlay)

                VStack(alignment: .leading, spacing: 12) {
                    Text(world.name)
                        .font(.system(size: 28, weight: .black, design: .condensed))
                        .foregroundStyle(world.primaryColor)
                        .shadow(color: world.primaryColor.opacity(0.35), radius: 10, x: 0, y: 4)
                        .lineLimit(1)
                    progressRow
                }
                .padding(20)

                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                }
            }
            .frame(height: 120)
            .opacity(isUnlocked ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .modifier(ShakeEffect(amount: isUnlocked ? 0 : 10, shakesPerUnit: 3, animatableData: shakeTrigger))
    }

    private var gradientOverlay: some View {
        LinearGradient(
            colors: [world.primaryColor.opacity(0.08), world.accentColor.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var progressRow: some View {
        HStack {
            Text(isUnlocked ? "\(completedCount)/10 completed" : "LOCKED")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isUnlocked ? .white.opacity(0.7) : .white.opacity(0.5))
            Spacer()
            Image(systemName: "arrow.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(world.primaryColor)
                .opacity(isUnlocked ? 1 : 0)
        }
    }

    private func handleTap() {
        if isUnlocked {
            onUnlockedTap()
            if !UIAccessibility.isGuidedAccessEnabled {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else {
            triggerShake()
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
        }
    }

    private func triggerShake() {
        withAnimation(.easeInOut(duration: 0.35)) {
            shakeTrigger += 1
        }
    }
}

private struct ShakeEffect: GeometryEffect {
    var amount: CGFloat
    var shakesPerUnit: CGFloat
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
