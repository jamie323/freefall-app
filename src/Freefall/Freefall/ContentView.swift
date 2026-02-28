import SwiftUI

struct ContentView: View {
    @State private var gameState = GameState()
    @State private var navigationPath = NavigationPath()
    @State private var isSettingsPresented = false

    private let worlds = WorldLibrary.allWorlds

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
                    WorldSelectView(
                        worlds: worlds,
                        onBack: popDestination,
                        onWorldSelected: { world in
                            navigationPath.append(.levelSelect(worldId: world.id))
                        }
                    )
                case .levelSelect(let worldId):
                    if let world = WorldLibrary.world(for: worldId) {
                        LevelSelectView(
                            world: world,
                            onBack: popDestination,
                            onLevelSelected: { levelId in
                                navigationPath.append(.game(worldId: worldId, levelId: levelId))
                            }
                        )
                    }
                case .game(let worldId, let levelId):
                    if let world = WorldLibrary.world(for: worldId) {
                        do {
                            let level = try LevelLoader().loadLevel(world: worldId, level: levelId)
                            GameView(
                                world: world,
                                level: level,
                                onQuit: popDestination
                            )
                        } catch {
                            GameErrorView(error: error, onDismiss: popDestination)
                        }
                    }
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

    private func popDestination() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }
}

enum AppDestination: Hashable, Codable {
    case worldSelect
    case levelSelect(worldId: Int)
    case game(worldId: Int, levelId: Int)
    case settings
}

private struct GameErrorView: View {
    let error: Error
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Error Loading Level")
                .font(.headline)
                .foregroundStyle(.red)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button(action: onDismiss) {
                Text("Go Back")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.hex("#00D4FF"))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .border(Color.hex("#00D4FF"), width: 1)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
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
