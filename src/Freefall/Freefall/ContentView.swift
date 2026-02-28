import SwiftUI

struct ContentView: View {
    @State private var gameState = GameState()
    @State private var levelDefinition: LevelDefinition?
    @State private var worldDefinition: WorldDefinition? = WorldLibrary.world(for: 1)
    @State private var loadError: String?
    @State private var hasLoadedLevel = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let levelDefinition, let worldDefinition {
                SpriteKitView(level: levelDefinition, world: worldDefinition)
                    .ignoresSafeArea()
            } else if let loadError {
                Text(loadError)
                    .foregroundStyle(Color.hex("#00D4FF"))
                    .padding()
            } else {
                ProgressView("Loading Freefall…")
                    .tint(Color.hex("#00D4FF"))
            }
        }
        .task {
            loadInitialLevelIfNeeded()
        }
        .environment(gameState)
    }

    @MainActor
    private func loadInitialLevelIfNeeded() {
        guard !hasLoadedLevel else { return }
        hasLoadedLevel = true

        do {
            let level = try LevelLoader().loadLevel(world: 1, level: 1)
            levelDefinition = level
        } catch {
            loadError = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
