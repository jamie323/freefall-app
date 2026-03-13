import SwiftUI
import SpriteKit

struct IntermissionView: View {
    @Environment(GameState.self) private var gameState
    let audioManager: AudioManager
    var onComplete: (Int, TimeInterval) -> Void  // score, time

    @State private var scene: IntermissionScene?
    @State private var survivalTime: TimeInterval = 0
    @State private var displayScore: Int = 0
    @State private var showResult = false
    @State private var showVoiceDrop = true
    @State private var instructionOpacity: CGFloat = 1
    @State private var showTutorial = false
    @State private var showCountdown = false
    @State private var countdownNumber: Int = 3
    @State private var gameStarted = false

    private var isFirstIntermission: Bool {
        !UserDefaults.standard.bool(forKey: "hasSeenIntermissionTutorial")
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let scene = scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
            }

            // Score HUD
            if !showResult && !showTutorial && gameStarted {
                VStack {
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(displayScore)")
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text(String(format: "%.1fs", survivalTime))
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 60)
                    }
                    Text("HOLD LEFT OR RIGHT TO STRAFE THROUGH THE DROP")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(instructionOpacity * 0.45))
                        .padding(.top, 100)
                    Spacer()
                }
            }

            // Help button — always visible during gameplay (not during tutorial/result)
            if !showTutorial && !showResult && gameStarted {
                VStack {
                    HStack {
                        Button(action: showHelpTutorial) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.leading, 20)
                        .padding(.top, 60)
                        Spacer()
                    }
                    Spacer()
                }
            }

            // Voice drop overlay (shown briefly at start)
            if showVoiceDrop && !showTutorial {
                VStack(spacing: 10) {
                    Text("DROP IN")
                        .font(.system(size: 54, weight: .black, design: .default))
                        .foregroundColor(.white)
                        .shadow(color: .red, radius: 24)
                    Text("FREEFALL PROTOCOL")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                .transition(.opacity)
            }

            // 3-2-1 countdown overlay
            if showCountdown {
                Text("\(countdownNumber)")
                    .font(.system(size: 100, weight: .black, design: .default))
                    .foregroundColor(.white)
                    .shadow(color: .red, radius: 30)
                    .transition(.scale.combined(with: .opacity))
            }

            // Tutorial overlay (first time + help button)
            if showTutorial {
                ZStack {
                    Color.black.opacity(0.85).ignoresSafeArea()

                    VStack(spacing: 28) {
                        Spacer()

                        Text("THE DROP")
                            .font(.system(size: 42, weight: .black))
                            .foregroundColor(.red)
                            .shadow(color: .red.opacity(0.6), radius: 16)

                        VStack(spacing: 16) {
                            tutorialRow(icon: "arrow.left.and.right", text: "HOLD LEFT OR RIGHT TO DODGE")
                            tutorialRow(icon: "bolt.fill", text: "AVOID THE GATES")
                            tutorialRow(icon: "clock.fill", text: "SURVIVE AS LONG AS YOU CAN")
                            tutorialRow(icon: "star.fill", text: "BONUS POINTS FOR SURVIVAL")
                        }
                        .padding(.horizontal, 40)

                        Spacer()

                        Button(action: dismissTutorial) {
                            Text("TAP TO DROP")
                                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                        .padding(.bottom, 60)
                    }
                }
                .transition(.opacity)
            }

            // Result screen
            if showResult {
                VStack(spacing: 24) {
                    Spacer()
                    Text("SURVIVED")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white.opacity(0.6))
                    Text(String(format: "%.1f SECONDS", survivalTime))
                        .font(.system(size: 42, weight: .black))
                        .foregroundColor(.white)
                    Text("+\(displayScore) PTS")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            setupScene()
            if isFirstIntermission {
                // Show tutorial — scene animates visually but gameplay frozen
                showTutorial = true
                scene?.waitingForStart = true
            } else {
                startIntermissionSequence()
            }
        }
    }

    private func tutorialRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.red)
                .frame(width: 32)
            Text(text)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
    }

    /// Show tutorial from help button (doesn't reset first-time flag)
    private func showHelpTutorial() {
        scene?.waitingForStart = true
        withAnimation(.easeIn(duration: 0.2)) {
            showTutorial = true
        }
    }

    private func dismissTutorial() {
        UserDefaults.standard.set(true, forKey: "hasSeenIntermissionTutorial")
        withAnimation(.easeOut(duration: 0.3)) {
            showTutorial = false
        }
        scene?.waitingForStart = false

        // Only start the full sequence if game hasn't started yet
        if !gameStarted {
            startIntermissionSequence()
        }
    }

    private func startIntermissionSequence() {
        playIntermissionAudio()

        // 3-2-1 countdown before action starts
        showCountdown = true
        countdownNumber = 3
        audioManager.playSFX("countdown-3")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                countdownNumber = 2
            }
            audioManager.playSFX("countdown-2")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                countdownNumber = 1
            }
            audioManager.playSFX("countdown-1")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCountdown = false
                showVoiceDrop = false
                instructionOpacity = 0
                gameStarted = true
            }
            // Unfreeze the scene — gameplay starts NOW
            scene?.waitingForStart = false
        }
    }

    private func setupScene() {
        let s = IntermissionScene(size: UIScreen.main.bounds.size)
        s.scaleMode = .resizeFill
        s.gameState = gameState
        s.waitingForStart = true  // Always start paused until countdown finishes
        s.onDeath = { finalScore, time in
            survivalTime = time
            displayScore = finalScore
            audioManager.stopMusic()
            withAnimation(.easeIn(duration: 0.3)) {
                showResult = true
            }
            // Auto-advance after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onComplete(finalScore, time)
            }
        }
        scene = s
    }

    private func playIntermissionAudio() {
        audioManager.fadeOutMusic(duration: 0.45)
        // Play voice drop first
        audioManager.playSFX("intermission-voice")
        // Then start music after 2.5s (after countdown)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            audioManager.playIntermissionMusic()
        }
    }
}
