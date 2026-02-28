import SpriteKit

final class ObstacleNode: SKShapeNode {
    private enum Constants {
        static let neonOutlineColor = UIColor(red: 0, green: 0.831, blue: 1, alpha: 1)
        static let neonOutlineWidth: CGFloat = 2
        static let neonGlowWidth: CGFloat = 3
    }

    init(obstacle: LevelDefinition.ObstacleDefinition, normalizedToScreenSize size: CGSize) {
        super.init()
        configureGeometry(from: obstacle, screenSize: size)
        configurePhysics()
        configureAppearance()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    private func configureGeometry(from obstacle: LevelDefinition.ObstacleDefinition, screenSize: CGSize) {
        let absolutePosition = CGPoint(x: obstacle.position.x * screenSize.width, y: obstacle.position.y * screenSize.height)
        position = absolutePosition

        switch obstacle.type {
        case .rect:
            guard let size = obstacle.size else { break }
            let absoluteSize = CGSize(width: size.width * screenSize.width, height: size.height * screenSize.height)
            path = CGPath(rect: CGRect(x: -absoluteSize.width / 2, y: -absoluteSize.height / 2, width: absoluteSize.width, height: absoluteSize.height), transform: nil)
            zRotation = CGFloat(obstacle.rotation * .pi / 180)

        case .circle:
            guard let radius = obstacle.radius else { break }
            let absoluteRadius = radius * screenSize.width
            path = CGPath(ellipseIn: CGRect(x: -absoluteRadius, y: -absoluteRadius, width: absoluteRadius * 2, height: absoluteRadius * 2), transform: nil)

        case .polygon:
            guard let points = obstacle.points, !points.isEmpty else { break }
            let absolutePoints = points.map { CGPoint(x: $0.x * screenSize.width, y: $0.y * screenSize.height) }
            let mutablePath = CGMutablePath()
            mutablePath.move(to: absolutePoints[0])
            for point in absolutePoints.dropFirst() {
                mutablePath.addLine(to: point)
            }
            mutablePath.closeSubpath()
            path = mutablePath

        case .line:
            guard let points = obstacle.points, points.count >= 2 else { break }
            let mutablePath = CGMutablePath()
            let startAbsolute = CGPoint(x: points[0].x * screenSize.width, y: points[0].y * screenSize.height)
            let endAbsolute = CGPoint(x: points[1].x * screenSize.width, y: points[1].y * screenSize.height)
            mutablePath.move(to: startAbsolute)
            mutablePath.addLine(to: endAbsolute)
            path = mutablePath
        }
    }

    private func configurePhysics() {
        guard let path = path else { return }
        physicsBody = SKPhysicsBody(polygonFrom: path)
        physicsBody?.isDynamic = false
        physicsBody?.affectedByGravity = false
        physicsBody?.allowsRotation = false
        physicsBody?.categoryBitMask = PhysicsCategory.obstacle
        physicsBody?.collisionBitMask = PhysicsCategory.sphere
        physicsBody?.contactTestBitMask = PhysicsCategory.sphere
    }

    private func configureAppearance() {
        fillColor = .clear
        strokeColor = Constants.neonOutlineColor
        lineWidth = Constants.neonOutlineWidth
        lineCap = .round
        lineJoin = .round
    }
}

struct PhysicsCategory {
    static let sphere: UInt32 = 1 << 0
    static let obstacle: UInt32 = 1 << 1
    static let goal: UInt32 = 1 << 2
    static let boundary: UInt32 = 1 << 3
}
