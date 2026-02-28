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

    private enum Constants {
        static let sphereDiameter: CGFloat = 28
        static let gravityMagnitude: CGFloat = 500
        static let backgroundScale: CGFloat = 1.2
        static let parallaxMultiplier: CGFloat = 0.2
        static let backgroundResetDuration: TimeInterval = 0.3
        static let placeholderBackground = UIColor(red: 0.039, green: 0.039, blue: 0.118, alpha: 1)
    }

    var hapticsEnabled: Bool = true

    var levelDefinition: LevelDefinition? {
        didSet {
            configureForCurrentLevelIfPossible()
        }
    }

    private(set) var sceneState: SceneState = .ready {
        didSet {
            if sceneState != oldValue {
                stateDidChange?(sceneState)
            }
        }
    }

    var stateDidChange: ((SceneState) -> Void)?

    private var sphereNode: SKSpriteNode?
    private var backgroundNode: SKSpriteNode?
    private var backgroundHomePosition: CGPoint = .zero
    private let backgroundReturnActionKey = "backgroundReturnAction"

    private var isGravityDown: Bool = true
    private var launchVelocity: CGVector = CGVector(dx: 150, dy: 0)
    private lazy var hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var lastUpdateTimestamp: TimeInterval = 0

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .black
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func sceneDidLoad() {
        super.sceneDidLoad()
        physicsWorld.gravity = CGVector(dx: 0, dy: -Constants.gravityMagnitude)
        createBackgroundIfNeeded()
        createSphereIfNeeded()
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

    private func beginPlaying() {
        guard let sphere = sphereNode else { return }
        sceneState = .playing
        sphere.physicsBody?.isDynamic = true
        stopSphereMotion()
        sphere.physicsBody?.velocity = launchVelocity
    }

    private func flipGravity() {
        guard sceneState == .playing else { return }
        isGravityDown.toggle()
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

    private func resetBackgroundPosition(animated: Bool) {
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

        guard let levelDefinition else {
            enterReadyState(shouldReposition: true, animateBackgroundReset: false)
            return
        }

        launchVelocity = levelDefinition.launchVelocity
        isGravityDown = levelDefinition.initialGravityDown
        applyGravityDirection()
        positionSphere(atNormalizedPoint: levelDefinition.launchPosition)
        enterReadyState(shouldReposition: false, animateBackgroundReset: false)
    }

    private func enterReadyState(shouldReposition: Bool, animateBackgroundReset: Bool) {
        sceneState = .ready
        lastUpdateTimestamp = 0
        sphereNode?.physicsBody?.isDynamic = false
        stopSphereMotion()
        if shouldReposition {
            positionSphere(at: CGPoint(x: size.width * 0.2, y: size.height * 0.5))
        }
        resetBackgroundPosition(animated: animateBackgroundReset)
    }

    private func stopSphereMotion() {
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

    private func triggerHapticIfNeeded() {
        guard hapticsEnabled else { return }
        hapticGenerator.impactOccurred(intensity: 0.8)
        hapticGenerator.prepare()
    }

    private static func makeSphereTexture(diameter: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.addEllipse(in: CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter)))
            context.cgContext.fillPath()
        }
        return SKTexture(image: image)
    }
}
