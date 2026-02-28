import SwiftUI

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

    var accentColorOpacity: Color {
        primaryColor.opacity(0.15)
    }
}

enum WorldLibrary {
    static let allWorlds: [WorldDefinition] = [
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
            bpmB: 95
        ),
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
            bpmB: 174
        ),
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
            bpmB: 165
        ),
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
            bpmB: 138
        )
    ]

    static func world(for id: Int) -> WorldDefinition? {
        allWorlds.first { $0.id == id }
    }
}
