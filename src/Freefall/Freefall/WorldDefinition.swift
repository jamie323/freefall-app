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
            physicsConfig: PhysicsConfig(gravityMagnitude: 38, flipImpulse: 30, maxVerticalVelocity: 125, verticalDamping: 0.025)
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
            physicsConfig: PhysicsConfig(gravityMagnitude: 72, flipImpulse: 52, maxVerticalVelocity: 190, verticalDamping: 0.006)
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
            physicsConfig: PhysicsConfig(gravityMagnitude: 85, flipImpulse: 28, maxVerticalVelocity: 115, verticalDamping: 0.04)
        ),
        // W4: Wild/precise — near-zero damping, high max velocity. Demands precision.
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
            physicsConfig: PhysicsConfig(gravityMagnitude: 68, flipImpulse: 44, maxVerticalVelocity: 210, verticalDamping: 0.004)
        ),
        // W5: Slippery/momentum — zero damping, ball never slows vertically. Ice-skating overshoot feel.
        WorldDefinition(
            id: 5,
            name: "GLASS",
            primaryColor: .hex("#A0E7FF"),
            secondaryColor: .hex("#0A1A2E"),
            accentColor: .hex("#E0F7FF"),
            trailStartColor: .hex("#A0E7FF"),
            trailEndColor: .hex("#E0F7FF"),
            backgroundImageName: "world5-bg",
            musicFolderName: "world5-glass",
            bpmA: 110,
            bpmB: 118,
            physicsConfig: PhysicsConfig(gravityMagnitude: 32, flipImpulse: 26, maxVerticalVelocity: 240, verticalDamping: 0.0)
        ),
        // W6: Explosive/short hops — extreme gravity, huge impulse, high damping. Deliberate committed moves.
        WorldDefinition(
            id: 6,
            name: "FURNACE",
            primaryColor: .hex("#FF2200"),
            secondaryColor: .hex("#1A0500"),
            accentColor: .hex("#FF8800"),
            trailStartColor: .hex("#FF2200"),
            trailEndColor: .hex("#FF8800"),
            backgroundImageName: "world6-bg",
            musicFolderName: "world6-furnace",
            bpmA: 180,
            bpmB: 185,
            physicsConfig: PhysicsConfig(gravityMagnitude: 105, flipImpulse: 65, maxVerticalVelocity: 105, verticalDamping: 0.05)
        ),
        // W7: Inverted start — gravity starts UP on every level. Mentally disorienting. Forces re-learning.
        WorldDefinition(
            id: 7,
            name: "VOID",
            primaryColor: .hex("#CC00FF"),
            secondaryColor: .hex("#0A000F"),
            accentColor: .hex("#FF66FF"),
            trailStartColor: .hex("#CC00FF"),
            trailEndColor: .hex("#FF66FF"),
            backgroundImageName: "world7-bg",
            musicFolderName: "world7-void",
            bpmA: 140,
            bpmB: 148,
            physicsConfig: PhysicsConfig(gravityMagnitude: 55, flipImpulse: 36, maxVerticalVelocity: 165, verticalDamping: 0.015)
        ),
        // W8: Brutal precision — near-max everything. Fast, violent reactions. Expert-only.
        WorldDefinition(
            id: 8,
            name: "MAINFRAME",
            primaryColor: .hex("#00FF88"),
            secondaryColor: .hex("#000A05"),
            accentColor: .hex("#88FFCC"),
            trailStartColor: .hex("#00FF88"),
            trailEndColor: .hex("#88FFCC"),
            backgroundImageName: "world8-bg",
            musicFolderName: "world8-mainframe",
            bpmA: 150,
            bpmB: 158,
            physicsConfig: PhysicsConfig(gravityMagnitude: 95, flipImpulse: 48, maxVerticalVelocity: 250, verticalDamping: 0.002)
        )
    ]

    static func world(for id: Int) -> WorldDefinition? {
        allWorlds.first { $0.id == id }
    }
}
