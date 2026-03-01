import SwiftUI

struct ContentView: View {
    @State private var gameState = GameState()
    @State private var navigationPath = NavigationPath()
    @State private var isSettingsPresented = false
    @State private var audioManager: AudioManager?

    private let worlds = WorldLibrary.allWorlds

    var body: some View {
        NavigationStack(path: $navigationPath) {
            MainMenuView(
                audioManager: audioManager ?? AudioManager(gameState: gameState),
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
                            navigationPath.append(AppDestination.levelSelect(worldId: world.id))
                        }
                    )
                case .levelSelect(let worldId):
                    if let world = WorldLibrary.world(for: worldId) {
                        LevelSelectView(
                            world: world,
                            onBack: popDestination,
                            onLevelSelected: { levelId in
                                navigationPath.append(AppDestination.game(worldId: worldId, levelId: levelId))
                            }
                        )
                    }
                case .game(let worldId, let levelId):
                    GameDestinationView(
                        worldId: worldId,
                        levelId: levelId,
                        gameState: gameState,
                        audioManager: audioManager ?? AudioManager(gameState: gameState),
                        navigationPath: $navigationPath,
                        onQuit: popDestination
                    )
                case .settings:
                    SettingsView()
                }
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.thinMaterial)
        }
        .environment(gameState)
        .onAppear {
            if audioManager == nil {
                audioManager = AudioManager(gameState: gameState)
            }
        }
    }

    private func handleMusicToggle() {
        if gameState.musicEnabled {
            audioManager?.playMenuMusic()
        } else {
            audioManager?.stopMusic()
        }
    }

    private func popDestination() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }
}

// Separate view to handle try/catch outside ViewBuilder
private struct GameDestinationView: View {
    let worldId: Int
    let levelId: Int
    let gameState: GameState
    let audioManager: AudioManager
    @Binding var navigationPath: NavigationPath
    let onQuit: () -> Void

    @State private var level: LevelDefinition?
    @State private var loadError: Error?

    var body: some View {
        Group {
            if let level = level, let world = WorldLibrary.world(for: worldId) {
                ZStack {
                    GameView(
                        world: world,
                        level: level,
                        onQuit: onQuit
                    )

                    if gameState.isIntermissionActive {
                        IntermissionView(
                            audioManager: audioManager,
                            onComplete: { finalScore, time in
                                gameState.addScore(finalScore)
                                gameState.lastIntermissionScore = finalScore
                                gameState.lastIntermissionSurvivalTime = time
                                gameState.isIntermissionActive = false
                                navigationPath.removeLast()
                                navigationPath.append(AppDestination.game(worldId: worldId, levelId: levelId + 1))
                            }
                        )
                        .ignoresSafeArea()
                    }
                }
            } else if let error = loadError {
                GameErrorView(error: error, onDismiss: onQuit)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .onAppear {
            do {
                level = try LevelLoader().loadLevel(world: worldId, level: levelId)
            } catch {
                loadError = error
            }
        }
    }
}

enum AppDestination: Hashable, Codable {
    case worldSelect
    case levelSelect(worldId: Int)
    case game(worldId: Int, levelId: Int)
    case settings

    enum CodingKeys: String, CodingKey {
        case type, worldId, levelId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "worldSelect": self = .worldSelect
        case "settings": self = .settings
        case "levelSelect":
            let worldId = try container.decode(Int.self, forKey: .worldId)
            self = .levelSelect(worldId: worldId)
        case "game":
            let worldId = try container.decode(Int.self, forKey: .worldId)
            let levelId = try container.decode(Int.self, forKey: .levelId)
            self = .game(worldId: worldId, levelId: levelId)
        default: self = .worldSelect
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .worldSelect: try container.encode("worldSelect", forKey: .type)
        case .settings: try container.encode("settings", forKey: .type)
        case .levelSelect(let worldId):
            try container.encode("levelSelect", forKey: .type)
            try container.encode(worldId, forKey: .worldId)
        case .game(let worldId, let levelId):
            try container.encode("game", forKey: .type)
            try container.encode(worldId, forKey: .worldId)
            try container.encode(levelId, forKey: .levelId)
        }
    }
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

#Preview {
    ContentView()
}
