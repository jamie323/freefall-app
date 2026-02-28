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
        sphereNode?.physicsBody?.isDynamic = false
        stopSphereMotion()

        createDeathParticleBurst()
        fadeOutTrailNodes()
        resetBackgroundPosition(animated: true)
        scheduleDeathReset()
    }

    private func createDeathParticleBurst() {
        guard let sphere = sphereNode else { return }

        for _ in 0..<Constants.deathParticleCount {
            let radius = CGFloat.random(in: Constants.deathParticleRadiusRange)
            let diameter = radius * 2
            let texture = GameScene.makeSphereTexture(diameter: diameter)
            let particle = SKSpriteNode(texture: texture)
            particle.size = CGSize(width: diameter, height: diameter)
            particle.color = Constants.deathParticleColor
            particle.colorBlendFactor = 1
            particle.blendMode = .add
            particle.position = sphere.position
            particle.zPosition = 15
            addChild(particle)

            let angle = CGFloat.random(in: 0..<(2 * .pi))
            let speed = CGFloat.random(in: Constants.deathParticleSpeedRange)
            let duration = TimeInterval.random(in: Constants.deathParticleDurationRange)
            let dx = cos(angle) * speed * CGFloat(duration)
            let dy = sin(angle) * speed * CGFloat(duration)

            let moveAction = SKAction.moveBy(x: dx, y: dy, duration: duration)
            let fadeAction = SKAction.fadeOut(withDuration: duration)
            let group = SKAction.group([moveAction, fadeAction])
            particle.run(SKAction.sequence([group, .removeFromParent()]))
        }
    }

    private func fadeOutTrailNodes() {
        clearTrail()
    }

    private func scheduleDeathReset() {
        removeAction(forKey: Constants.deathResetActionKey)
        let wait = SKAction.wait(forDuration: Constants.deathResetDelay)
        let reset = SKAction.run { [weak self] in
            self?.completeDeathReset()
        }
        run(SKAction.sequence([wait, reset]), withKey: Constants.deathResetActionKey)
    }

    private func completeDeathReset() {
        enterReadyState(shouldReposition: true, animateBackgroundReset: false)
    }

    private func enterCompleteState() {
        guard sceneState == .playing else { return }
        sceneState = .complete
        stopSphereMotion()
        
        if let goal = goalNode {
            goal.removeAction(forKey: Constants.goalPulseActionKey)
            performGoalFlash(goal: goal)
        }
        
        createGoalCelebrationBurst()
        
        if let sphere = sphereNode {
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            sphere.run(fadeOut)
        }
        
        pauseBackgroundMovement()
        
        let delayAction = SKAction.sequence([
            SKAction.wait(forDuration: 0.8),
            SKAction.run { [weak self] in
                self?.emitLevelCompleteMessage()
                self?.levelCompleted?()
            }
        ])
        run(delayAction)
    }

    private func pauseBackgroundMovement() {
        backgroundNode?.isPaused = true
    }

    private func performGoalFlash(goal: SKShapeNode) {
        let originalColor = goal.strokeColor
        let white = SKAction.run { goal.strokeColor = .white }
        let wait1 = SKAction.wait(forDuration: 0.1)
        let back = SKAction.run { goal.strokeColor = originalColor }
        let wait2 = SKAction.wait(forDuration: 0.2)
        let sequence = SKAction.sequence([white, wait1, back, wait2])
        goal.run(sequence)
    }

    private func emitLevelCompleteMessage() {
        guard let definition = levelDefinition else { return }
        
        let flipCount = totalFlipsDuringLevel
        let parFlips = definition.parFlips
        var word: String
        
        let roll = Double.random(in: 0...1)
        if flipCount <= parFlips {
            word = roll < 0.75 ? "CLEAN" : "FRESH"
        } else {
            if roll < 0.40 {
                word = "CLEAN"
            } else if roll < 0.65 {
                word = "FRESH"
            } else if roll < 0.85 {
                word = "DOPE"
            } else {
                word = "NICE"
            }
        }
        
        print("LEVEL COMPLETE - flips: \(flipCount), word: \(word)")
    }

    private func createGoalCelebrationBurst() {
        guard let goalNode = goalNode else { return }
        
        for _ in 0..<20 {
            let angle = CGFloat.random(in: 0..<(2 * .pi))
            let speed = CGFloat.random(in: 100...250)
            let duration: TimeInterval = 0.6
            let dx = cos(angle) * speed * CGFloat(duration)
            let dy = sin(angle) * speed * CGFloat(duration)
            
            let particle = SKSpriteNode(color: UIColor(red: 0, green: 1, blue: 1, alpha: 1), size: CGSize(width: 3, height: 3))
            particle.position = goalNode.position
            particle.zPosition = 15
            addChild(particle)
            
            let moveAction = SKAction.moveBy(x: dx, y: dy, duration: duration)
            let fadeAction = SKAction.fadeOut(withDuration: duration)
            let group = SKAction.group([moveAction, fadeAction])
            particle.run(SKAction.sequence([group, .removeFromParent()]))
        }
    }

    var levelCompleted: (() -> Void)?
}
