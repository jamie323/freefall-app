import SwiftUI

struct MainMenuView: View {
    @Environment(GameState.self) private var gameState
    var audioManager: AudioManager

    var onPlay: () -> Void
    var onOpenSettings: () -> Void
    var onToggleMusic: () -> Void

    private let cyan = Color.hex("#00D4FF")

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AmbientSphereView()

            VStack(spacing: 0) {
                Spacer()

                Text("FREEFALL")
                    .onAppear {
                        audioManager.playMenuMusic()
                    }
                    .font(.system(size: 64, weight: .black, design: .default).width(.condensed))
                    .foregroundStyle(cyan)
                    .shadow(color: cyan.opacity(0.8), radius: 20)

                Spacer().frame(height: 40)

                Button(action: handlePlayTapped) {
                    Text("PLAY")
                        .font(.system(size: 32, weight: .heavy, design: .default).width(.condensed))
                        .foregroundStyle(cyan)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(cyan, lineWidth: 2)
                        )
                }

                Spacer()

                HStack {
                    Button(action: handleSettingsTapped) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(cyan.opacity(0.7))
                    }

                    Spacer()

                    Button(action: handleMusicTapped) {
                        Image(systemName: gameState.musicEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(cyan.opacity(0.7))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .padding(.top, 40)
        }
    }

    private func handlePlayTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onPlay()
    }

    private func handleSettingsTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onOpenSettings()
    }

    private func handleMusicTapped() {
        gameState.musicEnabled.toggle()
        onToggleMusic()
    }
}

private struct AmbientSphereView: View {
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.hex("#00D4FF"), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 200
                )
            )
            .frame(width: 320, height: 320)
            .blur(radius: 80)
            .opacity(0.8)
            .offset(x: animate ? 60 : -60, y: animate ? -50 : 50)
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animate)
            .onAppear {
                animate = true
            }
    }
}

#Preview {
    MainMenuView(
        audioManager: AudioManager(gameState: GameState()),
        onPlay: {},
        onOpenSettings: {},
        onToggleMusic: {}
    )
    .environment(GameState())
}
