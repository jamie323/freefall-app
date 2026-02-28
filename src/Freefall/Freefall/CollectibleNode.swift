import SpriteKit

final class CollectibleNode: SKNode {
    let collectibleId: String
    private let radius: CGFloat = 6
    private let glow: SKShapeNode = SKShapeNode()

    init(position: CGPoint, worldColor: UIColor, id: String = UUID().uuidString) {
        self.collectibleId = id
        super.init()

        self.position = position

        // Core circle (radius 6pt)
        let core = SKShapeNode(circleOfRadius: radius)
        core.fillColor = worldColor
        core.strokeColor = .clear
        core.zPosition = 1
        addChild(core)

        // Glow effect (radius 12pt)
        glow.path = UIBezierPath(arcCenter: .zero, radius: 12, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true).cgPath
        glow.fillColor = .clear
        glow.strokeColor = worldColor
        glow.lineWidth = 2
        glow.blendMode = .add
        glow.zPosition = 0
        addChild(glow)

        // Pulse animation
        addPulseAnimation()

        // Physics
        let physicsBody = SKPhysicsBody(circleOfRadius: 10)
        physicsBody.isDynamic = false
        physicsBody.affectedByGravity = false
        physicsBody.categoryBitMask = PhysicsCategory.collectible
        physicsBody.collisionBitMask = 0
        physicsBody.contactTestBitMask = PhysicsCategory.sphere
        self.physicsBody = physicsBody

        name = "collectible-\(id)"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addPulseAnimation() {
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.6)
        let scaleDown = SKAction.scale(to: 0.8, duration: 0.6)
        let pulse = SKAction.sequence([scaleDown, scaleUp])
        let repeatPulse = SKAction.repeatForever(pulse)
        run(repeatPulse)
    }
}
