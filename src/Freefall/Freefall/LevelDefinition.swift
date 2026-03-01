import CoreGraphics
import Foundation

struct LevelDefinition: Codable, Identifiable {
    struct ObstacleDefinition: Codable, Identifiable {
        enum ObstacleType: String, Codable {
            case rect
            case circle
            case polygon
            case line
        }

        var id: String {
            if let identifier {
                return identifier
            }
            return "\(type.rawValue)-\(position.x)-\(position.y)-\(rotation)"
        }

        private enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case type
            case position
            case size
            case radius
            case points
            case rotation
            case style
        }

        var identifier: String?
        let type: ObstacleType
        let position: CGPoint
        let size: CGSize?
        let radius: CGFloat?
        let points: [CGPoint]?
        let rotation: CGFloat
        let style: String
    }

    struct CollectibleDefinition: Codable, Identifiable {
        var id: String { position.debugDescription }
        let position: CGPoint
    }

    var id: String { "W\(worldId)L\(levelId)" }

    let worldId: Int
    let levelId: Int
    let launchPosition: CGPoint
    let launchVelocity: CGVector
    let goalPosition: CGPoint
    let goalRadius: CGFloat
    let initialGravityDown: Bool
    let parFlips: Int
    let parTime: TimeInterval
    let obstacles: [ObstacleDefinition]
    let collectibles: [CollectibleDefinition]?

    private enum CodingKeys: String, CodingKey {
        case worldId
        case levelId
        case launchPosition
        case launchVelocity
        case goalPosition
        case goalRadius
        case initialGravityDown
        case parFlips
        case parTime
        case obstacles
        case collectibles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        worldId = try container.decode(Int.self, forKey: .worldId)
        levelId = try container.decode(Int.self, forKey: .levelId)
        launchPosition = try container.decode(CGPoint.self, forKey: .launchPosition)
        launchVelocity = try container.decode(CGVector.self, forKey: .launchVelocity)
        goalPosition = try container.decode(CGPoint.self, forKey: .goalPosition)
        goalRadius = try container.decode(CGFloat.self, forKey: .goalRadius)
        initialGravityDown = try container.decode(Bool.self, forKey: .initialGravityDown)
        parFlips = try container.decode(Int.self, forKey: .parFlips)
        obstacles = try container.decode([ObstacleDefinition].self, forKey: .obstacles)
        collectibles = try container.decodeIfPresent([CollectibleDefinition].self, forKey: .collectibles)
        parTime = try container.decodeIfPresent(TimeInterval.self, forKey: .parTime) ?? 10.0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(worldId, forKey: .worldId)
        try container.encode(levelId, forKey: .levelId)
        try container.encode(launchPosition, forKey: .launchPosition)
        try container.encode(launchVelocity, forKey: .launchVelocity)
        try container.encode(goalPosition, forKey: .goalPosition)
        try container.encode(goalRadius, forKey: .goalRadius)
        try container.encode(initialGravityDown, forKey: .initialGravityDown)
        try container.encode(parFlips, forKey: .parFlips)
        try container.encode(parTime, forKey: .parTime)
        try container.encode(obstacles, forKey: .obstacles)
        try container.encodeIfPresent(collectibles, forKey: .collectibles)
    }
}

enum LevelLoaderError: Error, LocalizedError {
    case fileNotFound(String)
    case failedToDecode(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let file):
            return "Level file not found: \(file)"
        case .failedToDecode(let details):
            return "Failed to decode level: \(details)"
        }
    }
}

struct LevelLoader {
    private let bundle: Bundle
    private let decoder: JSONDecoder

    init(bundle: Bundle = .main, decoder: JSONDecoder = JSONDecoder()) {
        self.bundle = bundle
        self.decoder = decoder
    }

    func loadLevel(world: Int, level: Int) throws -> LevelDefinition {
        let fileName = LevelLoader.fileName(world: world, level: level)
        let subdirectory = "levels/world\(world)"

        guard let url = bundle.url(forResource: fileName, withExtension: "json", subdirectory: subdirectory) else {
            throw LevelLoaderError.fileNotFound("\(subdirectory)/\(fileName).json")
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(LevelDefinition.self, from: data)
        } catch {
            throw LevelLoaderError.failedToDecode(error.localizedDescription)
        }
    }

    private static func fileName(world: Int, level: Int) -> String {
        String(format: "w%dl%02d", world, level)
    }
}
