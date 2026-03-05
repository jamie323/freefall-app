import SpriteKit
import UIKit
import SwiftUI

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
        static let gravityMagnitude: CGFloat = 60
        static let maxVerticalVelocity: CGFloat = 160
        static let flipImpulse: CGFloat = 40
        static let linearDamping: CGFloat = 0.0
        static let verticalDamping: CGFloat = 0.015
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
        static let deathResetDelay: TimeInterval = 0.55
        static let deathResetActionKey = "deathReset"
        // Trail distance scoring
        static let trailScorePerUnit: CGFloat = 0.08     // points per SpriteKit unit travelled
        static let trailScorePopupThreshold: Int = 10    // show popup every N trail points earned
    }

    let gameState: GameState
    weak var audioManager: AudioManager?

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
    var onSizeReady: (() -> Void)?

    // Exposed for GameView to read after completion
    var lastCompletionWord: String = "CLEAN"
    var lastSpeedBonus: Int = 0
    var lastIsNewBest: Bool = false

    // Combo system
    var collectibleComboCount: Int = 0
    var comboMultiplier: CGFloat { min(3.0, 1.0 + CGFloat(max(0, collectibleComboCount - 1)) * 0.5) }

    // Close call system
    private let closeCallThreshold: CGFloat = 20
    private let closeCallMinDistance: CGFloat = 3
    private var closeCallTriggeredObstacles: Set<String> = []
    private let closeCallPoints: Int = 25

    // Tap to start
    private var tapToStartLabel: SKLabelNode?

    var sphereNode: SKSpriteNode?
    var backgroundNode: SKSpriteNode?
    private var backgroundHomePosition: CGPoint = .zero
    private let backgroundReturnActionKey = "backgroundReturnAction"
    private var obstacleNodes: [ObstacleNode] = []
    var goalNode: SKShapeNode?
    private var trailNode: TrailNode?
    private var trailSprayNode: TrailSprayNode?
    var collectibleNodes: [CollectibleNode] = []
    var collectiblesCollectedThisAttempt: Int = 0
    private var scoreLabel: SKLabelNode?
    private let scoreLabelPulseKey = "scoreLabelPulse"
    private var lastDisplayedScore: Int = 0
    var levelStartTime: TimeInterval?
    private var hasAppliedCompletionScore = false

    private var isGravityDown: Bool = true
    private var launchVelocity: CGVector = CGVector(dx: 150, dy: 0)
    private lazy var hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var lastUpdateTimestamp: TimeInterval = 0
    var totalFlipsDuringLevel: Int = 0

    // Trail distance scoring
    private var lastSpherePosition: CGPoint = .zero
    private var trailScoreAccumulator: CGFloat = 0
    private var trailPointsBuffer: Int = 0  // accumulated trail points waiting to be shown

    private var beatTimer: Timer?
    private var beatInterval: TimeInterval = 0

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
        setupScoreLabelIfNeeded()
        updateScoreLabel(animated: false)
    }

    func loadLevel(_ level: LevelDefinition, world: WorldDefinition) {
        levelDefinition = level
        worldDefinition = world
        gameState.currentWorldId = world.id
        gameState.currentLevelId = level.levelId
        levelStartTime = nil
        hasAppliedCompletionScore = false
        collectiblesCollectedThisAttempt = 0
        gameState.resetCurrentLevelScore()
        lastDisplayedScore = 0
        setupScoreLabelIfNeeded()
        updateScoreLabel(animated: false)
        createBackgroundIfNeeded()
        updateBackgroundTexture(for: world)
        configureForCurrentLevelIfPossible()

        // Start beat timer
        let bpm = level.levelId <= 5 ? world.bpmA : world.bpmB
        startBeatTimer(bpm: bpm)
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        hapticGenerator.prepare()
        configureForCurrentLevelIfPossible()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, size.height > 0 else { return }
        updateBackgroundLayout()
        layoutScoreLabel()
        // Notify coordinator that scene now has a real size — triggers pending level load
        if oldSize.width == 0 || oldSize.height == 0 {
            onSizeReady?()
        }
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        clampSphereVelocity()
        updateBackgroundParallax(currentTime: currentTime)
        updateTrail()
        updateTrailScore()
        checkNearMisses()
        checkSphereOutOfBounds()
    }

    private func updateTrailScore() {
        guard sceneState == .playing, let sphere = sphereNode else { return }
        let pos = sphere.position
        guard lastSpherePosition != .zero else {
            lastSpherePosition = pos
            return
        }
        let dx = pos.x - lastSpherePosition.x
        let dy = pos.y - lastSpherePosition.y
        let dist = sqrt(dx * dx + dy * dy)
        lastSpherePosition = pos

        trailScoreAccumulator += dist * Constants.trailScorePerUnit
        let earned = Int(trailScoreAccumulator)
        if earned > 0 {
            trailScoreAccumulator -= CGFloat(earned)
            trailPointsBuffer += earned
            gameState.addScore(earned)
            updateScoreLabel(animated: true)

            // Show popup every threshold points
            if trailPointsBuffer >= Constants.trailScorePopupThreshold {
                spawnScorePopup("+\(trailPointsBuffer)", at: pos, color: UIColor(worldDefinition?.primaryColor ?? .cyan))
                trailPointsBuffer = 0
            }
        }
    }

    private func clampSphereVelocity() {
        guard let body = sphereNode?.physicsBody, sceneState == .playing else { return }
        let physics = worldDefinition?.physicsConfig
        let dx = body.velocity.dx
        var dy = body.velocity.dy

        // Vertical-only damping — horizontal momentum is preserved fully
        let damping = physics?.verticalDamping ?? Constants.verticalDamping
        dy *= (1.0 - damping)

        // Hard cap on vertical speed
        let maxDY = physics?.maxVerticalVelocity ?? Constants.maxVerticalVelocity
        dy = min(max(dy, -maxDY), maxDY)

        body.velocity = CGVector(dx: dx, dy: dy)
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

    /// Public entry point for tap — called by SwiftUI gesture via SpriteKitView.Coordinator
    func handleTap() {
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
        gameState.resetCurrentLevelScore()
        collectiblesCollectedThisAttempt = 0
        collectibleComboCount = 0
        closeCallTriggeredObstacles.removeAll()
        lastDisplayedScore = 0
        trailScoreAccumulator = 0
        trailPointsBuffer = 0
        lastSpherePosition = .zero
        updateScoreLabel(animated: false)
        levelStartTime = CACurrentMediaTime()
        hasAppliedCompletionScore = false
        sceneState = .playing
        totalFlipsDuringLevel = 0
        sphere.physicsBody?.isDynamic = true
        stopSphereMotion()
        sphere.physicsBody?.velocity = launchVelocity
        createTrail()
        hideTapToStart()
        audioManager?.playSFX("level-start")
    }

    private(set) var flipCount: Int = 0

    private func flipGravity() {
        guard sceneState == .playing, let body = sphereNode?.physicsBody else { return }
        isGravityDown.toggle()
        totalFlipsDuringLevel += 1
        flipCount += 1
        applyGravityDirection()
        let physics = worldDefinition?.physicsConfig
        // Pendulum feel: carry 30% of existing vertical velocity into the new direction,
        // then add a small impulse. Gives swing/arc rather than dead stop + restart.
        let carry = -body.velocity.dy * 0.3   // reverse 30% of current dy
        let flipImpulse = physics?.flipImpulse ?? Constants.flipImpulse
        let impulse = isGravityDown ? -flipImpulse : flipImpulse
        body.velocity = CGVector(dx: body.velocity.dx, dy: carry + impulse)
        triggerHapticIfNeeded()
        audioManager?.playSFX("flip")
    }

    private func applyGravityDirection() {
        let gravity = worldDefinition?.physicsConfig.gravityMagnitude ?? Constants.gravityMagnitude
        let dy = isGravityDown ? -gravity : gravity
        physicsWorld.gravity = CGVector(dx: 0, dy: dy)
    }

    private func createSphereIfNeeded() {
        // If the sphere was removed from parent (e.g. completion animation), clear and recreate
        if let existing = sphereNode, existing.parent == nil {
            sphereNode = nil
        }
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
        physicsBody.linearDamping = Constants.linearDamping
        physicsBody.allowsRotation = false
        physicsBody.affectedByGravity = true
        physicsBody.isDynamic = false
        physicsBody.usesPreciseCollisionDetection = true
        physicsBody.categoryBitMask = PhysicsCategory.sphere
        physicsBody.collisionBitMask = PhysicsCategory.obstacle | PhysicsCategory.boundary
        physicsBody.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.goal | PhysicsCategory.boundary | PhysicsCategory.collectible
        node.physicsBody = physicsBody

        addChild(node)
        sphereNode = node
    }

    private func createBackgroundIfNeeded() {
        guard backgroundNode == nil else { return }
        let bgSize = CGSize(
            width: max(size.width, 1) * Constants.backgroundScale,
            height: max(size.height, 1) * Constants.backgroundScale
        )
        let node = SKSpriteNode(color: Constants.placeholderBackground, size: bgSize)
        node.zPosition = -10
        node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        node.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(node)
        backgroundNode = node
        backgroundHomePosition = node.position
    }

    private func updateBackgroundTexture(for world: WorldDefinition) {
        guard let background = backgroundNode else { return }
        if let uiImage = UIImage(named: world.backgroundImageName) {
            let texture = SKTexture(image: uiImage)
            background.texture = texture
            background.color = .clear
            background.colorBlendFactor = 0
        }
        // If image not found, keep the solid colour placeholder
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

    private func setupScoreLabelIfNeeded() {
        guard scoreLabel == nil else { return }
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 24
        label.fontColor = .white
        label.alpha = 0.95
        label.horizontalAlignmentMode = .right
        label.verticalAlignmentMode = .top
        label.zPosition = 50
        label.text = "0"
        scoreLabel = label
        addChild(label)
        layoutScoreLabel()
    }

    private func layoutScoreLabel() {
        guard let label = scoreLabel else { return }
        let padding: CGFloat = 16
        // Position below the pause button area
        label.position = CGPoint(x: size.width - padding, y: size.height - 52)
    }

    func updateScoreLabel(animated: Bool) {
        setupScoreLabelIfNeeded()
        guard let label = scoreLabel else { return }
        let newScore = gameState.currentLevelScore
        label.text = "\(newScore)"
        if animated && newScore > lastDisplayedScore {
            label.removeAction(forKey: scoreLabelPulseKey)
            let scaleUp = SKAction.scale(to: 1.3, duration: 0.08)
            scaleUp.timingMode = .easeOut
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.12)
            scaleDown.timingMode = .easeIn
            let sequence = SKAction.sequence([scaleUp, scaleDown])
            label.run(sequence, withKey: scoreLabelPulseKey)
        }
        lastDisplayedScore = newScore
    }

    /// Spawns a floating score text at the given scene position
    func spawnScorePopup(_ text: String, at position: CGPoint, color: UIColor) {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 18
        label.fontColor = color
        label.alpha = 1.0
        label.zPosition = 60
        label.blendMode = .add
        label.position = position
        addChild(label)

        let rise = SKAction.moveBy(x: CGFloat.random(in: -12...12), y: 48, duration: 0.7)
        rise.timingMode = .easeOut
        let scaleDown = SKAction.scale(to: 0.5, duration: 0.7)
        let fade = SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            SKAction.fadeOut(withDuration: 0.4)
        ])
        label.run(SKAction.group([rise, fade, scaleDown])) {
            label.removeFromParent()
        }
    }

    func applyCompletionScoreIfNeeded() {
        guard !hasAppliedCompletionScore else { return }
        hasAppliedCompletionScore = true
        guard let levelDefinition else { return }
        let parTime = max(levelDefinition.parTime, 0.1)
        let elapsed = levelStartTime.map { CACurrentMediaTime() - $0 } ?? parTime
        let ratio = max(0, min(1, (parTime - elapsed) / parTime))
        let speedBonus = max(0, Int(ratio * 300))
        let totalPoints = 200 + speedBonus
        if totalPoints > 0 {
            gameState.addScore(totalPoints)
            updateScoreLabel(animated: true)
        }
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
        clearCollectibles()

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
        if let worldDefinition {
            createCollectibles(from: levelDefinition, world: worldDefinition)
        }
        enterReadyState(shouldReposition: false, animateBackgroundReset: false)
    }

    func enterReadyState(shouldReposition: Bool, animateBackgroundReset: Bool) {
        sceneState = .ready
        lastUpdateTimestamp = 0
        levelStartTime = nil
        sphereNode?.physicsBody?.isDynamic = false
        sphereNode?.alpha = 1
        stopSphereMotion()
        collectibleComboCount = 0
        closeCallTriggeredObstacles.removeAll()
        if shouldReposition {
            gameState.resetCurrentLevelScore()
            collectiblesCollectedThisAttempt = 0
            lastDisplayedScore = 0
            updateScoreLabel(animated: false)
            repositionSphereToLaunchPoint()
            if let definition = levelDefinition, let world = worldDefinition {
                createCollectibles(from: definition, world: world)
            } else {
                clearCollectibles()
            }
            hasAppliedCompletionScore = false
        }
        resetGravityToInitialDirection()
        backgroundNode?.isPaused = false
        resetBackgroundPosition(animated: animateBackgroundReset)
        showTapToStart()
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
        let worldColor = UIColor(worldDefinition?.primaryColor ?? Color(red: 0, green: 0.831, blue: 1))
        for (index, obstacle) in definition.obstacles.enumerated() {
            let node = ObstacleNode(obstacle: obstacle, normalizedToScreenSize: size)
            node.zPosition = 5
            node.name = obstacle.identifier ?? "obs-\(index)"
            node.applyWorldColor(worldColor)
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

    private func createCollectibles(from definition: LevelDefinition, world: WorldDefinition) {
        clearCollectibles()
        guard let collectibles = definition.collectibles, !collectibles.isEmpty else { return }
        let worldColor = UIColor(worldDefinition?.primaryColor ?? Color(red: 0, green: 0.831, blue: 1))
        for collectible in collectibles {
            let position = CGPoint(x: collectible.position.x * size.width, y: collectible.position.y * size.height)
            let node = CollectibleNode(position: position, worldColor: worldColor, id: collectible.id)
            addChild(node)
            collectibleNodes.append(node)
        }
    }

    private func clearCollectibles() {
        for node in collectibleNodes {
            node.removeFromParent()
        }
        collectibleNodes.removeAll()
    }

    private func createTrail() {
        trailNode?.removeFromParent()
        trailSprayNode?.removeFromParent()
        
        guard let sphere = sphereNode else { return }
        
        let trailStart = worldDefinition.map { UIColor($0.trailStartColor) } ?? UIColor(red: 0, green: 0.831, blue: 1, alpha: 1)
        let trailEnd = worldDefinition.map { UIColor($0.trailEndColor) } ?? UIColor(red: 1, green: 0.078, blue: 0.576, alpha: 1)

        let trail = TrailNode(
            startPosition: sphere.position,
            startColor: trailStart,
            endColor: trailEnd,
            estimatedLevelLength: size.width
        )
        addChild(trail)
        trailNode = trail

        let spray = TrailSprayNode(color: trailStart)
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

    // MARK: - Beat-Reactive Effects
    
    private func startBeatTimer(bpm: Double) {
        beatTimer?.invalidate()
        beatInterval = 60.0 / bpm
        beatTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { [weak self] _ in
            self?.onBeat()
        }
    }
    
    private func onBeat() {
        guard sceneState == .playing else { return }

        // Background brightness pulse (stronger)
        if let background = backgroundNode {
            let originalAlpha = background.alpha
            background.run(SKAction.sequence([
                SKAction.fadeAlpha(to: originalAlpha + 0.15, duration: 0.04),
                SKAction.fadeAlpha(to: originalAlpha, duration: 0.12)
            ]))
        }

        // Sphere glow pulse on beat
        if let sphere = sphereNode {
            let worldColor = UIColor(worldDefinition?.primaryColor ?? .cyan)
            sphere.run(SKAction.sequence([
                SKAction.colorize(with: worldColor, colorBlendFactor: 0.8, duration: 0.04),
                SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.12)
            ]))
        }

        // Obstacle glow pulse — smooth alpha fade (gradual, not flashing)
        for obstacle in obstacleNodes {
            obstacle.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 1.0, duration: 0.08),
                SKAction.fadeAlpha(to: 0.7, duration: 0.3)
            ]))
        }
    }
    
    func stopBeatTimer() {
        beatTimer?.invalidate()
        beatTimer = nil
    }
    
    // MARK: - Tap to Start

    private func showTapToStart() {
        hideTapToStart()
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = "TAP"
        label.fontSize = 16
        label.fontColor = UIColor(worldDefinition?.primaryColor ?? .cyan)
        label.alpha = 0.6
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.12)
        label.zPosition = 50
        addChild(label)
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.25, duration: 0.8),
            SKAction.fadeAlpha(to: 0.6, duration: 0.8)
        ])
        label.run(SKAction.repeatForever(pulse))
        tapToStartLabel = label
    }

    private func hideTapToStart() {
        tapToStartLabel?.removeFromParent()
        tapToStartLabel = nil
    }

    // MARK: - Close Call / Near-Miss

    private func checkNearMisses() {
        guard sceneState == .playing, let sphere = sphereNode else { return }
        let spherePos = sphere.position
        let sphereRadius = Constants.sphereDiameter / 2

        for obstacleNode in obstacleNodes {
            guard let obstacleId = obstacleNode.name,
                  !closeCallTriggeredObstacles.contains(obstacleId) else { continue }

            let obstacleFrame = obstacleNode.calculateAccumulatedFrame()
            let closestPoint = closestPointOnRect(obstacleFrame, to: spherePos)
            let distance = hypot(spherePos.x - closestPoint.x, spherePos.y - closestPoint.y) - sphereRadius

            if distance > closeCallMinDistance && distance < closeCallThreshold {
                closeCallTriggeredObstacles.insert(obstacleId)
                triggerCloseCall(at: spherePos, obstaclePosition: closestPoint)
            }
        }
    }

    private func closestPointOnRect(_ rect: CGRect, to point: CGPoint) -> CGPoint {
        let x = min(max(point.x, rect.minX), rect.maxX)
        let y = min(max(point.y, rect.minY), rect.maxY)
        return CGPoint(x: x, y: y)
    }

    private func triggerCloseCall(at spherePos: CGPoint, obstaclePosition: CGPoint) {
        gameState.addScore(closeCallPoints)
        updateScoreLabel(animated: true)
        spawnScorePopup("CLOSE! +\(closeCallPoints)", at: spherePos, color: .yellow)

        // Spark particles
        let midpoint = CGPoint(
            x: (spherePos.x + obstaclePosition.x) / 2,
            y: (spherePos.y + obstaclePosition.y) / 2
        )
        spawnCloseCallSparks(at: midpoint)

        // Sphere flash
        sphereNode?.run(SKAction.sequence([
            SKAction.colorize(with: .yellow, colorBlendFactor: 1.0, duration: 0.05),
            SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.15)
        ]))

        // Haptic + SFX
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.4)
        }
        audioManager?.playSFX("close-call")
    }

    private func spawnCloseCallSparks(at position: CGPoint) {
        for _ in 0..<6 {
            let spark = SKSpriteNode(color: .yellow, size: CGSize(width: 2, height: 2))
            spark.position = position
            spark.zPosition = 20
            spark.blendMode = .add
            addChild(spark)
            let angle = CGFloat.random(in: 0..<(2 * .pi))
            let speed = CGFloat.random(in: 40...100)
            let dur = TimeInterval.random(in: 0.15...0.3)
            spark.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: cos(angle) * speed * CGFloat(dur), y: sin(angle) * speed * CGFloat(dur), duration: dur),
                    SKAction.fadeOut(withDuration: dur)
                ]),
                .removeFromParent()
            ]))
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
