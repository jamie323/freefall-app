import SwiftUI
import AVFoundation

struct LevelCompleteView: View {
    let world: WorldDefinition
    let level: LevelDefinition
    let completionWord: String
    let collectiblesCollected: Int
    let speedBonus: Int
    let isNewBest: Bool
    let bestScore: Int
    let stars: Int
    let onNextLevel: () -> Void
    let onReplay: () -> Void
    let onLevels: () -> Void

    @State private var showButtons = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: CGFloat = 0
    @State private var showScoreDetails = false
    @State private var showStars = false
    @State private var newBestScale: CGFloat = 0.3
    @State private var scratchPlayer: AVAudioPlayer?

    private var isLastLevel: Bool {
        level.levelId == 10
    }

    private var isLastLevelOverall: Bool {
        world.id == 4 && level.levelId == 10
    }

    private var baseLevelScore: Int { 200 }
    private var collectibleScore: Int { collectiblesCollected * 50 }
    private var totalLevelScore: Int { baseLevelScore + collectibleScore + speedBonus }

    var body: some View {
        ZStack {
            // Semi-transparent black background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Completion word with spring animation
                Text(completionWord)
                    .font(.system(size: 80, weight: .black, design: .default))
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
                        // Record scratch SFX on completion word appearance
                        playRecordScratch()

                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.3).delay(0.05)) {
                            scale = 1.0
                            opacity = 1.0
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                                showStars = true
                            }
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                            withAnimation(.easeIn(duration: 0.3)) {
                                showScoreDetails = true
                            }
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                            withAnimation(.easeIn(duration: 0.3)) {
                                showButtons = true
                            }
                        }

                        if isNewBest {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) {
                                    newBestScale = 1.0
                                }
                            }
                        }
                    }

                // 3-Star display
                if showStars {
                    HStack(spacing: 8) {
                        ForEach(1...3, id: \.self) { i in
                            Image(systemName: i <= stars ? "star.fill" : "star")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(i <= stars ? world.primaryColor : .white.opacity(0.2))
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // NEW BEST badge
                if isNewBest && showScoreDetails {
                    Text("NEW BEST!")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.6), radius: 8)
                        .scaleEffect(newBestScale)
                }

                if showScoreDetails {
                    VStack(spacing: 6) {
                        Text("LEVEL SCORE")
                            .font(.system(size: 16, weight: .heavy, design: .monospaced))
                            .foregroundStyle(world.primaryColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Base: +\(baseLevelScore)")
                            Text("Collectibles: +\(collectiblesCollected)×50")
                            Text("Speed bonus: +\(speedBonus)")
                            Text("Total: \(totalLevelScore)")
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                        }
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(world.primaryColor)

                        if bestScore > 0 {
                            Text("BEST: \(bestScore)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top, 12)
                    .transition(.opacity)
                }

                Spacer()

                // Bottom buttons
                HStack(spacing: 12) {
                    Button(action: onLevels) {
                        Text("LEVELS")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    Button(action: onReplay) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 13, weight: .bold))
                            Text("REPLAY")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                    }

                    Button(action: onNextLevel) {
                        Text(isLastLevelOverall ? "DONE" : (isLastLevel ? "NEXT WORLD →" : "NEXT →"))
                            .font(.system(size: 16, weight: .heavy, design: .default))
                            .foregroundStyle(world.primaryColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .border(world.primaryColor, width: 1)
                            .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .opacity(showButtons ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func playRecordScratch() {
        guard let url = Bundle.main.url(forResource: "record-scratch", withExtension: "mp3", subdirectory: "audio/sfx") else { return }
        scratchPlayer = try? AVAudioPlayer(contentsOf: url)
        scratchPlayer?.volume = 0.8
        scratchPlayer?.play()
    }
}

#Preview {
    ZStack {
        Color.black
        Text("LevelCompleteView Preview")
            .foregroundColor(.white)
    }
}
