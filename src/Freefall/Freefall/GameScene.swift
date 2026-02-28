import SpriteKit
import UIKit

final class GameScene: SKScene {
    enum SceneState: String {
        case ready
        case playing
        case dead
        case complete
        case paused
    }

    enum Constants {
        static let sphereDiameter: CGFloat = 28
        static let gravityMagnitude: CGFloat = 500
        static let backgroundScale: CGFloat = 1.2
        static let parallaxMultiplier: CGFloat = 0.2
        static let backgroundResetDuration: TimeInterval = 0.3
        static let placeholderBackground = UIColor(red: 0.039, green: 0.039, blue: 0.118, alpha: 1)
        static let goalStrokeColor = UIColor(red: 0, green: 1, blue: 1, alpha: 1)
        static let goalPulseDuration: TimeInterval = 0.8
        static let goalPulseLowAlpha: CGFloat = 0.6
        static let goalPulseHighAlpha: CGFloat = 1.0
        static let goalPulseActionKey = "goalPulse"
        static let sphereOutOfBoundsBuffer: CGFloat = 50
        static let deathParticleCount = 14
        static let deathParticleColor = UIColor(red: 0, green: 0.831, blue: 1, alpha: 1)
        static let deathParticleRadiusRange: ClosedRange<CGFloat> = 3.0...5.0
        static let deathParticleSpeedRange: ClosedRange<CGFloat> = 120.0...220.0
        static let deathParticleDurationRange: ClosedRange<TimeInterval> = 0.3...0.5
        static let deathResetDelay: TimeInterval = 0.35
        static let deathResetActionKey = "deathReset"
    }

    private let gameState: GameState

    var hapticsEnabled: Bool = true

    private(set) var levelDefinition: LevelDefinition?
    private(set) var worldDefinition: WorldDefinition?

    var sceneState: SceneState = .ready {
        didSet {
            if sceneState != oldValue {
                stateDidChange?(sceneState)
                syncGameStateWithSceneState()
            }
        }
    }

    var stateDidChange: ((SceneState) -> Void)?
    var levelCompleted: (() -> Void)?

    var sphereNode: SKSpriteNode?
    var backgroundNode: SKSpriteNode?
    private var backgroundHomePosition: CGPoint = .zero
    private let backgroundReturnActionKey = "backgroundReturnAction"
    private var obstacleNodes: [ObstacleNode] = []
    var goalNode: SKShapeNode?
    private var trailNode: TrailNode?
    private var trailSprayNode: TrailSprayNode?

    private var isGravityDown: Bool = true
    private var launchVelocity: CGVector = CGVector(dx: 150, dy: 0)
    private lazy var hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var lastUpdateTimestamp: TimeInterval = 0
    var totalFlipsDuringLevel: Int = 0

    init(size: CGSize, gameState: GameState) {
        self.gameState = gameState
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .black
        syncGameStateWithSceneState()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sceneDidLoad() {
        super.sceneDidLoad()
        physicsWorld.gravity = CGVector(dx: 0, dy: -Constants.gravityMagnitude)
        setupPhysicsContactDelegate()
        createBackgroundIfNeeded()
        createSphereIfNeeded()
    }

    func loadLevel(_ level: LevelDefinition, world: WorldDefinition) {
        levelDefinition = level
        worldDefinition = world
        gameState.currentWorldId = world.id
        gameState.currentLevelId = level.levelId
        configureForCurrentLevelIfPossible()
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        hapticGenerator.prepare()
        configureForCurrentLevelIfPossible()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateBackgroundLayout()
        configureForCurrentLevelIfPossible()
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        updateBackgroundParallax(currentTime: currentTime)
        updateTrail()
        checkSphereOutOfBounds()
    }

    private func checkSphereOutOfBounds() {
        guard sceneState == .playing,
              let sphere = sphereNode,
              size.width > 0,
              size.height > 0 else { return }

        let buffer = Constants.sphereOutOfBoundsBuffer
        let extendedFrame = CGRect(x: -buffer, y: -buffer, width: size.width + buffer * 2, height: size.height + buffer * 2)
        if !extendedFrame.contains(sphere.position) {
            enterDeadState()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard touches.first != nil else { return }
        handlePrimaryTap()
    }

    func resetScene() {
        stopSphereMotion()
        enterReadyState(shouldReposition: true, animateBackgroundReset: true)
    }

    private func handlePrimaryTap() {
        switch sceneState {
        case .ready:
            beginPlaying()
        case .playing:
            flipGravity()
        default:
            break
        }
    }

    private func syncGameStateWithSceneState() {
        let gameplayState: GameState.GameplayState
        switch sceneState {
        case .ready:
            gameplayState = .ready
        case .playing:
            gameplayState = .playing
        case .dead:
            gameplayState = .dead
        case .complete:
            gameplayState = .complete
        case .paused:
            gameplayState = .paused
        }

        if gameState.gameplayState != gameplayState {
            gameState.gameplayState = gameplayState
        }
    }

    private func beginPlaying() {
        guard let sphere = sphereNode else { return }
        sceneState = .playing
        totalFlipsDuringLevel = 0
        sphere.physicsBody?.isDynamic = true
        stopSphereMotion()
        sphere.physicsBody?.velocity = launchVelocity
        createTrail()
    }

    private func flipGravity() {
        guard sceneState == .playing else { return }
        isGravityDown.toggle()
        totalFlipsDuringLevel += 1
        applyGravityDirection()
        triggerHapticIfNeeded()
    }

    private func applyGravityDirection() {
        let dy = isGravityDown ? -Constants.gravityMagnitude : Constants.gravityMagnitude
        physicsWorld.gravity = CGVector(dx: 0, dy: dy)
    }

    private func createSphereIfNeeded() {
        guard sphereNode == nil else { return }
        let texture = GameScene.makeSphereTexture(diameter: Constants.sphereDiameter)
        let node = SKSpriteNode(texture: texture)
        node.size = CGSize(width: Constants.sphereDiameter, height: Constants.sphereDiameter)
        node.color = .white
        node.colorBlendFactor = 1
        node.blendMode = .add
        node.name = "sphere"
        node.zPosition = 10
        node.position = CGPoint(x: size.width * 0.2, y: size.height * 0.5)

        let physicsBody = SKPhysicsBody(circleOfRadius: Constants.sphereDiameter / 2)
        physicsBody.mass = 1
        physicsBody.restitution = 0
        physicsBody.friction = 0.1
        physicsBody.linearDamping = 0.05
        physicsBody.allowsRotation = false
        physicsBody.affectedByGravity = true
        physicsBody.isDynamic = false
        physicsBody.usesPreciseCollisionDetection = true
        physicsBody.categoryBitMask = PhysicsCategory.sphere
        physicsBody.collisionBitMask = PhysicsCategory.obstacle | PhysicsCategory.boundary
        physicsBody.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.goal | PhysicsCategory.boundary
        node.physicsBody = physicsBody

        addChild(node)
        sphereNode = node
    }

    private func createBackgroundIfNeeded() {
        guard backgroundNode == nil else { return }
        let node = SKSpriteNode(color: Constants.placeholderBackground, size: CGSize(width: size.width * Constants.backgroundScale, height: size.height * Constants.backgroundScale))
        node.zPosition = -10
        node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        node.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(node)
        backgroundNode = node
        backgroundHomePosition = node.position
    }

    private func updateBackgroundLayout() {
        guard let background = backgroundNode, size.width > 0, size.height > 0 else { return }
        background.size = CGSize(width: size.width * Constants.backgroundScale, height: size.height * Constants.backgroundScale)
        backgroundHomePosition = CGPoint(x: size.width / 2, y: size.height / 2)
        if sceneState != .playing {
            background.position = backgroundHomePosition
        }
    }

    private func updateBackgroundParallax(currentTime: TimeInterval) {
        guard sceneState == .playing,
              let background = backgroundNode,
              let velocity = sphereNode?.physicsBody?.velocity else {
            lastUpdateTimestamp = currentTime
            return
        }

        defer { lastUpdateTimestamp = currentTime }

        if lastUpdateTimestamp == 0 {
            return
        }

        let delta = CGFloat(currentTime - lastUpdateTimestamp)
        let dx = -velocity.dx * Constants.parallaxMultiplier * delta
        let dy = -velocity.dy * Constants.parallaxMultiplier * delta

        if background.action(forKey: backgroundReturnActionKey) != nil {
            background.removeAction(forKey: backgroundReturnActionKey)
        }

        let newPosition = CGPoint(x: background.position.x + dx, y: background.position.y + dy)
        background.position = clampBackgroundPosition(newPosition)
    }

    private func clampBackgroundPosition(_ position: CGPoint) -> CGPoint {
        guard let background = backgroundNode else { return position }
        let horizontalLimit = max(0, (background.size.width - size.width) / 2)
        let verticalLimit = max(0, (background.size.height - size.height) / 2)

        let minX = backgroundHomePosition.x - horizontalLimit
        let maxX = backgroundHomePosition.x + horizontalLimit
        let minY = backgroundHomePosition.y - verticalLimit
        let maxY = backgroundHomePosition.y + verticalLimit

        let clampedX = min(max(position.x, minX), maxX)
        let clampedY = min(max(position.y, minY), maxY)
        return CGPoint(x: clampedX, y: clampedY)
    }

    func resetBackgroundPosition(animated: Bool) {
        guard let background = backgroundNode else { return }
        background.removeAction(forKey: backgroundReturnActionKey)
        if animated {
            let move = SKAction.move(to: backgroundHomePosition, duration: Constants.backgroundResetDuration)
            move.timingMode = .easeOut
            background.run(move, withKey: backgroundReturnActionKey)
        } else {
            background.position = backgroundHomePosition
        }
    }

    private func configureForCurrentLevelIfPossible() {
        guard view != nil else { return }
        createBackgroundIfNeeded()
        createSphereIfNeeded()
        updateBackgroundLayout()
        clearObstacles()

        guard let levelDefinition else {
            enterReadyState(shouldReposition: true, animateBackgroundReset: false)
            return
        }

        launchVelocity = levelDefinition.launchVelocity
        isGravityDown = levelDefinition.initialGravityDown
        applyGravityDirection()
        positionSphere(atNormalizedPoint: levelDefinition.launchPosition)
        createObstacles(from: levelDefinition)
        createGoal(from: levelDefinition)
        enterReadyState(shouldReposition: false, animateBackgroundReset: false)
    }

    func enterReadyState(shouldReposition: Bool, animateBackgroundReset: Bool) {
        sceneState = .ready
        lastUpdateTimestamp = 0
        sphereNode?.physicsBody?.isDynamic = false
        sphereNode?.alpha = 1
        stopSphereMotion()
        if shouldReposition {
            repositionSphereToLaunchPoint()
        }
        resetGravityToInitialDirection()
        resetBackgroundPosition(animated: animateBackgroundReset)
    }

    func stopSphereMotion() {
        sphereNode?.physicsBody?.velocity = .zero
        sphereNode?.physicsBody?.angularVelocity = 0
    }

    private func positionSphere(atNormalizedPoint point: CGPoint) {
        guard size.width > 0, size.height > 0 else { return }
        let absolute = CGPoint(x: point.x * size.width, y: point.y * size.height)
        positionSphere(at: absolute)
    }

    private func positionSphere(at point: CGPoint) {
        sphereNode?.position = point
    }

    private func repositionSphereToLaunchPoint() {
        if let definition = levelDefinition {
            positionSphere(atNormalizedPoint: definition.launchPosition)
        } else {
            positionSphere(at: defaultLaunchPoint())
        }
    }

    private func resetGravityToInitialDirection() {
        if let definition = levelDefinition {
            isGravityDown = definition.initialGravityDown
        } else {
            isGravityDown = true
        }
        applyGravityDirection()
    }

    private func defaultLaunchPoint() -> CGPoint {
        CGPoint(x: size.width * 0.2, y: size.height * 0.5)
    }

    private func triggerHapticIfNeeded() {
        guard hapticsEnabled else { return }
        hapticGenerator.impactOccurred(intensity: 0.8)
        hapticGenerator.prepare()
    }

    private func createObstacles(from definition: LevelDefinition) {
        for obstacle in definition.obstacles {
            let node = ObstacleNode(obstacle: obstacle, normalizedToScreenSize: size)
            node.zPosition = 5
            addChild(node)
            obstacleNodes.append(node)
        }
    }

    private func clearObstacles() {
        for node in obstacleNodes {
            node.removeFromParent()
        }
        obstacleNodes.removeAll()
    }

    private func createGoal(from definition: LevelDefinition) {
        goalNode?.removeFromParent()
        
        let circle = SKShapeNode(circleOfRadius: definition.goalRadius)
        circle.position = CGPoint(
            x: definition.goalPosition.x * size.width,
            y: definition.goalPosition.y * size.height
        )
        circle.strokeColor = Constants.goalStrokeColor
        circle.lineWidth = 2
        circle.fillColor = .clear
        circle.alpha = Constants.goalPulseHighAlpha
        circle.zPosition = 6
        
        let physicsBody = SKPhysicsBody(circleOfRadius: definition.goalRadius)
        physicsBody.isDynamic = false
        physicsBody.affectedByGravity = false
        physicsBody.categoryBitMask = PhysicsCategory.goal
        physicsBody.collisionBitMask = 0
        physicsBody.contactTestBitMask = PhysicsCategory.sphere
        circle.physicsBody = physicsBody
        
        let fadeDown = SKAction.fadeAlpha(to: Constants.goalPulseLowAlpha, duration: Constants.goalPulseDuration / 2)
        let fadeUp = SKAction.fadeAlpha(to: Constants.goalPulseHighAlpha, duration: Constants.goalPulseDuration / 2)
        let pulseSequence = SKAction.sequence([fadeDown, fadeUp])
        circle.run(SKAction.repeatForever(pulseSequence), withKey: Constants.goalPulseActionKey)
        
        addChild(circle)
        goalNode = circle
    }

    private func createTrail() {
        trailNode?.removeFromParent()
        trailSprayNode?.removeFromParent()
        
        guard let sphere = sphereNode else { return }
        
        let trail = TrailNode(
            startPosition: sphere.position,
            startColor: UIColor(red: 0, green: 0.831, blue: 1, alpha: 1),
            endColor: UIColor(red: 1, green: 0.078, blue: 0.576, alpha: 1),
            estimatedLevelLength: size.width
        )
        addChild(trail)
        trailNode = trail
        
        let spray = TrailSprayNode(color: UIColor(red: 0, green: 0.831, blue: 1, alpha: 1))
        addChild(spray)
        trailSprayNode = spray
    }

    private func updateTrail() {
        guard sceneState == .playing,
              let trail = trailNode,
              let spray = trailSprayNode,
              let sphere = sphereNode else { return }
        trail.appendPosition(sphere.position)
        spray.spawnScatterAtPosition(sphere.position)
    }

    func clearTrail() {
        let fadeDuration: TimeInterval = 0.3

        if let spray = trailSprayNode {
            spray.fadeOutAndClear(duration: fadeDuration) { [weak spray] in
                spray?.removeFromParent()
            }
            trailSprayNode = nil
        }

        if let trail = trailNode {
            let fadeSequence = SKAction.sequence([
                SKAction.fadeOut(withDuration: fadeDuration),
                SKAction.removeFromParent()
            ])
            trail.run(fadeSequence)
            trailNode = nil
        }
    }

    static func makeSphereTexture(diameter: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.addEllipse(in: CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter)))
            context.cgContext.fillPath()
        }
        return SKTexture(image: image)
    }
}
