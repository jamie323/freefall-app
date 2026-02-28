import SwiftUI

struct ContentView: View {
    @State private var gameState = GameState()
    @State private var isShowingMainMenu = true
    @State private var isSettingsPresented = false

    var body: some View {
        ZStack {
            if isShowingMainMenu {
                MainMenuView(
                    onPlay: { isShowingMainMenu = false },
                    onOpenSettings: { isSettingsPresented = true },
                    onToggleMusic: handleMusicToggle
                )
            } else {
                WorldSelectPlaceholderView(onBack: { isShowingMainMenu = true })
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsPlaceholderView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.thinMaterial)
        }
        .environment(gameState)
    }

    private func handleMusicToggle() {
        // Audio routing will be added with the audio engine step.
    }
}

private struct WorldSelectPlaceholderView: View {
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button("← Back", action: onBack)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.hex("#00D4FF"))
            Spacer()
            Text("World Select coming soon")
                .font(.title)
                .foregroundStyle(.white)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

private struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("SETTINGS")
                .font(.headline)
                .foregroundStyle(Color.hex("#00D4FF"))
            Text("Settings UI arriving in Step 17.")
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Color.black)
    }
}

#Preview {
    ContentView()
}
