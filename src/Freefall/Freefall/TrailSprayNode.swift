import SpriteKit

final class TrailSprayNode: SKNode {
    private var scatterNodes: [SKSpriteNode] = []
    private let maxScatterNodes = 1500
    private let scatterColor: UIColor

    init(color: UIColor) {
        self.scatterColor = color
        super.init()
        zPosition = 4
    }

    required init?(coder aDecoder: NSCoder) {
        self.scatterColor = .cyan
        super.init(coder: aDecoder)
    }

    func spawnScatterAtPosition(_ position: CGPoint) {
        if scatterNodes.count >= maxScatterNodes {
            return
        }

        let scatterCount = Int.random(in: 1...2)
        for _ in 0..<scatterCount {
            let offset = CGFloat.random(in: 6...10)
            let angle = CGFloat.random(in: 0..<(2 * .pi))
            let offsetX = cos(angle) * offset
            let offsetY = sin(angle) * offset

            let particle = SKSpriteNode(color: scatterColor, size: CGSize(width: 2, height: 2))
            particle.position = CGPoint(x: position.x + offsetX, y: position.y + offsetY)
            particle.alpha = CGFloat.random(in: 0.15...0.35)
            particle.zPosition = 4
            addChild(particle)
            scatterNodes.append(particle)
        }
    }

    func fadeOutAndClear(duration: TimeInterval, completion: @escaping () -> Void) {
        if scatterNodes.isEmpty {
            completion()
            return
        }

        let fadeAction = SKAction.fadeOut(withDuration: duration)
        let removeAction = SKAction.run { [weak self] in
            self?.scatterNodes.removeAll()
            completion()
        }
        let sequence = SKAction.sequence([fadeAction, removeAction])

        for node in scatterNodes {
            node.run(sequence)
        }
    }

    func clearImmediate() {
        for node in scatterNodes {
            node.removeFromParent()
        }
        scatterNodes.removeAll()
    }
}
