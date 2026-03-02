import CoreGraphics
import Foundation

// MARK: - CGPoint / CGSize / CGVector Codable extensions
extension CGPoint: @retroactive Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(x: try c.decode(CGFloat.self, forKey: .x),
                  y: try c.decode(CGFloat.self, forKey: .y))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(x, forKey: .x); try c.encode(y, forKey: .y)
    }
    enum CodingKeys: String, CodingKey { case x, y }
}

extension CGSize: @retroactive Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(width: try c.decode(CGFloat.self, forKey: .width),
                  height: try c.decode(CGFloat.self, forKey: .height))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(width, forKey: .width); try c.encode(height, forKey: .height)
    }
    enum CodingKeys: String, CodingKey { case width, height }
}

extension CGVector: @retroactive Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(dx: try c.decode(CGFloat.self, forKey: .dx),
                  dy: try c.decode(CGFloat.self, forKey: .dy))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(dx, forKey: .dx); try c.encode(dy, forKey: .dy)
    }
    enum CodingKeys: String, CodingKey { case dx, dy }
}

// MARK: - LevelDefinition

struct LevelDefinition: Codable, Identifiable {
    struct ObstacleDefinition: Codable, Identifiable {
        enum ObstacleType: String, Codable {
            case rect, circle, polygon, line
        }

        var id: String {
            if let identifier { return identifier }
            return "\(type.rawValue)-\(position.x)-\(position.y)-\(rotation)"
        }

        private enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case type, position, size, radius, points, rotation, style
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
        var id: String { "\(position.x)-\(position.y)" }
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
        case worldId, levelId, launchPosition, launchVelocity
        case goalPosition, goalRadius, initialGravityDown
        case parFlips, parTime, obstacles, collectibles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        worldId          = try container.decode(Int.self,      forKey: .worldId)
        levelId          = try container.decode(Int.self,      forKey: .levelId)
        launchPosition   = try container.decode(CGPoint.self,  forKey: .launchPosition)
        launchVelocity   = try container.decode(CGVector.self, forKey: .launchVelocity)
        goalPosition     = try container.decode(CGPoint.self,  forKey: .goalPosition)
        goalRadius       = try container.decode(CGFloat.self,  forKey: .goalRadius)
        initialGravityDown = try container.decode(Bool.self,   forKey: .initialGravityDown)
        parFlips         = try container.decode(Int.self,      forKey: .parFlips)
        obstacles        = try container.decode([ObstacleDefinition].self,   forKey: .obstacles)
        collectibles     = try container.decodeIfPresent([CollectibleDefinition].self, forKey: .collectibles)
        parTime          = try container.decodeIfPresent(TimeInterval.self,  forKey: .parTime) ?? 10.0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(worldId, forKey: .worldId)
        try c.encode(levelId, forKey: .levelId)
        try c.encode(launchPosition, forKey: .launchPosition)
        try c.encode(launchVelocity, forKey: .launchVelocity)
        try c.encode(goalPosition, forKey: .goalPosition)
        try c.encode(goalRadius, forKey: .goalRadius)
        try c.encode(initialGravityDown, forKey: .initialGravityDown)
        try c.encode(parFlips, forKey: .parFlips)
        try c.encode(parTime, forKey: .parTime)
        try c.encode(obstacles, forKey: .obstacles)
        try c.encodeIfPresent(collectibles, forKey: .collectibles)
    }
}

// MARK: - LevelLoader

enum LevelLoaderError: Error, LocalizedError {
    case fileNotFound(String)
    case failedToDecode(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let file):   return "Level file not found: \(file)"
        case .failedToDecode(let msg):  return "Failed to decode level: \(msg)"
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
            do {
                return try decoder.decode(LevelDefinition.self, from: data)
            } catch let decodingError as DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    throw LevelLoaderError.failedToDecode("Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
                case .typeMismatch(let type, let context):
                    throw LevelLoaderError.failedToDecode("Type mismatch: expected \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
                case .valueNotFound(let type, let context):
                    throw LevelLoaderError.failedToDecode("Value not found: \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
                case .dataCorrupted(let context):
                    throw LevelLoaderError.failedToDecode("Data corrupted at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)")
                @unknown default:
                    throw LevelLoaderError.failedToDecode(decodingError.localizedDescription)
                }
            }
        } catch let e as LevelLoaderError {
            throw e
        } catch {
            throw LevelLoaderError.failedToDecode(error.localizedDescription)
        }
    }

    static func fileName(world: Int, level: Int) -> String {
        String(format: "w%dl%02d", world, level)
    }
}
