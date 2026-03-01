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
        static let worldScores = "freefall.worldScores"
        static let totalScore = "freefall.totalScore"
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

    // Runtime (non-persisted)
    var currentLevelScore: Int = 0
    var isIntermissionActive: Bool = false
    var lastIntermissionScore: Int = 0
    var lastIntermissionSurvivalTime: TimeInterval = 0

    // Persisted totals
    var worldScores: [Int: Int] {
        didSet {
            guard oldValue != worldScores else { return }
            persistWorldScores()
        }
    }

    var totalScore: Int {
        didSet {
            guard oldValue != totalScore else { return }
            defaults.set(totalScore, forKey: DefaultsKeys.totalScore)
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
        self.worldScores = GameState.loadWorldScores(from: defaults)
        self.totalScore = defaults.object(forKey: DefaultsKeys.totalScore) as? Int ?? 0
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
        currentLevelScore = 0
        worldScores = [:]
        totalScore = 0
        defaults.removeObject(forKey: DefaultsKeys.worldScores)
        defaults.removeObject(forKey: DefaultsKeys.totalScore)
    }

    func addScore(_ points: Int) {
        currentLevelScore += points
        if let world = currentWorldId {
            worldScores[world, default: 0] += points
        }
        totalScore += points
    }

    func shouldTriggerIntermission(world: Int, level: Int) -> Bool {
        level == 5 || level == 10
    }

    func resetCurrentLevelScore() {
        currentLevelScore = 0
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

    private func persistWorldScores() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(worldScores) {
            defaults.set(data, forKey: DefaultsKeys.worldScores)
        }
    }

    private static func loadCompletedLevels(from defaults: UserDefaults) -> Set<String> {
        guard let data = defaults.data(forKey: DefaultsKeys.completedLevels),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(decoded)
    }

    private static func loadWorldScores(from defaults: UserDefaults) -> [Int: Int] {
        guard let data = defaults.data(forKey: DefaultsKeys.worldScores),
              let decoded = try? JSONDecoder().decode([Int: Int].self, from: data) else {
            return [:]
        }
        return decoded
    }
}
