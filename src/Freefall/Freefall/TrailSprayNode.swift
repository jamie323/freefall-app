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

        let scatterCount = Int.random(in: 1...3)
        for _ in 0..<scatterCount {
            let offset = CGFloat.random(in: 6...14)
            let angle = CGFloat.random(in: 0..<(2 * .pi))
            let offsetX = cos(angle) * offset
            let offsetY = sin(angle) * offset

            let sz = CGFloat.random(in: 2...4)
            let particle = SKSpriteNode(color: scatterColor, size: CGSize(width: sz, height: sz))
            particle.position = CGPoint(x: position.x + offsetX, y: position.y + offsetY)
            particle.alpha = CGFloat.random(in: 0.25...0.5)
            particle.zPosition = 4
            particle.blendMode = .add
            addChild(particle)
            scatterNodes.append(particle)

            // Particles drift outward and fade over time
            let driftDur = TimeInterval.random(in: 0.4...0.8)
            let driftDist = CGFloat.random(in: 4...10)
            particle.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: cos(angle) * driftDist, y: sin(angle) * driftDist, duration: driftDur),
                    SKAction.fadeOut(withDuration: driftDur)
                ]),
                SKAction.removeFromParent()
            ])) { [weak self] in
                self?.scatterNodes.removeAll { $0 === particle }
            }
        }
    }

    func fadeOutAndClear(duration: TimeInterval, completion: @escaping () -> Void) {
        if scatterNodes.isEmpty {
            completion()
            return
        }

        let fadeAction = SKAction.fadeOut(withDuration: duration)
        let cleanup = SKAction.run { [weak self] in
            guard let self = self else { return }
            for node in self.scatterNodes {
                node.removeFromParent()
            }
            self.scatterNodes.removeAll()
            self.alpha = 1
            completion()
        }
        let sequence = SKAction.sequence([fadeAction, cleanup])
        run(sequence)
    }

    func clearImmediate() {
        for node in scatterNodes {
            node.removeFromParent()
        }
        scatterNodes.removeAll()
        alpha = 1
    }
}
