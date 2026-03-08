import SwiftUI

struct GameView: View {
    @Environment(GameState.self) private var gameState

    let world: WorldDefinition
    let level: LevelDefinition
    var audioManager: AudioManager?
    var cosmeticsManager: CosmeticsManager?
    let onQuit: () -> Void
    let onHome: () -> Void
    let onAdvance: (GameAdvanceAction) -> Void

    @State private var proxy = SceneProxy()
    @State private var showLevelComplete = false
    @State private var showPauseOverlay = false
    @State private var completionWord = "CLEAN"
    @State private var speedBonus = 0
    @State private var totalScore = 0
    @State private var isNewBest = false
    var skipTransitionFade: Bool = false

    @State private var fadeIn = true
    @State private var fadeOut = false
    @State private var showOnboarding = false
    @State private var showWorldComplete = false

    private var isLastLevelInWorld: Bool { level.levelId == 10 }
    private var isLastLevelOverall: Bool { world.id == WorldLibrary.allWorlds.count && level.levelId == 10 }
    private var completionAdvanceAction: GameAdvanceAction {
        if level.levelId < 10 {
            return .nextLevel(level.levelId + 1)
        }
        if world.id < WorldLibrary.allWorlds.count {
            return .nextWorld(world.id + 1)
        }
        return .quitToLevels
    }

    private func wireLevelCompleteCallback() {
        if let scene = proxy.coordinator?.scene {
            scene.levelCompleted = { [self] in
                self.completionWord = scene.lastCompletionWord
                self.speedBonus = scene.lastSpeedBonus
                self.totalScore = scene.lastTotalScore
                self.isNewBest = scene.lastIsNewBest
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
            SpriteKitView(level: level, world: world, proxy: proxy, audioManager: audioManager, cosmeticsManager: cosmeticsManager)
                .ignoresSafeArea()

            // Full-screen tap target — SpriteKit gesture handler
            Color.white.opacity(0.001)
                .ignoresSafeArea()
                .allowsHitTesting(!showLevelComplete && !showPauseOverlay)
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
            Button(action: handlePause) {
                Image(systemName: "pause.circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 4)
            .padding(.top, 8)
            .accessibilityLabel("Pause")
            .accessibilityHint("Double tap to pause the game")

            // Pause overlay
            if showPauseOverlay {
                PauseOverlayView(
                    world: world,
                    onResume: handleResume,
                    onRestart: handleRestart,
                    onQuit: {
                        showPauseOverlay = false
                        handleQuitWithFade()
                    },
                    onHome: {
                        showPauseOverlay = false
                        onHome()
                    }
                )
                .transition(.opacity)
                .zIndex(99)
            }

            // World complete celebration
            if showWorldComplete {
                WorldCompleteView(
                    world: world,
                    nextWorld: isLastLevelOverall ? nil : WorldLibrary.world(for: world.id + 1),
                    totalStars: (1...10).reduce(0) { $0 + gameState.starsForLevel(world: world.id, level: $1) },
                    worldBestScore: gameState.bestScoreForWorld(world: world.id),
                    onContinue: {
                        showWorldComplete = false
                        handleAdvanceWithFade(completionAdvanceAction)
                    }
                )
                .transition(.opacity)
                .zIndex(120)
            }

            // Onboarding overlay — first time only
            if showOnboarding {
                OnboardingOverlay(world: world) {
                    UserDefaults.standard.set(true, forKey: "freefall.hasSeenOnboarding")
                    withAnimation(.easeOut(duration: 0.3)) {
                        showOnboarding = false
                    }
                }
                .transition(.opacity)
                .zIndex(150)
            }

            // Fade-in overlay — white flash "loading" feel
            if fadeIn {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(200)
            }

            // Fade-out overlay — smooth exit
            if fadeOut {
                Color.black
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                    .transition(.opacity)
                    .zIndex(201)
            }

            // Level complete overlay
            if showLevelComplete {
                LevelCompleteView(
                    world: world,
                    level: level,
                    completionWord: completionWord,
                    collectiblesCollected: proxy.coordinator?.scene.collectiblesCollectedThisAttempt ?? 0,
                    totalCollectibles: level.collectibles?.count ?? 0,
                    speedBonus: speedBonus,
                    totalScore: totalScore,
                    isNewBest: isNewBest,
                    bestScore: gameState.bestScoreForLevel(world: world.id, level: level.levelId),
                    stars: gameState.starsForLevel(world: world.id, level: level.levelId),
                    audioManager: audioManager,
                    onNextLevel: {
                        showLevelComplete = false
                        if proxy.coordinator?.scene.shouldOfferIntermissionAfterCompletion == true {
                            gameState.isIntermissionActive = true
                        } else if isLastLevelInWorld {
                            // Show world complete celebration
                            withAnimation(.easeIn(duration: 0.3)) {
                                showWorldComplete = true
                            }
                        } else {
                            onAdvance(completionAdvanceAction)
                        }
                    },
                    onReplay: {
                        showLevelComplete = false
                        handleRestart()
                    },
                    onLevels: {
                        showLevelComplete = false
                        handleQuitWithFade()
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

            if skipTransitionFade {
                // Same-world level advance — no white flash, start immediately
                fadeIn = false
            } else {
                // Hold white overlay while music fades out, then reveal game
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    withAnimation(.easeOut(duration: 0.8)) {
                        fadeIn = false
                    }
                    // Show onboarding after fade-in (first play only)
                    if !UserDefaults.standard.bool(forKey: "freefall.hasSeenOnboarding") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                            withAnimation(.easeIn(duration: 0.3)) {
                                showOnboarding = true
                            }
                        }
                    }
                }
            }
        }
    }

    private func handlePause() {
        guard let scene = proxy.coordinator?.scene,
              scene.sceneState == .playing else { return }
        scene.sceneState = .paused
        scene.view?.isPaused = true
        withAnimation(.easeIn(duration: 0.15)) {
            showPauseOverlay = true
        }
    }

    private func handleResume() {
        guard let scene = proxy.coordinator?.scene else { return }
        scene.view?.isPaused = false
        scene.sceneState = .playing
        withAnimation(.easeOut(duration: 0.15)) {
            showPauseOverlay = false
        }
    }

    private func handleRestart() {
        guard let scene = proxy.coordinator?.scene else { return }
        scene.view?.isPaused = false
        showPauseOverlay = false
        scene.resetScene()
    }

    /// Fade to black + fade music, then call onQuit
    private func handleQuitWithFade() {
        handleAdvanceWithFade(.quitToLevels)
    }

    private func handleAdvanceWithFade(_ action: GameAdvanceAction) {
        // Only fade music when leaving the world (quit or next world)
        switch action {
        case .quitToLevels, .nextWorld:
            audioManager?.fadeOutMusic(duration: 0.5)
        case .nextLevel:
            break // keep music playing for same-world transitions
        }
        withAnimation(.easeIn(duration: 0.4)) {
            fadeOut = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            switch action {
            case .quitToLevels:
                onQuit()
            case .nextLevel, .nextWorld:
                onAdvance(action)
            }
        }
    }
}

private struct PauseOverlayView: View {
    let world: WorldDefinition
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("PAUSED")
                    .font(.system(size: 48, weight: .black, design: .default))
                    .foregroundStyle(world.primaryColor)

                VStack(spacing: 14) {
                    Button(action: onResume) {
                        Text("RESUME")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(world.primaryColor)
                            .frame(width: 200)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(world.primaryColor, lineWidth: 2)
                            )
                    }
                    .accessibilityLabel("Resume game")

                    Button(action: onRestart) {
                        Text("RESTART")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 200)
                            .padding(.vertical, 12)
                    }
                    .accessibilityLabel("Restart level")

                    Button(action: onQuit) {
                        Text("LEVELS")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 200)
                            .padding(.vertical, 12)
                    }
                    .accessibilityLabel("Back to level select")

                    Button(action: onHome) {
                        Text("HOME")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 200)
                            .padding(.vertical, 12)
                    }
                    .accessibilityLabel("Back to main menu")
                }
            }
        }
    }
}
