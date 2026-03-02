import CoreGraphics
import Foundation

// MARK: - LevelDefinition

struct LevelDefinition: Identifiable {
    struct ObstacleDefinition: Identifiable {
        enum ObstacleType: String {
            case rect, circle, polygon, line
        }
        var id: String { identifier ?? "\(type.rawValue)-\(Int(position.x*1000))-\(Int(position.y*1000))" }
        var identifier: String?
        let type: ObstacleType
        let position: CGPoint
        let size: CGSize?
        let radius: CGFloat?
        let points: [CGPoint]?
        let rotation: CGFloat
        let style: String
    }

    struct CollectibleDefinition: Identifiable {
        var id: String { "\(Int(position.x*1000))-\(Int(position.y*1000))" }
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
}

// MARK: - Manual JSON decoding helpers

private func decodePoint(_ container: KeyedDecodingContainer<GenericKeys>, key: GenericKeys) throws -> CGPoint {
    let nested = try container.nestedContainer(keyedBy: GenericKeys.self, forKey: key)
    let x = try nested.decode(Double.self, forKey: .x)
    let y = try nested.decode(Double.self, forKey: .y)
    return CGPoint(x: x, y: y)
}

private func decodeVector(_ container: KeyedDecodingContainer<GenericKeys>, key: GenericKeys) throws -> CGVector {
    let nested = try container.nestedContainer(keyedBy: GenericKeys.self, forKey: key)
    let dx = try nested.decode(Double.self, forKey: .dx)
    let dy = try nested.decode(Double.self, forKey: .dy)
    return CGVector(dx: dx, dy: dy)
}

private func decodeSize(_ container: KeyedDecodingContainer<GenericKeys>, key: GenericKeys) throws -> CGSize {
    let nested = try container.nestedContainer(keyedBy: GenericKeys.self, forKey: key)
    let w = try nested.decode(Double.self, forKey: .width)
    let h = try nested.decode(Double.self, forKey: .height)
    return CGSize(width: w, height: h)
}

private enum GenericKeys: String, CodingKey {
    case id, type, position, size, radius, points, rotation, style
    case worldId, levelId, launchPosition, launchVelocity, goalPosition
    case goalRadius, initialGravityDown, parFlips, parTime
    case obstacles, collectibles
    case x, y, dx, dy, width, height
}

extension LevelDefinition {
    init(from data: Data) throws {
        let decoder = JSONDecoder()
        let raw = try decoder.decode(RawLevel.self, from: data)

        worldId           = raw.worldId
        levelId           = raw.levelId
        launchPosition    = CGPoint(x: raw.launchPosition.x, y: raw.launchPosition.y)
        launchVelocity    = CGVector(dx: raw.launchVelocity.dx, dy: raw.launchVelocity.dy)
        goalPosition      = CGPoint(x: raw.goalPosition.x, y: raw.goalPosition.y)
        goalRadius        = CGFloat(raw.goalRadius)
        initialGravityDown = raw.initialGravityDown
        parFlips          = raw.parFlips
        parTime           = raw.parTime ?? 10.0
        obstacles         = raw.obstacles.map { o in
            ObstacleDefinition(
                identifier: o.id,
                type: ObstacleDefinition.ObstacleType(rawValue: o.type) ?? .rect,
                position: CGPoint(x: o.position.x, y: o.position.y),
                size: o.size.map { CGSize(width: $0.width, height: $0.height) },
                radius: o.radius.map { CGFloat($0) },
                points: o.points?.map { CGPoint(x: $0.x, y: $0.y) },
                rotation: CGFloat(o.rotation ?? 0),
                style: o.style
            )
        }
        collectibles = raw.collectibles?.map { c in
            CollectibleDefinition(position: CGPoint(x: c.position.x, y: c.position.y))
        }
    }
}

// MARK: - Raw Decodable structs (plain Double, no CG types)

private struct RawPoint: Decodable { let x: Double; let y: Double }
private struct RawSize: Decodable  { let width: Double; let height: Double }
private struct RawVector: Decodable { let dx: Double; let dy: Double }

private struct RawObstacle: Decodable {
    let id: String?
    let type: String
    let position: RawPoint
    let size: RawSize?
    let radius: Double?
    let points: [RawPoint]?
    let rotation: Double?
    let style: String
}

private struct RawCollectible: Decodable {
    let position: RawPoint
}

private struct RawLevel: Decodable {
    let worldId: Int
    let levelId: Int
    let launchPosition: RawPoint
    let launchVelocity: RawVector
    let goalPosition: RawPoint
    let goalRadius: Double
    let initialGravityDown: Bool
    let parFlips: Int
    let parTime: Double?
    let obstacles: [RawObstacle]
    let collectibles: [RawCollectible]?
}

// MARK: - LevelLoader

enum LevelLoaderError: Error, LocalizedError {
    case fileNotFound(String)
    case failedToDecode(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let file): return "Level file not found: \(file)"
        case .failedToDecode(let msg): return "Failed to decode level: \(msg)"
        }
    }
}

struct LevelLoader {
    private let bundle: Bundle

    init(bundle: Bundle = .main) { self.bundle = bundle }

    func loadLevel(world: Int, level: Int) throws -> LevelDefinition {
        let fileName = LevelLoader.fileName(world: world, level: level)
        let subdirectory = "levels/world\(world)"

        guard let url = bundle.url(forResource: fileName, withExtension: "json", subdirectory: subdirectory) else {
            throw LevelLoaderError.fileNotFound("\(subdirectory)/\(fileName).json")
        }

        do {
            let data = try Data(contentsOf: url)
            return try LevelDefinition(from: data)
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
