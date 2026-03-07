import SwiftUI

struct ContentView: View {
    @State private var gameState: GameState
    @State private var navigationPath = NavigationPath()
    @State private var isSettingsPresented = false
    @State private var audioManager: AudioManager
    @State private var cosmeticsManager: CosmeticsManager
    @State private var isCosmeticsPresented = false

    private let worlds = WorldLibrary.allWorlds

    init() {
        let gameState = GameState()
        _gameState = State(initialValue: gameState)
        _audioManager = State(initialValue: AudioManager(gameState: gameState))
        _cosmeticsManager = State(initialValue: CosmeticsManager(gameState: gameState))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            MainMenuView(
                audioManager: audioManager,
                onPlay: { navigationPath.append(AppDestination.worldSelect) },
                onOpenSettings: { isSettingsPresented = true },
                onOpenCosmetics: { isCosmeticsPresented = true },
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
                        audioManager: audioManager,
                        cosmeticsManager: cosmeticsManager,
                        onQuit: {
                            // Return to level select, play menu music
                            audioManager.playMenuMusic()
                            popDestination()
                        },
                        onAdvance: { action in
                            navigationPath.removeLast()
                            switch action {
                            case .nextLevel(let nextLevelId):
                                navigationPath.append(AppDestination.game(worldId: worldId, levelId: nextLevelId))
                            case .nextWorld(let nextWorldId):
                                audioManager.playMenuMusic()
                                navigationPath.append(AppDestination.levelSelect(worldId: nextWorldId))
                            case .quitToLevels:
                                audioManager.playMenuMusic()
                            }
                        }
                    )
                    .id("game-\(worldId)-\(levelId)")
                case .settings:
                    SettingsView()
                }
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Material.thin)
        }
        .sheet(isPresented: $isCosmeticsPresented) {
            CosmeticsView(cosmeticsManager: cosmeticsManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.black)
        }
        .environment(gameState)
        .onChange(of: gameState.musicEnabled) { _, _ in
            handleMusicToggle()
        }
    }

    private func handleMusicToggle() {
        guard gameState.musicEnabled else {
            audioManager.stopMusic()
            return
        }

        if gameState.isIntermissionActive {
            audioManager.playIntermissionMusic()
        } else if let worldId = gameState.currentWorldId, let levelId = gameState.currentLevelId {
            audioManager.playMusic(world: worldId, level: levelId)
        } else {
            audioManager.playMenuMusic()
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
    let cosmeticsManager: CosmeticsManager
    let onQuit: () -> Void
    let onAdvance: (GameAdvanceAction) -> Void

    @State private var level: LevelDefinition?
    @State private var loadError: Error?

    var body: some View {
        Group {
            if let level = level, let world = WorldLibrary.world(for: worldId) {
                ZStack {
                    GameView(
                        world: world,
                        level: level,
                        audioManager: audioManager,
                        cosmeticsManager: cosmeticsManager,
                        onQuit: onQuit,
                        onAdvance: onAdvance
                    )

                    if gameState.isIntermissionActive {
                        IntermissionView(
                            audioManager: audioManager,
                            onComplete: { finalScore, time in
                                gameState.addScore(finalScore)
                                gameState.lastIntermissionScore = finalScore
                                gameState.lastIntermissionSurvivalTime = time
                                gameState.commitCurrentAttemptScore()
                                gameState.isIntermissionActive = false
                                onAdvance(nextAdvanceAction(forWorld: worldId, level: levelId))
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
            // Fade out menu/previous music completely, THEN start level music
            audioManager.fadeOutMusic(duration: 1.0) { [audioManager] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    audioManager.playMusic(world: worldId, level: levelId)
                }
            }
        }
    }

    private func nextAdvanceAction(forWorld worldId: Int, level: Int) -> GameAdvanceAction {
        if level < 10 {
            return .nextLevel(level + 1)
        }
        if worldId < WorldLibrary.allWorlds.count {
            return .nextWorld(worldId + 1)
        }
        return .quitToLevels
    }
}

enum GameAdvanceAction {
    case nextLevel(Int)
    case nextWorld(Int)
    case quitToLevels
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
