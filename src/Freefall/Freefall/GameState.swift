import Foundation
import Observation

@Observable
final class GameState {
    enum GameplayState: String, CaseIterable {
        case ready
        case playing
        case dead
        case complete
        case paused
    }

    private enum DefaultsKeys {
        static let completedLevels = "freefall.completedLevels"
        static let musicEnabled = "freefall.musicEnabled"
        static let sfxEnabled = "freefall.sfxEnabled"
        static let hapticsEnabled = "freefall.hapticsEnabled"
    }

    private let defaults: UserDefaults

    var completedLevels: Set<String> {
        didSet {
            guard oldValue != completedLevels else { return }
            persistCompletedLevels()
        }
    }

    var musicEnabled: Bool {
        didSet {
            guard oldValue != musicEnabled else { return }
            defaults.set(musicEnabled, forKey: DefaultsKeys.musicEnabled)
        }
    }

    var sfxEnabled: Bool {
        didSet {
            guard oldValue != sfxEnabled else { return }
            defaults.set(sfxEnabled, forKey: DefaultsKeys.sfxEnabled)
        }
    }

    var hapticsEnabled: Bool {
        didSet {
            guard oldValue != hapticsEnabled else { return }
            defaults.set(hapticsEnabled, forKey: DefaultsKeys.hapticsEnabled)
        }
    }

    var currentWorldId: Int?
    var currentLevelId: Int?
    var gameplayState: GameplayState

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.completedLevels = GameState.loadCompletedLevels(from: defaults)
        self.musicEnabled = defaults.object(forKey: DefaultsKeys.musicEnabled) as? Bool ?? true
        self.sfxEnabled = defaults.object(forKey: DefaultsKeys.sfxEnabled) as? Bool ?? true
        self.hapticsEnabled = defaults.object(forKey: DefaultsKeys.hapticsEnabled) as? Bool ?? true
        self.currentWorldId = nil
        self.currentLevelId = nil
        self.gameplayState = .ready
    }

    func isLevelUnlocked(world: Int, level: Int) -> Bool {
        guard world > 0, level > 0 else { return false }
        guard isWorldUnlocked(world: world) else { return false }
        if level == 1 { return true }
        return completedLevels.contains(levelKey(world: world, level: level - 1))
    }

    func isWorldUnlocked(world: Int) -> Bool {
        guard world > 0 else { return false }
        if world == 1 { return true }
        let previousWorld = world - 1
        let previousWorldKeys = (1...10).map { levelKey(world: previousWorld, level: $0) }
        return previousWorldKeys.allSatisfy { completedLevels.contains($0) }
    }

    func completedCountForWorld(world: Int) -> Int {
        guard world > 0 else { return 0 }
        return completedLevels.reduce(into: 0) { count, entry in
            if entry.hasPrefix("W\(world)L") {
                count += 1
            }
        }
    }

    func markLevelCompleted(world: Int, level: Int) {
        let key = levelKey(world: world, level: level)
        completedLevels.insert(key)
    }

    func resetProgress() {
        completedLevels.removeAll()
    }

    private func levelKey(world: Int, level: Int) -> String {
        "W\(world)L\(level)"
    }

    private func persistCompletedLevels() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(Array(completedLevels)) {
            defaults.set(data, forKey: DefaultsKeys.completedLevels)
        }
    }

    private static func loadCompletedLevels(from defaults: UserDefaults) -> Set<String> {
        guard let data = defaults.data(forKey: DefaultsKeys.completedLevels),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(decoded)
    }
}
