import SwiftUI
import Observation

// MARK: - Trail Styles

struct TrailStyle: Identifiable, Hashable {
    let id: String
    let name: String
    let startColor: Color
    let endColor: Color
    let unlockRequirement: UnlockRequirement

    enum UnlockRequirement: Hashable {
        case free                          // Available from start
        case stars(Int)                    // Earn N total stars
        case completeWorld(Int)            // Beat all 10 levels of world N
        case sRankCount(Int)               // Get S rank on N levels
        case allCollectiblesWorld(Int)     // Get all collectibles in a world
    }
}

// MARK: - Ball Skins

struct BallSkin: Identifiable, Hashable {
    let id: String
    let name: String
    let color: Color
    let glowColor: Color
    let unlockRequirement: TrailStyle.UnlockRequirement

    /// Whether this skin uses the world color instead of its own
    let usesWorldColor: Bool
}

// MARK: - Cosmetics Library

enum CosmeticsLibrary {
    static let trails: [TrailStyle] = [
        // Default — uses world colors (handled specially in GameScene)
        TrailStyle(id: "default", name: "WORLD", startColor: .clear, endColor: .clear, unlockRequirement: .free),
        // Unlockable trails
        TrailStyle(id: "fire", name: "FIRE", startColor: .hex("#FF4400"), endColor: .hex("#FFD700"), unlockRequirement: .stars(15)),
        TrailStyle(id: "ice", name: "ICE", startColor: .hex("#88DDFF"), endColor: .hex("#FFFFFF"), unlockRequirement: .stars(30)),
        TrailStyle(id: "toxic", name: "TOXIC", startColor: .hex("#39FF14"), endColor: .hex("#006600"), unlockRequirement: .stars(50)),
        TrailStyle(id: "sunset", name: "SUNSET", startColor: .hex("#FF6B6B"), endColor: .hex("#FFE66D"), unlockRequirement: .completeWorld(3)),
        TrailStyle(id: "midnight", name: "MIDNIGHT", startColor: .hex("#191970"), endColor: .hex("#9400D3"), unlockRequirement: .completeWorld(5)),
        TrailStyle(id: "gold", name: "GOLD", startColor: .hex("#FFD700"), endColor: .hex("#FF8C00"), unlockRequirement: .stars(80)),
        TrailStyle(id: "rainbow", name: "PRISMATIC", startColor: .hex("#FF0000"), endColor: .hex("#0000FF"), unlockRequirement: .stars(120)),
        TrailStyle(id: "void", name: "VOID", startColor: .hex("#CC00FF"), endColor: .hex("#000000"), unlockRequirement: .completeWorld(7)),
        TrailStyle(id: "platinum", name: "PLATINUM", startColor: .hex("#E5E4E2"), endColor: .hex("#C0C0C0"), unlockRequirement: .sRankCount(20)),
        TrailStyle(id: "neon", name: "NEON PINK", startColor: .hex("#FF1493"), endColor: .hex("#FF69B4"), unlockRequirement: .stars(160)),
        TrailStyle(id: "master", name: "MASTER", startColor: .hex("#FFFFFF"), endColor: .hex("#FFD700"), unlockRequirement: .stars(200)),
    ]

    static let ballSkins: [BallSkin] = [
        // Default — white ball, world-colored glow
        BallSkin(id: "default", name: "CLASSIC", color: .white, glowColor: .clear, unlockRequirement: .free, usesWorldColor: true),
        // Unlockable skins
        BallSkin(id: "ember", name: "EMBER", color: .hex("#FF4400"), glowColor: .hex("#FF6600"), unlockRequirement: .stars(10), usesWorldColor: false),
        BallSkin(id: "frost", name: "FROST", color: .hex("#88DDFF"), glowColor: .hex("#AAEEFF"), unlockRequirement: .stars(25), usesWorldColor: false),
        BallSkin(id: "lime", name: "LIME", color: .hex("#39FF14"), glowColor: .hex("#66FF44"), unlockRequirement: .completeWorld(2), usesWorldColor: false),
        BallSkin(id: "solar", name: "SOLAR", color: .hex("#FFD700"), glowColor: .hex("#FFAA00"), unlockRequirement: .stars(45), usesWorldColor: false),
        BallSkin(id: "phantom", name: "PHANTOM", color: .hex("#8B00FF"), glowColor: .hex("#AA44FF"), unlockRequirement: .completeWorld(4), usesWorldColor: false),
        BallSkin(id: "rose", name: "ROSE", color: .hex("#FF1493"), glowColor: .hex("#FF69B4"), unlockRequirement: .stars(70), usesWorldColor: false),
        BallSkin(id: "chrome", name: "CHROME", color: .hex("#C0C0C0"), glowColor: .hex("#E8E8E8"), unlockRequirement: .stars(100), usesWorldColor: false),
        BallSkin(id: "obsidian", name: "OBSIDIAN", color: .hex("#1A1A1A"), glowColor: .hex("#FF2200"), unlockRequirement: .completeWorld(6), usesWorldColor: false),
        BallSkin(id: "hologram", name: "HOLOGRAM", color: .hex("#00FFFF"), glowColor: .hex("#FF00FF"), unlockRequirement: .completeWorld(8), usesWorldColor: false),
        BallSkin(id: "diamond", name: "DIAMOND", color: .hex("#B9F2FF"), glowColor: .hex("#FFFFFF"), unlockRequirement: .sRankCount(30), usesWorldColor: false),
        BallSkin(id: "champion", name: "CHAMPION", color: .hex("#FFD700"), glowColor: .hex("#FFFFFF"), unlockRequirement: .stars(220), usesWorldColor: false),
    ]
}

// MARK: - Cosmetics Manager (persists selections)

@Observable
final class CosmeticsManager {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let gameState: GameState

    private(set) var selectedTrailId: String {
        didSet {
            guard oldValue != selectedTrailId else { return }
            defaults.set(selectedTrailId, forKey: "freefall.selectedTrail")
        }
    }

    private(set) var selectedBallSkinId: String {
        didSet {
            guard oldValue != selectedBallSkinId else { return }
            defaults.set(selectedBallSkinId, forKey: "freefall.selectedBallSkin")
        }
    }

    init(gameState: GameState, defaults: UserDefaults = .standard) {
        self.gameState = gameState
        self.defaults = defaults
        self.selectedTrailId = defaults.string(forKey: "freefall.selectedTrail") ?? "default"
        self.selectedBallSkinId = defaults.string(forKey: "freefall.selectedBallSkin") ?? "default"
    }

    // MARK: - Selection

    func selectTrail(_ id: String) {
        guard isTrailUnlocked(id) else { return }
        selectedTrailId = id
    }

    func selectBallSkin(_ id: String) {
        guard isBallSkinUnlocked(id) else { return }
        selectedBallSkinId = id
    }

    var selectedTrail: TrailStyle {
        CosmeticsLibrary.trails.first { $0.id == selectedTrailId } ?? CosmeticsLibrary.trails[0]
    }

    var selectedBallSkin: BallSkin {
        CosmeticsLibrary.ballSkins.first { $0.id == selectedBallSkinId } ?? CosmeticsLibrary.ballSkins[0]
    }

    // MARK: - Unlock Checking

    func isTrailUnlocked(_ id: String) -> Bool {
        guard let trail = CosmeticsLibrary.trails.first(where: { $0.id == id }) else { return false }
        return isRequirementMet(trail.unlockRequirement)
    }

    func isBallSkinUnlocked(_ id: String) -> Bool {
        guard let skin = CosmeticsLibrary.ballSkins.first(where: { $0.id == id }) else { return false }
        return isRequirementMet(skin.unlockRequirement)
    }

    func unlockProgress(for requirement: TrailStyle.UnlockRequirement) -> (current: Int, target: Int) {
        switch requirement {
        case .free:
            return (1, 1)
        case .stars(let target):
            return (gameState.totalStars, target)
        case .completeWorld(let worldId):
            let completed = gameState.completedCountForWorld(world: worldId)
            return (completed, 10)
        case .sRankCount(let target):
            return (totalSRanks(), target)
        case .allCollectiblesWorld:
            // Simplified — just check if world is completed
            return (0, 1)
        }
    }

    private func isRequirementMet(_ requirement: TrailStyle.UnlockRequirement) -> Bool {
        switch requirement {
        case .free:
            return true
        case .stars(let needed):
            return gameState.totalStars >= needed
        case .completeWorld(let worldId):
            return gameState.completedCountForWorld(world: worldId) >= 10
        case .sRankCount(let needed):
            return totalSRanks() >= needed
        case .allCollectiblesWorld(let worldId):
            // For now, same as completing the world
            return gameState.completedCountForWorld(world: worldId) >= 10
        }
    }

    private func totalSRanks() -> Int {
        // S rank = score ≥ 550 (3 stars) — we approximate with 3-star count
        // A proper check would also require all collectibles, but we don't track that per-level yet
        var count = 0
        for world in WorldLibrary.allWorlds {
            for level in 1...10 {
                if gameState.starsForLevel(world: world.id, level: level) >= 3 {
                    count += 1
                }
            }
        }
        return count
    }

    func requirementDescription(_ requirement: TrailStyle.UnlockRequirement) -> String {
        switch requirement {
        case .free:
            return "Unlocked"
        case .stars(let n):
            return "Earn \(n) stars"
        case .completeWorld(let w):
            let worldName = WorldLibrary.world(for: w)?.name ?? "World \(w)"
            return "Complete \(worldName)"
        case .sRankCount(let n):
            return "Get S rank on \(n) levels"
        case .allCollectiblesWorld(let w):
            let worldName = WorldLibrary.world(for: w)?.name ?? "World \(w)"
            return "All diamonds in \(worldName)"
        }
    }
}
