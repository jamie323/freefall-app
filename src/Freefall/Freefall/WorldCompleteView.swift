import SwiftUI

struct WorldCompleteView: View {
    let world: WorldDefinition
    let nextWorld: WorldDefinition?
    let totalStars: Int
    let worldBestScore: Int
    let onContinue: () -> Void

    @State private var titleScale: CGFloat = 0.5
    @State private var titleOpacity: CGFloat = 0
    @State private var showStats = false
    @State private var showNext = false
    @State private var showButton = false

    private var isGameComplete: Bool { nextWorld == nil }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Big world name
                VStack(spacing: 8) {
                    Text(isGameComplete ? "GAME COMPLETE" : "WORLD COMPLETE")
                        .font(.system(size: 16, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))

                    Text(world.name)
                        .font(.system(size: 52, weight: .black, design: .default))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [world.primaryColor, .white],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: world.primaryColor.opacity(0.6), radius: 20)
                }
                .scaleEffect(titleScale)
                .opacity(titleOpacity)

                // Stars earned in this world
                if showStats {
                    VStack(spacing: 8) {
                        // Star count for this world
                        HStack(spacing: 4) {
                            ForEach(0..<30, id: \.self) { i in
                                Image(systemName: i < totalStars ? "star.fill" : "star")
                                    .font(.system(size: i < totalStars ? 10 : 8))
                                    .foregroundStyle(i < totalStars ? .yellow : .white.opacity(0.1))
                            }
                        }

                        Text("WORLD SCORE: \(worldBestScore)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(world.primaryColor.opacity(0.7))
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Next world teaser
                if showNext, let next = nextWorld {
                    VStack(spacing: 8) {
                        Text("NEXT UP")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))

                        Text(next.name)
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(next.primaryColor)
                            .shadow(color: next.primaryColor.opacity(0.5), radius: 12)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()

                if showButton {
                    Button(action: onContinue) {
                        Text(isGameComplete ? "DONE" : "CONTINUE →")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(nextWorld?.primaryColor ?? world.primaryColor)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(nextWorld?.primaryColor ?? world.primaryColor, lineWidth: 2)
                            )
                    }
                    .transition(.opacity)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
            titleScale = 1.0
            titleOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                showStats = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showNext = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeIn(duration: 0.3)) {
                showButton = true
            }
        }
    }
}
