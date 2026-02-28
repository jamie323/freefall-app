import SpriteKit

extension GameScene: SKPhysicsContactDelegate {
    func setupPhysicsContactDelegate() {
        physicsWorld.contactDelegate = self
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let bodyA = contact.bodyA
        let bodyB = contact.bodyB

        guard sceneState == .playing else { return }

        if (bodyA.categoryBitMask == PhysicsCategory.sphere && bodyB.categoryBitMask == PhysicsCategory.obstacle) ||
           (bodyA.categoryBitMask == PhysicsCategory.obstacle && bodyB.categoryBitMask == PhysicsCategory.sphere) {
            handleSphereObstacleCollision()
        }

        if (bodyA.categoryBitMask == PhysicsCategory.sphere && bodyB.categoryBitMask == PhysicsCategory.goal) ||
           (bodyA.categoryBitMask == PhysicsCategory.goal && bodyB.categoryBitMask == PhysicsCategory.sphere) {
            handleSphereGoalCollision()
        }
    }

    override func update(_ currentTime: TimeInterval) {
        checkSphereOutOfBounds(currentTime: currentTime)
        updateBackgroundParallax(currentTime: currentTime)
    }

    private func handleSphereObstacleCollision() {
        enterDeadState()
    }

    private func handleSphereGoalCollision() {
        enterCompleteState()
    }

    private func checkSphereOutOfBounds(currentTime: TimeInterval) {
        guard sceneState == .playing,
              let sphere = sphereNode else { return }

        let buffer: CGFloat = Constants.sphereDiameter
        if sphere.position.x < -buffer ||
           sphere.position.x > size.width + buffer ||
           sphere.position.y < -buffer ||
           sphere.position.y > size.height + buffer {
            enterDeadState()
        }
    }

    private func enterDeadState() {
        guard sceneState == .playing else { return }
        sceneState = .dead
        stopSphereMotion()
        
        let delayAction = SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            SKAction.run { [weak self] in
                self?.resetScene()
            }
        ])
        run(delayAction)
    }

    private func enterCompleteState() {
        guard sceneState == .playing else { return }
        sceneState = .complete
        stopSphereMotion()
        
        if let sphere = sphereNode {
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            sphere.run(fadeOut)
        }
        
        let delayAction = SKAction.sequence([
            SKAction.wait(forDuration: 0.8),
            SKAction.run { [weak self] in
                self?.levelCompleted?()
            }
        ])
        run(delayAction)
    }

    var levelCompleted: (() -> Void)?
}
