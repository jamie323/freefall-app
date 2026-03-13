import SpriteKit
import UIKit

final class IntermissionScene: SKScene {
    weak var gameState: GameState?
    var onDeath: ((Int, TimeInterval) -> Void)?

    private struct TunnelSlice {
        let node: SKShapeNode
        var depth: CGFloat
        var spin: CGFloat
    }

    private struct FallingGate {
        let root: SKNode
        let leftPanel: SKShapeNode
        let rightPanel: SKShapeNode
        let glow: SKShapeNode
        var depth: CGFloat
        let gapCenter: CGFloat
        let gapWidth: CGFloat
        let roll: CGFloat
        let pulse: CGFloat
    }

    private enum Constants {
        static let playerRange: CGFloat = 165
        static let playerPlaneY: CGFloat = 0.82
        static let gateStartDepth: CGFloat = 0.07
        static let gateHitDepth: CGFloat = 0.95
        static let ringCount = 18
        static let streakCount = 90
    }

    private var tunnelSlices: [TunnelSlice] = []
    private var gates: [FallingGate] = []
    private var starStreaks: [SKShapeNode] = []

    private var pitGlow: SKShapeNode?
    private var horizonGlow: SKSpriteNode?
    private var laneReticle: SKShapeNode?
    private var speedLines: SKEmitterNode?

    private var scrollSpeed: CGFloat = 0.28
    private let speedIncreaseRate: CGFloat = 1.08
    private var spawnInterval: TimeInterval = 0.72
    private var spawnTimer: TimeInterval = 0
    private var speedRampTimer: TimeInterval = 0

    private var timeAlive: TimeInterval = 0
    private var score: Int = 0
    private var isDead = false
    private var lastUpdateTime: TimeInterval = 0

    private var playerX: CGFloat = 0
    private var targetPlayerX: CGFloat = 0
    private var touchSide: CGFloat = 0
    private var beatTimer: TimeInterval = 0
    private let bpm: Double = 170

    /// When true, tunnel animates but gates don't spawn and no death — used for tutorial overlay
    var waitingForStart = false

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, size.height > 0 else { return }
        rebuildScene()
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isDead else { return }

        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }

        let dt = min(1.0 / 20.0, currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        // When waiting for start (tutorial showing), only animate visuals — no gameplay
        if waitingForStart {
            updateTunnel(dt: dt)
            updateStreaks(dt: dt)
            updateBeat(dt: dt)
            return
        }

        timeAlive += dt
        score += Int((900 + scrollSpeed * 800) * dt)

        speedRampTimer += dt
        if speedRampTimer >= 3.0 {
            speedRampTimer = 0
            scrollSpeed *= speedIncreaseRate
            spawnInterval = max(0.28, spawnInterval * 0.94)
        }

        updatePlayer(dt: dt)
        updateTunnel(dt: dt)
        updateGates(dt: dt)
        updateStreaks(dt: dt)
        updateBeat(dt: dt)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let x = touch.location(in: self).x
        touchSide = x < size.width / 2 ? -1 : 1
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchSide = 0
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchSide = 0
    }

    private func setupScene() {
        removeAllChildren()
        tunnelSlices.removeAll()
        gates.removeAll()
        starStreaks.removeAll()
        pitGlow = nil
        horizonGlow = nil
        laneReticle = nil
        speedLines = nil
        rebuildScene()
    }

    private func rebuildScene() {
        removeAllChildren()
        tunnelSlices.removeAll()
        gates.removeAll()
        starStreaks.removeAll()
        setupBackdrop()
        setupTunnel()
        setupReticle()
        setupSpeedLines()
        spawnTimer = 0
        playerX = 0
        targetPlayerX = 0
    }

    private func setupBackdrop() {
        let horizon = SKSpriteNode(color: UIColor(red: 0.10, green: 0.02, blue: 0.16, alpha: 1), size: size)
        horizon.position = CGPoint(x: size.width / 2, y: size.height / 2)
        horizon.alpha = 0.55
        horizon.blendMode = .add
        horizonGlow = horizon
        addChild(horizon)

        let pit = SKShapeNode(circleOfRadius: size.width * 0.08)
        pit.position = vanishingPoint
        pit.fillColor = UIColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1)
        pit.strokeColor = UIColor(red: 0.85, green: 0.18, blue: 1.0, alpha: 0.9)
        pit.glowWidth = 24
        pit.lineWidth = 2
        pit.zPosition = 5
        pitGlow = pit
        addChild(pit)

        for index in 0..<Constants.streakCount {
            let streak = SKShapeNode()
            streak.strokeColor = UIColor(white: 1.0, alpha: 0.18)
            streak.lineWidth = CGFloat.random(in: 0.8...1.8)
            streak.zPosition = 1
            streak.alpha = CGFloat.random(in: 0.2...0.8)
            let userData = NSMutableDictionary()
            userData["depth"] = NSNumber(value: Double(CGFloat(index) / CGFloat(Constants.streakCount)))
            userData["lane"] = NSNumber(value: Double(CGFloat.random(in: -1.1...1.1)))
            userData["length"] = NSNumber(value: Double(CGFloat.random(in: 10...28)))
            streak.userData = userData
            starStreaks.append(streak)
            addChild(streak)
        }
    }

    private func setupTunnel() {
        for index in 0..<Constants.ringCount {
            let node = SKShapeNode(rectOf: CGSize(width: size.width * 0.72, height: size.height * 0.72), cornerRadius: 22)
            node.lineWidth = 2.2
            node.strokeColor = UIColor(red: 0.26, green: 0.92, blue: 1.0, alpha: 0.9)
            node.glowWidth = 10
            node.fillColor = .clear
            node.zPosition = 2
            let depth = CGFloat(index) / CGFloat(Constants.ringCount)
            let spin = CGFloat.random(in: -0.7...0.7)
            tunnelSlices.append(TunnelSlice(node: node, depth: depth, spin: spin))
            addChild(node)
        }
    }

    private func setupReticle() {
        let reticle = SKShapeNode()
        reticle.lineWidth = 3
        reticle.strokeColor = .white
        reticle.glowWidth = 12
        reticle.zPosition = 20
        laneReticle = reticle
        addChild(reticle)
        layoutReticle()
    }

    private func setupSpeedLines() {
        let emitter = SKEmitterNode()
        emitter.particleTexture = makeParticleTexture()
        emitter.particleBirthRate = 140
        emitter.particleLifetime = 0.6
        emitter.particleLifetimeRange = 0.2
        emitter.particleScale = 0.08
        emitter.particleScaleRange = 0.04
        emitter.particleScaleSpeed = -0.08
        emitter.particleSpeed = 620
        emitter.particleSpeedRange = 180
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = .pi / 10
        emitter.particleAlpha = 0.28
        emitter.particleAlphaRange = 0.18
        emitter.particleAlphaSpeed = -0.4
        emitter.particleColor = UIColor(red: 0.7, green: 0.95, blue: 1.0, alpha: 1.0)
        emitter.particleBlendMode = .add
        emitter.position = CGPoint(x: size.width / 2, y: size.height + 40)
        emitter.particlePositionRange = CGVector(dx: size.width * 0.9, dy: 0)
        emitter.zPosition = 3
        speedLines = emitter
        addChild(emitter)
    }

    private func updatePlayer(dt: TimeInterval) {
        let laneSpeed: CGFloat = 1.85
        if touchSide != 0 {
            targetPlayerX += touchSide * laneSpeed * CGFloat(dt)
        } else {
            targetPlayerX += (0 - targetPlayerX) * min(1, CGFloat(dt) * 6.0)
        }

        targetPlayerX = min(max(targetPlayerX, -1.0), 1.0)
        playerX += (targetPlayerX - playerX) * min(1, CGFloat(dt) * 10.0)
        layoutReticle()
    }

    private func layoutReticle() {
        guard let laneReticle else { return }
        let x = size.width / 2 + playerX * Constants.playerRange
        let y = size.height * Constants.playerPlaneY
        let path = CGMutablePath()
        path.addArc(center: CGPoint(x: x, y: y), radius: 16, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        path.move(to: CGPoint(x: x - 26, y: y))
        path.addLine(to: CGPoint(x: x - 8, y: y))
        path.move(to: CGPoint(x: x + 8, y: y))
        path.addLine(to: CGPoint(x: x + 26, y: y))
        path.move(to: CGPoint(x: x, y: y - 26))
        path.addLine(to: CGPoint(x: x, y: y - 8))
        path.move(to: CGPoint(x: x, y: y + 8))
        path.addLine(to: CGPoint(x: x, y: y + 26))
        laneReticle.path = path
    }

    private func updateTunnel(dt: TimeInterval) {
        let vanishing = vanishingPoint
        for index in tunnelSlices.indices {
            tunnelSlices[index].depth += scrollSpeed * CGFloat(dt) * 0.55
            if tunnelSlices[index].depth > 1.0 {
                tunnelSlices[index].depth -= 1.0
            }

            let depth = tunnelSlices[index].depth
            let perspective = perspectiveScale(for: depth)
            let node = tunnelSlices[index].node
            node.position = CGPoint(
                x: vanishing.x + playerX * depth * 46,
                y: vanishing.y + depth * size.height * 0.56
            )
            node.setScale(perspective)
            node.zRotation += tunnelSlices[index].spin * CGFloat(dt) * 0.12
            node.alpha = max(0.08, min(0.9, 1.0 - depth * 0.35))
            node.glowWidth = 4 + perspective * 12
        }
    }

    private func updateGates(dt: TimeInterval) {
        spawnTimer += dt
        if spawnTimer >= spawnInterval {
            spawnTimer = 0
            spawnGate()
        }

        var survivors: [FallingGate] = []
        for var gate in gates {
            gate.depth += scrollSpeed * CGFloat(dt)
            if gate.depth >= 1.02 {
                gate.root.removeFromParent()
                continue
            }

            layout(gate: gate)

            if gate.depth >= Constants.gateHitDepth {
                if abs(playerX - gate.gapCenter) > gate.gapWidth * 0.5 {
                    triggerDeath()
                    return
                }
            }

            survivors.append(gate)
        }
        gates = survivors
    }

    private func spawnGate() {
        let gapCenter = CGFloat.random(in: -0.72...0.72)
        let gapWidth = CGFloat.random(in: 0.34...0.52)
        let roll = CGFloat.random(in: -0.35...0.35)
        let pulse = CGFloat.random(in: 0.7...1.3)

        let root = SKNode()
        root.zPosition = 12

        let leftPanel = SKShapeNode(rectOf: CGSize(width: 120, height: 28), cornerRadius: 8)
        let rightPanel = SKShapeNode(rectOf: CGSize(width: 120, height: 28), cornerRadius: 8)
        let glow = SKShapeNode(rectOf: CGSize(width: 160, height: 36), cornerRadius: 10)

        for panel in [leftPanel, rightPanel] {
            panel.fillColor = UIColor(red: 0.95, green: 0.18, blue: 0.08, alpha: 0.9)
            panel.strokeColor = UIColor(red: 1.0, green: 0.74, blue: 0.18, alpha: 1.0)
            panel.lineWidth = 2
            panel.glowWidth = 14
            panel.blendMode = .add
            root.addChild(panel)
        }

        glow.fillColor = .clear
        glow.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.22)
        glow.lineWidth = 1.5
        glow.glowWidth = 10
        glow.blendMode = .add
        root.addChild(glow)

        addChild(root)

        let gate = FallingGate(
            root: root,
            leftPanel: leftPanel,
            rightPanel: rightPanel,
            glow: glow,
            depth: Constants.gateStartDepth,
            gapCenter: gapCenter,
            gapWidth: gapWidth,
            roll: roll,
            pulse: pulse
        )
        layout(gate: gate)
        gates.append(gate)
    }

    private func layout(gate: FallingGate) {
        let perspective = perspectiveScale(for: gate.depth) * 1.15
        let width = size.width * 0.94 * perspective
        let height = max(18, size.height * 0.03 * perspective)
        let gapWidth = width * gate.gapWidth
        let centreX = size.width / 2 + gate.gapCenter * Constants.playerRange * perspective * 1.2 + playerX * gate.depth * 42
        let y = vanishingPoint.y + gate.depth * size.height * 0.72

        let leftWidth = max(18, (width - gapWidth) * 0.5)
        let rightWidth = leftWidth
        gate.leftPanel.path = CGPath(roundedRect: CGRect(x: -leftWidth / 2, y: -height / 2, width: leftWidth, height: height), cornerWidth: 10, cornerHeight: 10, transform: nil)
        gate.rightPanel.path = CGPath(roundedRect: CGRect(x: -rightWidth / 2, y: -height / 2, width: rightWidth, height: height), cornerWidth: 10, cornerHeight: 10, transform: nil)
        gate.leftPanel.position = CGPoint(x: -(gapWidth + leftWidth) / 2, y: 0)
        gate.rightPanel.position = CGPoint(x: (gapWidth + rightWidth) / 2, y: 0)
        gate.glow.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -height * 0.8, width: width, height: height * 1.6), cornerWidth: 12, cornerHeight: 12, transform: nil)

        gate.root.position = CGPoint(x: centreX, y: y)
        gate.root.zRotation = gate.roll * perspective
        gate.root.alpha = min(1.0, 0.15 + gate.depth * 1.1)
        gate.root.setScale(0.92 + perspective * 0.08)
        let pulse = 0.78 + sin(timeAlive * gate.pulse * 8) * 0.1
        gate.leftPanel.fillColor = UIColor(red: 1.0, green: pulse * 0.28, blue: 0.08, alpha: 0.95)
        gate.rightPanel.fillColor = UIColor(red: 1.0, green: pulse * 0.28, blue: 0.08, alpha: 0.95)
    }

    private func updateStreaks(dt: TimeInterval) {
        for streak in starStreaks {
            guard let userData = streak.userData,
                  let depthNumber = userData["depth"] as? NSNumber,
                  let laneNumber = userData["lane"] as? NSNumber,
                  let lengthNumber = userData["length"] as? NSNumber else { continue }

            let depth = CGFloat(depthNumber.doubleValue)
            let lane = CGFloat(laneNumber.doubleValue)
            let length = CGFloat(lengthNumber.doubleValue)

            let nextDepth = (depth + scrollSpeed * CGFloat(dt) * 0.9).truncatingRemainder(dividingBy: 1.0)
            userData["depth"] = NSNumber(value: Double(nextDepth))
            let perspective = perspectiveScale(for: nextDepth)
            let x = vanishingPoint.x + lane * size.width * 0.36 * perspective
            let y = vanishingPoint.y + nextDepth * size.height * 0.82
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: y - length * perspective))
            path.addLine(to: CGPoint(x: x, y: y + length * perspective))
            streak.path = path
            streak.alpha = 0.08 + nextDepth * 0.35
        }
    }

    private func updateBeat(dt: TimeInterval) {
        beatTimer += dt
        let beatInterval = 60.0 / bpm
        if beatTimer >= beatInterval {
            beatTimer = 0
            pitGlow?.run(SKAction.sequence([
                SKAction.scale(to: 1.18, duration: 0.05),
                SKAction.scale(to: 1.0, duration: 0.18)
            ]))
            horizonGlow?.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.72, duration: 0.05),
                SKAction.fadeAlpha(to: 0.55, duration: 0.18)
            ]))
            laneReticle?.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 1.0, duration: 0.05),
                SKAction.fadeAlpha(to: 0.8, duration: 0.14)
            ]))
        }
    }

    private func triggerDeath() {
        guard !isDead else { return }
        isDead = true

        speedLines?.particleBirthRate = 0
        let finalMultiplier: Double = timeAlive > 30 ? 2.0 : timeAlive > 15 ? 1.5 : 1.0
        let finalScore = Int(Double(score) * finalMultiplier)
        let burstOrigin = CGPoint(
            x: size.width / 2 + playerX * Constants.playerRange,
            y: size.height * Constants.playerPlaneY
        )

        let crashFlash = SKSpriteNode(color: .white, size: size)
        crashFlash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        crashFlash.alpha = 0.7
        crashFlash.blendMode = .add
        crashFlash.zPosition = 200
        addChild(crashFlash)
        crashFlash.run(.sequence([.fadeOut(withDuration: 0.28), .removeFromParent()]))

        if let laneReticle {
            for _ in 0..<40 {
                let shard = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...4.0))
                shard.fillColor = .white
                shard.strokeColor = .clear
                shard.glowWidth = 10
                shard.position = burstOrigin
                shard.zPosition = 220
                addChild(shard)
                let angle = CGFloat.random(in: 0..<(2 * .pi))
                let distance = CGFloat.random(in: 80...260)
                let duration = TimeInterval.random(in: 0.35...0.75)
                shard.run(.sequence([
                    .group([
                        .moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: duration),
                        .fadeOut(withDuration: duration)
                    ]),
                    .removeFromParent()
                ]))
            }
            laneReticle.removeFromParent()
        }

        run(.sequence([
            .wait(forDuration: 1.1),
            .run { [weak self] in
                guard let self else { return }
                self.onDeath?(finalScore, self.timeAlive)
            }
        ]))
    }

    private var vanishingPoint: CGPoint {
        CGPoint(x: size.width / 2, y: size.height * 0.22)
    }

    private func perspectiveScale(for depth: CGFloat) -> CGFloat {
        let eased = CGFloat(pow(Double(max(0.02, depth)), 1.18))
        return 0.18 + eased * 3.4
    }

    private func makeParticleTexture() -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return SKTexture(image: image)
    }
}
