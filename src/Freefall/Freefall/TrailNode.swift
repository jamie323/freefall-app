import SpriteKit

final class TrailNode: SKNode {
    // Two trails: a wide glow behind, and a sharp core on top
    private let glowLine = SKShapeNode()
    private let coreLine = SKShapeNode()
    private var positions: [CGPoint] = []
    private let maxPositions = 120            // ring buffer — cap at 120 segments (~2 seconds of trail)
    private var distanceTravelled: CGFloat = 0
    private var lastPosition: CGPoint = .zero
    private let startColor: UIColor
    private let endColor: UIColor
    private let estimatedLevelLength: CGFloat

    init(startPosition: CGPoint, startColor: UIColor, endColor: UIColor, estimatedLevelLength: CGFloat) {
        self.startColor = startColor
        self.endColor = endColor
        self.estimatedLevelLength = estimatedLevelLength
        super.init()

        lastPosition = startPosition
        positions.reserveCapacity(maxPositions + 1)

        // Glow layer — wide, soft, additive
        glowLine.zPosition = 3
        glowLine.blendMode = .add
        glowLine.lineWidth = 12
        glowLine.lineCap = .round
        glowLine.lineJoin = .round
        glowLine.alpha = 0.2
        addChild(glowLine)

        // Core layer — sharp, bright
        coreLine.zPosition = 4
        coreLine.blendMode = .add
        coreLine.lineWidth = 5
        coreLine.lineCap = .round
        coreLine.lineJoin = .round
        coreLine.alpha = 0.9
        addChild(coreLine)
    }

    required init?(coder aDecoder: NSCoder) {
        self.startColor = .cyan
        self.endColor = UIColor(red: 1, green: 0.078, blue: 0.576, alpha: 1)
        self.estimatedLevelLength = 1000
        super.init(coder: aDecoder)
    }

    func appendPosition(_ position: CGPoint) {
        let distance = hypot(position.x - lastPosition.x, position.y - lastPosition.y)
        distanceTravelled += distance
        lastPosition = position

        positions.append(position)

        // Trim oldest positions to keep bounded
        if positions.count > maxPositions {
            positions.removeFirst(positions.count - maxPositions)
        }

        rebuildPath()
        updateStrokeColor()
    }

    private func rebuildPath() {
        guard positions.count >= 2 else {
            glowLine.path = nil
            coreLine.path = nil
            return
        }
        let path = CGMutablePath()
        path.move(to: positions[0])
        for i in 1..<positions.count {
            path.addLine(to: positions[i])
        }
        glowLine.path = path
        coreLine.path = path
    }

    private func updateStrokeColor() {
        let t = min(1, distanceTravelled / estimatedLevelLength)
        let color = interpolateColor(from: startColor, to: endColor, t: t)
        coreLine.strokeColor = color
        glowLine.strokeColor = color
    }

    private func interpolateColor(from: UIColor, to: UIColor, t: CGFloat) -> UIColor {
        var fromR: CGFloat = 0, fromG: CGFloat = 0, fromB: CGFloat = 0, fromA: CGFloat = 1
        var toR: CGFloat = 0, toG: CGFloat = 0, toB: CGFloat = 0, toA: CGFloat = 1

        from.getRed(&fromR, green: &fromG, blue: &fromB, alpha: &fromA)
        to.getRed(&toR, green: &toG, blue: &toB, alpha: &toA)

        let r = fromR + (toR - fromR) * t
        let g = fromG + (toG - fromG) * t
        let b = fromB + (toB - fromB) * t
        let a = fromA + (toA - fromA) * t

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }

    func fadeOut(duration: TimeInterval, completion: @escaping () -> Void) {
        let fadeAction = SKAction.fadeOut(withDuration: duration)
        let removeAction = SKAction.run(completion)
        let sequence = SKAction.sequence([fadeAction, removeAction])
        run(sequence)
    }
}
