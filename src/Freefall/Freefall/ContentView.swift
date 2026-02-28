import SwiftUI

struct ContentView: View {
    @State private var gameState = GameState()
    @State private var navigationPath = NavigationPath()
    @State private var isSettingsPresented = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            MainMenuView(
                onPlay: { navigationPath.append(AppDestination.worldSelect) },
                onOpenSettings: { isSettingsPresented = true },
                onToggleMusic: handleMusicToggle
            )
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .worldSelect:
                    WorldSelectPlaceholderView()
                case .levelSelect(let worldId):
                    LevelSelectPlaceholderView(worldId: worldId)
                case .game(let worldId, let levelId):
                    GamePlaceholderView(worldId: worldId, levelId: levelId)
                case .settings:
                    SettingsPlaceholderView()
                }
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

enum AppDestination: Hashable, Codable {
    case worldSelect
    case levelSelect(worldId: Int)
    case game(worldId: Int, levelId: Int)
    case settings
}

private struct WorldSelectPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("World Select coming soon")
                .font(.title)
                .foregroundStyle(.white)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.black.ignoresSafeArea())
    }
}

private struct LevelSelectPlaceholderView: View {
    let worldId: Int

    var body: some View {
        VStack(spacing: 16) {
            Text("Level Select for World \(worldId) coming soon")
                .font(.title2)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.black.ignoresSafeArea())
    }
}

private struct GamePlaceholderView: View {
    let worldId: Int
    let levelId: Int

    var body: some View {
        VStack(spacing: 16) {
            Text("Game View")
                .font(.title)
                .foregroundStyle(.white)
            Text("World \(worldId) – Level \(levelId)")
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
