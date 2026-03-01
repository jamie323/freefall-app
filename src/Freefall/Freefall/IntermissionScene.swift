import SpriteKit
import AVFoundation

class IntermissionScene: SKScene, SKPhysicsContactDelegate {
    // Ball: white glowing sphere, fixed at Y = screenHeight * 0.25 from bottom
    // Ball moves only on X axis. Springs back to centre when not touching.
    // Tunnel: two vertical wall nodes, left and right edges of screen
    // Obstacles: rectangular slabs that spawn at top, scroll downward
    // Camera: fixed. Obstacles move. Ball moves horizontally only.

    weak var gameState: GameState?
    var onDeath: ((Int, TimeInterval) -> Void)?  // score, survivalTime

    private var ball: SKShapeNode!
    private var scrollSpeed: CGFloat = 400      // pts/sec
    private let speedIncreaseRate: CGFloat = 0.08  // 8% every 3 seconds
    private var speedTimer: TimeInterval = 0
    private var timeAlive: TimeInterval = 0
    private var score: Int = 0
    private var isDead = false
    private var lastUpdateTime: TimeInterval = 0

    // Strobe
    private var strobeNode: SKSpriteNode!
    private var beatTimer: TimeInterval = 0
    private let bpm: Double = 170

    // Touch tracking
    private var touchSide: Int = 0  // -1 left, 0 none, 1 right

    override func didMove(to view: SKView) {
        setupScene()
        setupBall()
        setupStrobe()
        startObstacleSpawning()
    }

    private func setupScene() {
        backgroundColor = .black
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        physicsWorld.contactDelegate = self
    }

    private func setupBall() {
        let radius: CGFloat = 12
        ball = SKShapeNode(circleOfRadius: radius)
        ball.fillColor = .white
        ball.strokeColor = .clear
        ball.glowWidth = 8
        ball.position = CGPoint(x: size.width / 2, y: size.height * 0.25)
        ball.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        ball.physicsBody?.categoryBitMask = 0x1
        ball.physicsBody?.contactTestBitMask = 0x2
        ball.physicsBody?.collisionBitMask = 0
        ball.physicsBody?.affectedByGravity = false
        addChild(ball)
    }

    private func setupStrobe() {
        strobeNode = SKSpriteNode(color: .white, size: size)
        strobeNode.position = CGPoint(x: size.width/2, y: size.height/2)
        strobeNode.alpha = 0
        strobeNode.zPosition = 100
        addChild(strobeNode)
    }

    private func startObstacleSpawning() {
        let spawn = SKAction.run { [weak self] in self?.spawnObstacle() }
        let wait = SKAction.wait(forDuration: 0.8)
        run(SKAction.repeatForever(SKAction.sequence([spawn, wait])), withKey: "spawning")
    }

    private func spawnObstacle() {
        // Obstacle: a wide rectangle protruding from left OR right wall
        // Width: 40-55% of screen width. Height: 20-35pt.
        let fromLeft = Bool.random()
        let obstacleWidth = size.width * CGFloat.random(in: 0.40...0.55)
        let obstacleHeight: CGFloat = CGFloat.random(in: 20...35)

        let obstacle = SKShapeNode(rectOf: CGSize(width: obstacleWidth, height: obstacleHeight), cornerRadius: 3)
        obstacle.fillColor = UIColor(red: 0.8, green: 0.1, blue: 0.0, alpha: 1.0)  // dark red
        obstacle.strokeColor = UIColor(red: 1.0, green: 0.2, blue: 0.0, alpha: 1.0)  // bright red edge
        obstacle.glowWidth = 4

        let xPos = fromLeft ? obstacleWidth / 2 : size.width - obstacleWidth / 2
        obstacle.position = CGPoint(x: xPos, y: size.height + obstacleHeight)

        obstacle.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: obstacleWidth, height: obstacleHeight))
        obstacle.physicsBody?.categoryBitMask = 0x2
        obstacle.physicsBody?.contactTestBitMask = 0x1
        obstacle.physicsBody?.collisionBitMask = 0
        obstacle.physicsBody?.affectedByGravity = false
        obstacle.physicsBody?.isDynamic = false

        addChild(obstacle)

        // Remove when off screen
        let moveDown = SKAction.moveBy(x: 0, y: -(size.height + obstacleHeight * 2), duration: TimeInterval(size.height / scrollSpeed) * 1.5)
        let remove = SKAction.removeFromParent()
        obstacle.run(SKAction.sequence([moveDown, remove]))
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isDead else { return }

        // Delta time
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        timeAlive += dt

        // Score accumulation
        score += Int(scrollSpeed * 0.1 * CGFloat(dt))

        // Speed multiplier for score
        let multiplier: Double = timeAlive > 30 ? 2.0 : timeAlive > 15 ? 1.5 : 1.0
        _ = multiplier  // score already accumulates; apply multiplier at death

        // Speed ramp every 3 seconds
        speedTimer += dt
        if speedTimer >= 3.0 {
            speedTimer = 0
            scrollSpeed *= (1.0 + speedIncreaseRate)
            // Increase spawn rate too
            removeAction(forKey: "spawning")
            let newInterval = max(0.2, 0.8 * Double(400 / scrollSpeed))
            let spawn = SKAction.run { [weak self] in self?.spawnObstacle() }
            let wait = SKAction.wait(forDuration: newInterval)
            run(SKAction.repeatForever(SKAction.sequence([spawn, wait])), withKey: "spawning")
        }

        // Ball horizontal movement (spring to centre)
        let centreX = size.width / 2
        let dodgeSpeed: CGFloat = 280

        if touchSide != 0 {
            let direction = CGFloat(touchSide)
            ball.position.x += direction * dodgeSpeed * CGFloat(dt)
        } else {
            // Spring back to centre
            let diff = centreX - ball.position.x
            ball.position.x += diff * CGFloat(dt) * 4.0
        }

        // Clamp ball to screen
        ball.position.x = max(20, min(size.width - 20, ball.position.x))

        // Strobe: flash on beat
        beatTimer += dt
        let beatInterval = 60.0 / bpm
        if beatTimer >= beatInterval {
            beatTimer = 0
            strobeNode.alpha = 0.18
            strobeNode.run(SKAction.fadeOut(withDuration: 0.05))
        }

        // Scroll existing obstacles (those spawned before speed changed)
        // Note: obstacle nodes use their own SKAction moves so this is handled
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

    func didBegin(_ contact: SKPhysicsContact) {
        guard !isDead else { return }
        triggerDeath()
    }

    private func triggerDeath() {
        isDead = true
        removeAction(forKey: "spawning")

        // Apply survival multiplier to final score
        let multiplier: Double = timeAlive > 30 ? 2.0 : timeAlive > 15 ? 1.5 : 1.0
        let finalScore = Int(Double(score) * multiplier)

        // Particle burst at ball position
        let burst = SKEmitterNode()
        burst.particleBirthRate = 0
        burst.numParticlesToEmit = 30
        burst.particleLifetime = 0.5
        burst.particleSpeed = 150
        burst.particleSpeedRange = 100
        burst.particleAlpha = 1.0
        burst.particleAlphaSpeed = -2.0
        burst.particleScale = 0.3
        burst.particleColor = .white
        burst.position = ball.position
        burst.particleBirthRate = 100
        addChild(burst)

        ball.removeFromParent()

        // Notify after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.onDeath?(finalScore, self?.timeAlive ?? 0)
        }
    }
}
