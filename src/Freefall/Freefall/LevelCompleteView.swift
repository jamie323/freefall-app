import SwiftUI
import AVFoundation

struct LevelCompleteView: View {
    let world: WorldDefinition
    let level: LevelDefinition
    let completionWord: String
    let collectiblesCollected: Int
    let totalCollectibles: Int
    let speedBonus: Int
    let totalScore: Int
    let isNewBest: Bool
    let bestScore: Int
    let stars: Int
    let audioManager: AudioManager?
    let onNextLevel: () -> Void
    let onReplay: () -> Void
    let onLevels: () -> Void

    // Animation states
    @State private var showButtons = false
    @State private var wordScale: CGFloat = 0.5
    @State private var wordOpacity: CGFloat = 0
    @State private var showStars = false
    @State private var showCollectibles = false
    @State private var showScoreSection = false
    @State private var displayedScore: Int = 0
    @State private var scoreCountFinished = false
    @State private var showRank = false
    @State private var rankScale: CGFloat = 0.3
    @State private var showBreakdown = false
    @State private var showNewBest = false
    @State private var newBestScale: CGFloat = 0.3
    @State private var scratchPlayer: AVAudioPlayer?
    @State private var countTimer: Timer?

    private var isLastLevel: Bool { level.levelId == 10 }
    private var isLastLevelOverall: Bool {
        world.id == WorldLibrary.allWorlds.count && level.levelId == 10
    }

    private var allCollected: Bool {
        totalCollectibles > 0 && collectiblesCollected >= totalCollectibles
    }

    // Score rank — S rank REQUIRES all collectibles collected
    private var scoreRank: String {
        if allCollected && totalScore >= 550 { return "S" }
        if totalScore >= 500 { return "A" }
        if totalScore >= 350 { return "B" }
        return "C"
    }

    private var rankColor: Color {
        switch scoreRank {
        case "S": return .yellow
        case "A": return world.primaryColor
        case "B": return .white
        default: return .white.opacity(0.5)
        }
    }

    var body: some View {
        ZStack {
            // Semi-transparent black background — blocks taps from reaching game beneath
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())

            VStack(spacing: 14) {
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
                    .shadow(color: world.primaryColor.opacity(0.5), radius: 24)
                    .scaleEffect(wordScale)
                    .opacity(wordOpacity)
                    .onAppear { startAnimationSequence() }

                // 3-Star display
                if showStars {
                    HStack(spacing: 10) {
                        ForEach(1...3, id: \.self) { i in
                            Image(systemName: i <= stars ? "star.fill" : "star")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(i <= stars ? world.primaryColor : .white.opacity(0.2))
                                .shadow(color: i <= stars ? world.primaryColor.opacity(0.5) : .clear, radius: 6)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(stars) of 3 stars")
                }

                // === COLLECTIBLE DIAMONDS — the hook ===
                if showCollectibles && totalCollectibles > 0 {
                    VStack(spacing: 4) {
                        // Diamond indicators
                        HStack(spacing: 12) {
                            ForEach(0..<totalCollectibles, id: \.self) { i in
                                Image(systemName: i < collectiblesCollected ? "diamond.fill" : "diamond")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(
                                        i < collectiblesCollected
                                            ? world.primaryColor
                                            : .white.opacity(0.15)
                                    )
                                    .shadow(
                                        color: i < collectiblesCollected
                                            ? world.primaryColor.opacity(0.6)
                                            : .clear,
                                        radius: 6
                                    )
                            }
                        }

                        if allCollected {
                            Text("ALL COLLECTED")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundStyle(world.primaryColor)
                                .shadow(color: world.primaryColor.opacity(0.5), radius: 6)
                        } else {
                            Text("\(collectiblesCollected) / \(totalCollectibles)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // === SCORE SECTION — THE HERO ===
                if showScoreSection {
                    VStack(spacing: 8) {
                        // Giant counting score number
                        Text("\(displayedScore)")
                            .font(.system(size: 56, weight: .black, design: .monospaced))
                            .foregroundStyle(world.primaryColor)
                            .shadow(color: world.primaryColor.opacity(0.7), radius: 20)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.05), value: displayedScore)
                            .accessibilityLabel("Score \(totalScore)")

                        // Rank badge — slams in after count finishes
                        if showRank {
                            VStack(spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("RANK")
                                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.4))
                                    Text(scoreRank)
                                        .font(.system(size: 36, weight: .black, design: .default))
                                        .foregroundStyle(rankColor)
                                        .shadow(color: rankColor.opacity(0.6), radius: 12)
                                }
                                .scaleEffect(rankScale)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Rank \(scoreRank)")

                                // S rank teaser — THE key message
                                if !allCollected && totalCollectibles > 0 {
                                    Text("COLLECT ALL FOR RANK S")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.yellow.opacity(0.7))
                                        .padding(.top, 2)
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }

                        // NEW BEST badge
                        if showNewBest && isNewBest {
                            Text("★ NEW BEST ★")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundStyle(.yellow)
                                .shadow(color: .yellow.opacity(0.7), radius: 10)
                                .scaleEffect(newBestScale)
                                .transition(.scale)
                        }

                        // Score breakdown — compact, below the hero number
                        if showBreakdown {
                            VStack(spacing: 3) {
                                Divider()
                                    .background(world.primaryColor.opacity(0.3))
                                    .padding(.horizontal, 60)
                                    .padding(.bottom, 4)

                                breakdownRow("LEVEL", value: 200)
                                if collectiblesCollected > 0 {
                                    breakdownRow("COLLECT ×\(collectiblesCollected)", value: collectiblePointsTotal)
                                }
                                if speedBonus > 0 {
                                    breakdownRow("SPEED", value: speedBonus)
                                }

                                // Trail + close call points (remainder)
                                let bonusPoints = totalScore - 200 - collectiblePointsTotal - speedBonus
                                if bonusPoints > 0 {
                                    breakdownRow("BONUS", value: bonusPoints)
                                }

                                if bestScore > 0 && !isNewBest {
                                    Text("BEST: \(bestScore)")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.35))
                                        .padding(.top, 4)
                                }

                                // Star hint — show what they need for the next star
                                if stars < 3 {
                                    let nextThreshold = stars < 2 ? 350 : 550
                                    Text("\(nextThreshold) for \(String(repeating: "★", count: stars + 1))")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(world.primaryColor.opacity(0.5))
                                        .padding(.top, 2)
                                }
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
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
                    .accessibilityLabel("Back to level select")

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
                    .accessibilityLabel("Replay this level")

                    Button(action: onNextLevel) {
                        Text(isLastLevelOverall ? "DONE" : (isLastLevel ? "NEXT WORLD →" : "NEXT →"))
                            .font(.system(size: 16, weight: .heavy, design: .default))
                            .foregroundStyle(world.primaryColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .border(world.primaryColor, width: 1)
                            .cornerRadius(6)
                    }
                    .accessibilityLabel(isLastLevelOverall ? "Done, return to menu" : (isLastLevel ? "Continue to next world" : "Next level"))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .opacity(showButtons ? 1 : 0)
                .allowsHitTesting(showButtons)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onDisappear {
            countTimer?.invalidate()
            countTimer = nil
        }
    }

    /// Total collectible points accounting for combo multiplier
    private var collectiblePointsTotal: Int {
        guard collectiblesCollected > 0 else { return 0 }
        var total = 0
        for i in 1...collectiblesCollected {
            let multiplier = min(3.0, 1.0 + Double(max(0, i - 1)) * 0.5)
            total += Int(50.0 * multiplier)
        }
        // All-collected bonus
        if allCollected && collectiblesCollected > 1 {
            total += 100
        }
        return total
    }

    private func breakdownRow(_ label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
            Text("+\(value)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(world.primaryColor.opacity(0.6))
        }
        .padding(.horizontal, 50)
    }

    // MARK: - Animation Sequence

    private func startAnimationSequence() {
        playRecordScratch()

        // 1. Completion word springs in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.3).delay(0.05)) {
            wordScale = 1.0
            wordOpacity = 1.0
        }

        // 2. Stars appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                showStars = true
            }
        }

        // 3. Collectible diamonds pop in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                showCollectibles = true
            }
        }

        // 4. Score section appears + counting starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.2)) {
                showScoreSection = true
            }
            startScoreCountUp()
        }
    }

    private func startScoreCountUp() {
        let target = totalScore
        guard target > 0 else {
            displayedScore = 0
            scoreCountFinished = true
            finishScoreReveal()
            return
        }

        // Count up over ~0.9 seconds, stepping every 25ms
        let totalDuration: TimeInterval = 0.9
        let stepInterval: TimeInterval = 0.025
        let totalSteps = Int(totalDuration / stepInterval)
        var step = 0

        countTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { timer in
            step += 1
            let progress = min(1.0, Double(step) / Double(totalSteps))
            // Ease-out cubic — fast start, satisfying deceleration at end
            let eased = 1.0 - pow(1.0 - progress, 3.0)
            let newValue = Int(Double(target) * eased)

            if newValue != displayedScore {
                displayedScore = newValue
                audioManager?.playScoreTick()
            }

            if step >= totalSteps {
                timer.invalidate()
                countTimer = nil
                displayedScore = target
                scoreCountFinished = true
                finishScoreReveal()
            }
        }
    }

    private func finishScoreReveal() {
        // Rank badge slams in
        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
            showRank = true
            rankScale = 1.0
        }

        // NEW BEST
        if isNewBest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) {
                    showNewBest = true
                    newBestScale = 1.0
                }
            }
        }

        // Breakdown fades in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeIn(duration: 0.3)) {
                showBreakdown = true
            }
        }

        // Buttons
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeIn(duration: 0.3)) {
                showButtons = true
            }
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
