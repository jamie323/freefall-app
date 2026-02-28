import SpriteKit

final class TrailNode: SKShapeNode {
    private let mutablePath = CGMutablePath()
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
        path = mutablePath
        zPosition = 3
        blendMode = .add
        lineWidth = 4
        lineCap = .round
        lineJoin = .round
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

        if distanceTravelled == 0 {
            mutablePath.move(to: position)
        } else {
            mutablePath.addLine(to: position)
        }

        lastPosition = position
        updateStrokeColor()
        path = mutablePath
    }

    private func updateStrokeColor() {
        let t = min(1, distanceTravelled / estimatedLevelLength)
        strokeColor = interpolateColor(from: startColor, to: endColor, t: t)
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
