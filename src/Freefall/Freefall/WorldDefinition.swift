import SwiftUI

struct PhysicsConfig: Hashable {
    let gravityMagnitude: CGFloat
    let flipImpulse: CGFloat
    let maxVerticalVelocity: CGFloat
    let verticalDamping: CGFloat
}

struct WorldDefinition: Identifiable, Hashable {
    let id: Int
    let name: String
    let primaryColor: Color
    let secondaryColor: Color
    let accentColor: Color
    let trailStartColor: Color
    let trailEndColor: Color
    let backgroundImageName: String
    let musicFolderName: String
    let bpmA: Double  // BPM for track A (levels 1-5)
    let bpmB: Double  // BPM for track B (levels 6-10)
    let physicsConfig: PhysicsConfig

    var accentColorOpacity: Color {
        primaryColor.opacity(0.15)
    }
}

enum WorldLibrary {
    static let allWorlds: [WorldDefinition] = [
        // W1: Floaty/forgiving — low gravity, high damping, chill BPM. Learning world.
        WorldDefinition(
            id: 1,
            name: "THE BLOCK",
            primaryColor: .hex("#00D4FF"),
            secondaryColor: .hex("#1A1A2E"),
            accentColor: .hex("#FF1493"),
            trailStartColor: .hex("#00D4FF"),
            trailEndColor: .hex("#FF1493"),
            backgroundImageName: "world1-bg",
            musicFolderName: "world1-the-block",
            bpmA: 88,
            bpmB: 95,
            physicsConfig: PhysicsConfig(gravityMagnitude: 50, flipImpulse: 35, maxVerticalVelocity: 140, verticalDamping: 0.02)
        ),
        // W2: Snappy/twitchy — strong flip impulse, low damping, bouncy. Fast BPM.
        WorldDefinition(
            id: 2,
            name: "NEON YARD",
            primaryColor: .hex("#39FF14"),
            secondaryColor: .hex("#1A1A0A"),
            accentColor: .hex("#FFE600"),
            trailStartColor: .hex("#39FF14"),
            trailEndColor: .hex("#FFE600"),
            backgroundImageName: "world2-bg",
            musicFolderName: "world2-neon-yard",
            bpmA: 172,
            bpmB: 174,
            physicsConfig: PhysicsConfig(gravityMagnitude: 65, flipImpulse: 48, maxVerticalVelocity: 180, verticalDamping: 0.008)
        ),
        // W3: Heavy/sluggish — strong gravity, high damping, weak flip. Gritty, deliberate.
        WorldDefinition(
            id: 3,
            name: "UNDERGROUND",
            primaryColor: .hex("#FF6600"),
            secondaryColor: .hex("#1A0A00"),
            accentColor: .hex("#CC0000"),
            trailStartColor: .hex("#FF6600"),
            trailEndColor: .hex("#CC0000"),
            backgroundImageName: "world3-bg",
            musicFolderName: "world3-underground",
            bpmA: 160,
            bpmB: 165,
            physicsConfig: PhysicsConfig(gravityMagnitude: 75, flipImpulse: 32, maxVerticalVelocity: 130, verticalDamping: 0.03)
        ),
        // W4: Wild/precise — strong gravity, near-zero damping, high max velocity. Demands precision.
        WorldDefinition(
            id: 4,
            name: "STATIC",
            primaryColor: .hex("#8B00FF"),
            secondaryColor: .hex("#0A000A"),
            accentColor: .hex("#FFFFFF"),
            trailStartColor: .hex("#8B00FF"),
            trailEndColor: .hex("#FFFFFF"),
            backgroundImageName: "world4-bg",
            musicFolderName: "world4-static",
            bpmA: 132,
            bpmB: 138,
            physicsConfig: PhysicsConfig(gravityMagnitude: 70, flipImpulse: 42, maxVerticalVelocity: 200, verticalDamping: 0.005)
        )
    ]

    static func world(for id: Int) -> WorldDefinition? {
        allWorlds.first { $0.id == id }
    }
}
