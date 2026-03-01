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
                    Spacer()
                }
            }

            // Voice drop overlay (shown briefly at start)
            if showVoiceDrop {
                Text("INTERMISSION")
                    .font(.system(size: 48, weight: .black, design: .default))
                    .foregroundColor(.white)
                    .shadow(color: .red, radius: 20)
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
        // Play voice drop first
        audioManager.playSFX("intermission-voice")
        // Then start music after 1.2s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            audioManager.playIntermissionMusic()
        }
    }
}
