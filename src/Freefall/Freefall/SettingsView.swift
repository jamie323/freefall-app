import SwiftUI

struct SettingsView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirmation = false

    var body: some View {
        @Bindable var gs = gameState
        return ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("SETTINGS")
                        .font(.system(size: 22, weight: .black, design: .default))
                        .foregroundStyle(Color.hex("#00D4FF"))

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.hex("#00D4FF"))
                    }
                    .accessibilityLabel("Close settings")
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Divider()
                    .background(Color.hex("#00D4FF").opacity(0.2))
                    .padding(.horizontal, 24)

                // Settings Rows
                VStack(spacing: 16) {
                    SettingsRow(
                        label: "Music",
                        isOn: $gs.musicEnabled,
                        tintColor: Color.hex("#00D4FF")
                    )

                    SettingsRow(
                        label: "Sound Effects",
                        isOn: $gs.sfxEnabled,
                        tintColor: Color.hex("#00D4FF")
                    )

                    SettingsRow(
                        label: "Haptics",
                        isOn: $gs.hapticsEnabled,
                        tintColor: Color.hex("#00D4FF")
                    )
                }
                .padding(.horizontal, 24)

                Divider()
                    .background(Color.hex("#00D4FF").opacity(0.2))
                    .padding(.horizontal, 24)

                // Scoring Guide
                ScoringGuideView()
                    .padding(.horizontal, 24)

                Divider()
                    .background(Color.hex("#00D4FF").opacity(0.2))
                    .padding(.horizontal, 24)

                // Statistics
                StatsView()
                    .padding(.horizontal, 24)

                Spacer()

                // Reset Progress
                Button(action: { showResetConfirmation = true }) {
                    Text("Reset All Progress")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .padding(.horizontal, 24)

                // Version footer
                Text("FREEFALL v1.0")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity)

                Spacer().frame(height: 24)
            }
        }
        .alert("Reset Progress", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset Everything", role: .destructive) {
                gameState.resetProgress()
                dismiss()
            }
        } message: {
            Text("This will erase all scores, stars, completed levels, and stats. This cannot be undone.")
        }
    }
}

private struct SettingsRow: View {
    let label: String
    @Binding var isOn: Bool
    let tintColor: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white)

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(tintColor)
        }
    }
}

private struct ScoringGuideView: View {
    @State private var isExpanded = false

    private let cyan = Color.hex("#00D4FF")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("HOW SCORING WORKS")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(cyan.opacity(0.8))

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(cyan.opacity(0.5))
                }
                .padding(.vertical, 12)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Points breakdown
                    VStack(alignment: .leading, spacing: 6) {
                        Text("POINTS")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundStyle(cyan.opacity(0.6))

                        scoreRow("Complete level", "+200")
                        scoreRow("Speed bonus", "up to +300")
                        scoreRow("Collectible (1st)", "+50")
                        scoreRow("Collectible (2nd)", "+75  ×1.5")
                        scoreRow("Collectible (3rd)", "+100  ×2")
                        scoreRow("All collected bonus", "+100")
                        scoreRow("Close call", "+25 each")
                        scoreRow("Trail distance", "+1 per distance")
                    }

                    Divider()
                        .background(cyan.opacity(0.15))

                    // Star thresholds
                    VStack(alignment: .leading, spacing: 6) {
                        Text("STARS")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundStyle(cyan.opacity(0.6))

                        starRow(1, "Complete the level")
                        starRow(2, "Score 350+")
                        starRow(3, "Score 550+")
                    }

                    Divider()
                        .background(cyan.opacity(0.15))

                    Text("Replay levels to beat your best score and earn all 3 stars.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 2)
                }
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func scoreRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func starRow(_ count: Int, _ description: String) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(1...3, id: \.self) { i in
                    Image(systemName: i <= count ? "star.fill" : "star")
                        .font(.system(size: 10))
                        .foregroundStyle(i <= count ? .yellow : .white.opacity(0.15))
                }
            }
            Text(description)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

private struct StatsView: View {
    @Environment(GameState.self) private var gameState
    @State private var isExpanded = false

    private let cyan = Color.hex("#00D4FF")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("YOUR STATS")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(cyan.opacity(0.8))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(cyan.opacity(0.5))
                }
                .padding(.vertical, 12)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    statRow("Levels completed", "\(gameState.statsTotalLevelsCompleted)")
                    statRow("Total deaths", "\(gameState.statsTotalDeaths)")
                    statRow("Total flips", "\(gameState.statsTotalFlips)")
                    statRow("Diamonds collected", "\(gameState.statsTotalCollectibles)")
                    statRow("Play time", formatTime(gameState.statsTotalPlayTime))
                    statRow("Best streak", "\(gameState.statsLongestStreak) levels")
                    statRow("Current streak", "\(gameState.statsCurrentStreak) levels")
                    statRow("Total stars", "\(gameState.totalStars) / 240")
                }
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

#Preview {
    SettingsView()
        .environment(GameState())
}
