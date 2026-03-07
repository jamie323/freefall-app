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
        static let levelBestScores = "freefall.levelBestScores"
        // Statistics
        static let statsTotalDeaths = "freefall.stats.totalDeaths"
        static let statsTotalFlips = "freefall.stats.totalFlips"
        static let statsTotalPlayTime = "freefall.stats.totalPlayTime"
        static let statsTotalLevelsCompleted = "freefall.stats.totalLevelsCompleted"
        static let statsTotalCollectibles = "freefall.stats.totalCollectibles"
        static let statsLongestStreak = "freefall.stats.longestStreak"
        static let statsCurrentStreak = "freefall.stats.currentStreak"
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
    private(set) var currentAttemptScore: Int = 0
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

    var levelBestScores: [String: Int] {
        didSet {
            guard oldValue != levelBestScores else { return }
            persistLevelBestScores()
        }
    }

    var currentWorldId: Int?
    var currentLevelId: Int?
    var gameplayState: GameplayState

    // MARK: - Statistics (persisted)
    var statsTotalDeaths: Int {
        didSet { defaults.set(statsTotalDeaths, forKey: DefaultsKeys.statsTotalDeaths) }
    }
    var statsTotalFlips: Int {
        didSet { defaults.set(statsTotalFlips, forKey: DefaultsKeys.statsTotalFlips) }
    }
    var statsTotalPlayTime: TimeInterval {
        didSet { defaults.set(statsTotalPlayTime, forKey: DefaultsKeys.statsTotalPlayTime) }
    }
    var statsTotalLevelsCompleted: Int {
        didSet { defaults.set(statsTotalLevelsCompleted, forKey: DefaultsKeys.statsTotalLevelsCompleted) }
    }
    var statsTotalCollectibles: Int {
        didSet { defaults.set(statsTotalCollectibles, forKey: DefaultsKeys.statsTotalCollectibles) }
    }
    var statsLongestStreak: Int {
        didSet { defaults.set(statsLongestStreak, forKey: DefaultsKeys.statsLongestStreak) }
    }
    var statsCurrentStreak: Int {
        didSet { defaults.set(statsCurrentStreak, forKey: DefaultsKeys.statsCurrentStreak) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.completedLevels = GameState.loadCompletedLevels(from: defaults)
        self.musicEnabled = defaults.object(forKey: DefaultsKeys.musicEnabled) as? Bool ?? true
        self.sfxEnabled = defaults.object(forKey: DefaultsKeys.sfxEnabled) as? Bool ?? true
        self.hapticsEnabled = defaults.object(forKey: DefaultsKeys.hapticsEnabled) as? Bool ?? true
        self.worldScores = GameState.loadWorldScores(from: defaults)
        self.totalScore = defaults.object(forKey: DefaultsKeys.totalScore) as? Int ?? 0
        self.levelBestScores = GameState.loadLevelBestScores(from: defaults)
        self.currentWorldId = nil
        self.currentLevelId = nil
        self.gameplayState = .ready
        // Stats
        self.statsTotalDeaths = defaults.integer(forKey: DefaultsKeys.statsTotalDeaths)
        self.statsTotalFlips = defaults.integer(forKey: DefaultsKeys.statsTotalFlips)
        self.statsTotalPlayTime = defaults.double(forKey: DefaultsKeys.statsTotalPlayTime)
        self.statsTotalLevelsCompleted = defaults.integer(forKey: DefaultsKeys.statsTotalLevelsCompleted)
        self.statsTotalCollectibles = defaults.integer(forKey: DefaultsKeys.statsTotalCollectibles)
        self.statsLongestStreak = defaults.integer(forKey: DefaultsKeys.statsLongestStreak)
        self.statsCurrentStreak = defaults.integer(forKey: DefaultsKeys.statsCurrentStreak)
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
        levelBestScores = [:]
        defaults.removeObject(forKey: DefaultsKeys.worldScores)
        defaults.removeObject(forKey: DefaultsKeys.totalScore)
        defaults.removeObject(forKey: DefaultsKeys.levelBestScores)
    }

    func addScore(_ points: Int) {
        currentLevelScore += points
        currentAttemptScore += points
    }

    func commitCurrentAttemptScore() {
        guard currentAttemptScore > 0 else { return }
        if let world = currentWorldId {
            worldScores[world, default: 0] += currentAttemptScore
        }
        totalScore += currentAttemptScore
        currentAttemptScore = 0
    }

    func shouldTriggerIntermission(world: Int, level: Int) -> Bool {
        level == 5 || level == 10
    }

    func bestScoreForLevel(world: Int, level: Int) -> Int {
        levelBestScores[levelKey(world: world, level: level)] ?? 0
    }

    /// Updates the best score for a level if the new score beats the old one.
    /// Returns `true` if this is a new best.
    @discardableResult
    func updateBestScoreIfNeeded(world: Int, level: Int, score: Int) -> Bool {
        let key = levelKey(world: world, level: level)
        let previous = levelBestScores[key] ?? 0
        if score > previous {
            levelBestScores[key] = score
            return true
        }
        return false
    }

    /// Star thresholds: 1★ = completed (200+), 2★ = 350+, 3★ = 550+
    func starsForLevel(world: Int, level: Int) -> Int {
        let best = bestScoreForLevel(world: world, level: level)
        if best >= 550 { return 3 }
        if best >= 350 { return 2 }
        if best > 0 { return 1 }
        return 0
    }

    /// Sum of all per-level best scores for a world
    func bestScoreForWorld(world: Int) -> Int {
        (1...10).reduce(0) { $0 + bestScoreForLevel(world: world, level: $1) }
    }

    /// Sum of all per-level best scores across all worlds
    var totalBestScore: Int {
        levelBestScores.values.reduce(0, +)
    }

    /// Total stars earned across all worlds
    var totalStars: Int {
        WorldLibrary.allWorlds.reduce(0) { total, world in
            total + (1...10).reduce(0) { $0 + starsForLevel(world: world.id, level: $1) }
        }
    }

    func resetCurrentLevelScore() {
        currentLevelScore = 0
        currentAttemptScore = 0
    }

    // MARK: - Stat Recording

    func recordDeath() {
        statsTotalDeaths += 1
        statsCurrentStreak = 0
    }

    func recordLevelComplete(flips: Int, collectibles: Int, elapsed: TimeInterval) {
        statsTotalLevelsCompleted += 1
        statsTotalFlips += flips
        statsTotalCollectibles += collectibles
        statsTotalPlayTime += elapsed
        statsCurrentStreak += 1
        if statsCurrentStreak > statsLongestStreak {
            statsLongestStreak = statsCurrentStreak
        }
    }

    func recordFlips(_ count: Int) {
        statsTotalFlips += count
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

    private func persistLevelBestScores() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(levelBestScores) {
            defaults.set(data, forKey: DefaultsKeys.levelBestScores)
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

    private static func loadLevelBestScores(from defaults: UserDefaults) -> [String: Int] {
        guard let data = defaults.data(forKey: DefaultsKeys.levelBestScores),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return decoded
    }
}
