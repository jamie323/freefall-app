import SwiftUI

struct GameView: View {
    @Environment(GameState.self) private var gameState

    let world: WorldDefinition
    let level: LevelDefinition
    var audioManager: AudioManager?
    let onQuit: () -> Void
    let onNextLevel: (Int) -> Void

    @State private var proxy = SceneProxy()
    @State private var showLevelComplete = false
    @State private var showPauseOverlay = false
    @State private var completionWord = "CLEAN"
    @State private var speedBonus = 0
    @State private var isNewBest = false
    @State private var fadeIn = true
    @State private var fadeOut = false

    private var isLastLevelInWorld: Bool { level.levelId == 10 }
    private var isLastLevelOverall: Bool { world.id == 4 && level.levelId == 10 }

    private func wireLevelCompleteCallback() {
        if let scene = proxy.coordinator?.scene {
            scene.levelCompleted = { [self] in
                self.completionWord = scene.lastCompletionWord
                self.speedBonus = scene.lastSpeedBonus
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
            SpriteKitView(level: level, world: world, proxy: proxy, audioManager: audioManager)
                .ignoresSafeArea()

            // Full-screen tap target — SpriteKit gesture handler
            Color.white.opacity(0.001)
                .ignoresSafeArea()
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

            // Pause overlay
            if showPauseOverlay {
                PauseOverlayView(
                    world: world,
                    onResume: handleResume,
                    onRestart: handleRestart,
                    onQuit: {
                        showPauseOverlay = false
                        handleQuitWithFade()
                    }
                )
                .transition(.opacity)
                .zIndex(99)
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
                    speedBonus: speedBonus,
                    isNewBest: isNewBest,
                    bestScore: gameState.bestScoreForLevel(world: world.id, level: level.levelId),
                    stars: gameState.starsForLevel(world: world.id, level: level.levelId),
                    onNextLevel: {
                        showLevelComplete = false
                        if isLastLevelOverall {
                            handleQuitWithFade()
                        } else if isLastLevelInWorld {
                            handleQuitWithFade()
                        } else {
                            onNextLevel(level.levelId + 1)
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
            // Brief hold on white overlay, then fade to reveal game
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.easeOut(duration: 0.6)) {
                    fadeIn = false
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
        audioManager?.fadeOutMusic(duration: 0.5)
        withAnimation(.easeIn(duration: 0.4)) {
            fadeOut = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            onQuit()
        }
    }
}

private struct PauseOverlayView: View {
    let world: WorldDefinition
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

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

                    Button(action: onRestart) {
                        Text("RESTART")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 200)
                            .padding(.vertical, 12)
                    }

                    Button(action: onQuit) {
                        Text("QUIT")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 200)
                            .padding(.vertical, 12)
                    }
                }
            }
        }
    }
}
