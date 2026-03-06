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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let scene = scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
            }

            // Score HUD
            if !showResult {
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

            // Voice drop overlay (shown briefly at start)
            if showVoiceDrop {
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
            playIntermissionAudio()
            // Hide voice drop after 1.5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showVoiceDrop = false
                    instructionOpacity = 0
                }
            }
        }
    }

    private func setupScene() {
        let s = IntermissionScene(size: UIScreen.main.bounds.size)
        s.scaleMode = .resizeFill
        s.gameState = gameState
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
        // Then start music after 1.2s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            audioManager.playIntermissionMusic()
        }
    }
}
