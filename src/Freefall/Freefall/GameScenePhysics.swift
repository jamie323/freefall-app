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

    private func handleSphereObstacleCollision() {
        enterDeadState()
    }

    private func handleSphereGoalCollision() {
        enterCompleteState()
    }

    private func enterDeadState() {
        guard sceneState == .playing else { return }
        sceneState = .dead
        stopSphereMotion()
        
        createDeathParticleBurst()
        fadOutTrailNodes()
        
        let delayAction = SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            SKAction.run { [weak self] in
                self?.resetScene()
            }
        ])
        run(delayAction)
    }

    private func createDeathParticleBurst() {
        guard let sphere = sphereNode else { return }
        
        let particleCount = 12
        for _ in 0..<particleCount {
            let angle = CGFloat.random(in: 0..<(2 * .pi))
            let speed = CGFloat.random(in: 100...300)
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed
            
            let particle = SKSpriteNode(color: UIColor(red: 0, green: 0.831, blue: 1, alpha: 1), size: CGSize(width: 4, height: 4))
            particle.position = sphere.position
            particle.zPosition = 15
            addChild(particle)
            
            let moveAction = SKAction.move(by: CGVector(dx: dx * 0.3, dy: dy * 0.3), duration: 0.3)
            let fadeAction = SKAction.fadeOut(withDuration: 0.3)
            let group = SKAction.group([moveAction, fadeAction])
            let sequence = SKAction.sequence([
                group,
                SKAction.run { particle.removeFromParent() }
            ])
            particle.run(sequence)
        }
    }

    private func fadOutTrailNodes() {
        clearTrail()
    }

    private func enterCompleteState() {
        guard sceneState == .playing else { return }
        sceneState = .complete
        stopSphereMotion()
        
        createGoalCelebrationBurst()
        goalFlash()
        
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

    private func createGoalCelebrationBurst() {
        guard let goalNode = goalNode else { return }
        
        let particleCount = 16
        for _ in 0..<particleCount {
            let angle = CGFloat.random(in: 0..<(2 * .pi))
            let speed = CGFloat.random(in: 80...200)
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed
            
            let particle = SKSpriteNode(color: UIColor(red: 0, green: 1, blue: 1, alpha: 1), size: CGSize(width: 3, height: 3))
            particle.position = goalNode.position
            particle.zPosition = 15
            addChild(particle)
            
            let moveAction = SKAction.move(by: CGVector(dx: dx * 0.5, dy: dy * 0.5), duration: 0.5)
            let fadeAction = SKAction.fadeOut(withDuration: 0.5)
            let group = SKAction.group([moveAction, fadeAction])
            let sequence = SKAction.sequence([
                group,
                SKAction.run { particle.removeFromParent() }
            ])
            particle.run(sequence)
        }
    }

    private func goalFlash() {
        guard let goalNode = goalNode else { return }
        let originalColor = goalNode.strokeColor
        let flashSequence = SKAction.sequence([
            SKAction.run { goalNode.strokeColor = .white },
            SKAction.wait(forDuration: 0.2),
            SKAction.run { goalNode.strokeColor = originalColor }
        ])
        goalNode.run(flashSequence)
    }

    var levelCompleted: (() -> Void)?
}
