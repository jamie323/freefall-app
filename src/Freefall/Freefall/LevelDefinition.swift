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
    let obstacles: [ObstacleDefinition]
    let collectibles: [CollectibleDefinition]?
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
