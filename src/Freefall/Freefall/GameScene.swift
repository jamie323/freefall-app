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
    private var isGravityDown: Bool = true
    private var launchVelocity: CGVector = CGVector(dx: 150, dy: 0)
    private lazy var hapticGenerator = UIImpactFeedbackGenerator(style: .medium)

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func sceneDidLoad() {
        super.sceneDidLoad()
        physicsWorld.gravity = CGVector(dx: 0, dy: -Constants.gravityMagnitude)
        createSphereIfNeeded()
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        hapticGenerator.prepare()
        configureForCurrentLevelIfPossible()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        configureForCurrentLevelIfPossible()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard touches.first != nil else { return }
        handlePrimaryTap()
    }

    func resetScene() {
        stopSphereMotion()
        enterReadyState(shouldReposition: true)
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

    private func configureForCurrentLevelIfPossible() {
        guard view != nil else { return }
        createSphereIfNeeded()

        guard let levelDefinition else {
            enterReadyState(shouldReposition: true)
            return
        }

        launchVelocity = levelDefinition.launchVelocity
        isGravityDown = levelDefinition.initialGravityDown
        applyGravityDirection()
        positionSphere(atNormalizedPoint: levelDefinition.launchPosition)
        enterReadyState(shouldReposition: false)
    }

    private func enterReadyState(shouldReposition: Bool) {
        sceneState = .ready
        guard let sphere = sphereNode else { return }
        sphere.physicsBody?.isDynamic = false
        stopSphereMotion()
        if shouldReposition {
            positionSphere(at: CGPoint(x: size.width * 0.2, y: size.height * 0.5))
        }
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
