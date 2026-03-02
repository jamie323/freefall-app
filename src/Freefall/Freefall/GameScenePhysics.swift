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

        if (bodyA.categoryBitMask == PhysicsCategory.sphere && bodyB.categoryBitMask == PhysicsCategory.collectible) ||
           (bodyA.categoryBitMask == PhysicsCategory.collectible && bodyB.categoryBitMask == PhysicsCategory.sphere) {
            let collectibleBody = bodyA.categoryBitMask == PhysicsCategory.collectible ? bodyA : bodyB
            handleCollectibleContact(with: collectibleBody)
        }
    }

    private func handleSphereObstacleCollision() {
        enterDeadState()
    }

    private func handleSphereGoalCollision() {
        enterCompleteState()
    }

    private func handleCollectibleContact(with collectibleBody: SKPhysicsBody) {
        guard let node = collectibleBody.node as? CollectibleNode else {
            collectibleBody.node?.removeFromParent()
            return
        }
        // Disable physics immediately
        collectibleBody.categoryBitMask = 0
        collectibleBody.contactTestBitMask = 0
        collectibleBody.collisionBitMask = 0
        node.physicsBody = nil
        node.removeAllActions()

        let collectPos = node.position
        let worldColor = UIColor(worldDefinition?.primaryColor ?? .cyan)

        // Burst: 10 particles in world colour
        spawnCollectBurst(at: collectPos, color: worldColor)

        // Ring flash: quick expanding ring
        let ring = SKShapeNode(circleOfRadius: 8)
        ring.position = collectPos
        ring.strokeColor = worldColor
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.zPosition = 20
        ring.blendMode = .add
        addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 3.5, duration: 0.25),
                SKAction.fadeOut(withDuration: 0.25)
            ]),
            .removeFromParent()
        ]))

        // Remove collectible
        let pop = SKAction.group([
            SKAction.scale(to: 2.0, duration: 0.08),
            SKAction.fadeOut(withDuration: 0.08)
        ])
        node.run(SKAction.sequence([pop, .removeFromParent()]))
        collectibleNodes.removeAll { $0 === node }

        collectiblesCollectedThisAttempt += 1
        gameState.addScore(50)
        updateScoreLabel(animated: true)

        // Haptic ping
        if hapticsEnabled {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred(intensity: 0.5)
        }
    }

    private func spawnCollectBurst(at position: CGPoint, color: UIColor) {
        for _ in 0..<10 {
            let size: CGFloat = CGFloat.random(in: 2...5)
            let particle = SKSpriteNode(color: color, size: CGSize(width: size, height: size))
            particle.position = position
            particle.zPosition = 18
            particle.blendMode = .add
            addChild(particle)

            let angle = CGFloat.random(in: 0..<(2 * .pi))
            let speed = CGFloat.random(in: 60...140)
            let dur = TimeInterval.random(in: 0.25...0.45)
            let dx = cos(angle) * speed * CGFloat(dur)
            let dy = sin(angle) * speed * CGFloat(dur)

            particle.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: dur),
                    SKAction.fadeOut(withDuration: dur)
                ]),
                .removeFromParent()
            ]))
        }
    }

    func enterDeadState() {
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

    func enterCompleteState() {
        guard sceneState == .playing else { return }
        sceneState = .complete
        applyCompletionScoreIfNeeded()
        stopSphereMotion()
        stopBeatTimer()

        // Heavy haptic
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)

        // Goal flash
        if let goal = goalNode {
            goal.removeAction(forKey: Constants.goalPulseActionKey)
            performGoalFlash(goal: goal)
        }

        // Sphere flash then fade
        if let sphere = sphereNode {
            let worldColor = UIColor(worldDefinition?.primaryColor ?? .cyan)
            sphere.color = worldColor
            sphere.colorBlendFactor = 1
            let flash = SKAction.sequence([
                SKAction.colorize(with: .white, colorBlendFactor: 1, duration: 0.05),
                SKAction.colorize(with: worldColor, colorBlendFactor: 1, duration: 0.1),
                SKAction.fadeOut(withDuration: 0.4)
            ])
            sphere.run(flash)
        }

        // Screen flash overlay
        let flash = SKSpriteNode(color: UIColor(worldDefinition?.primaryColor ?? .cyan).withAlphaComponent(0.4),
                                 size: size)
        flash.position = CGPoint(x: size.width/2, y: size.height/2)
        flash.zPosition = 50
        flash.blendMode = .add
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))

        // Fireworks — 3 waves of bursts
        let goalPos = goalNode?.position ?? CGPoint(x: size.width/2, y: size.height/2)
        createFireworksBurst(at: goalPos, delay: 0.0)
        createFireworksBurst(at: CGPoint(x: goalPos.x - 80, y: goalPos.y + 60), delay: 0.15)
        createFireworksBurst(at: CGPoint(x: goalPos.x + 80, y: goalPos.y - 40), delay: 0.3)
        createFireworksBurst(at: CGPoint(x: size.width * 0.3, y: size.height * 0.4), delay: 0.45)
        createFireworksBurst(at: CGPoint(x: size.width * 0.7, y: size.height * 0.6), delay: 0.6)

        pauseBackgroundMovement()

        // Show complete UI after celebration fires
        let delayAction = SKAction.sequence([
            SKAction.wait(forDuration: 0.9),
            SKAction.run { [weak self] in
                self?.emitLevelCompleteMessage()
                self?.levelCompleted?()
            }
        ])
        run(delayAction)
    }

    private func createFireworksBurst(at position: CGPoint, delay: TimeInterval) {
        let worldColor = UIColor(worldDefinition?.primaryColor ?? .cyan)
        let colors: [UIColor] = [worldColor, .white, worldColor.withAlphaComponent(0.7), .cyan]

        run(SKAction.wait(forDuration: delay)) { [weak self] in
            guard let self else { return }

            // Haptic per burst
            let haptic = UIImpactFeedbackGenerator(style: .medium)
            haptic.impactOccurred(intensity: 0.7)

            // Central flash ring
            let ring = SKShapeNode(circleOfRadius: 6)
            ring.position = position
            ring.strokeColor = worldColor
            ring.fillColor = worldColor.withAlphaComponent(0.3)
            ring.lineWidth = 3
            ring.zPosition = 25
            ring.blendMode = .add
            self.addChild(ring)
            ring.run(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 6.0, duration: 0.4),
                    SKAction.fadeOut(withDuration: 0.4)
                ]),
                .removeFromParent()
            ]))

            // Particle shower — 30 particles per burst
            for i in 0..<30 {
                let color = colors[i % colors.count]
                let size: CGFloat = CGFloat.random(in: 3...7)
                let particle = SKSpriteNode(color: color, size: CGSize(width: size, height: size))
                particle.position = position
                particle.zPosition = 22
                particle.blendMode = .add
                self.addChild(particle)

                let angle = CGFloat(i) * (2 * .pi / 30) + CGFloat.random(in: -0.2...0.2)
                let speed = CGFloat.random(in: 120...320)
                let dur = TimeInterval.random(in: 0.5...0.9)
                let dx = cos(angle) * speed * CGFloat(dur)
                let dy = sin(angle) * speed * CGFloat(dur)

                particle.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: dx, y: dy, duration: dur),
                        SKAction.sequence([
                            SKAction.wait(forDuration: dur * 0.4),
                            SKAction.fadeOut(withDuration: dur * 0.6)
                        ])
                    ]),
                    .removeFromParent()
                ]))
            }
        }
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
        guard let definition = levelDefinition, let world = worldDefinition else { return }
        
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
        
        lastCompletionWord = word
        // Speed bonus: based on time vs par
        if let startTime = levelStartTime, let parTime = levelDefinition?.parTime {
            let elapsed = CACurrentMediaTime() - startTime
            if elapsed < parTime {
                let ratio = max(0, 1.0 - elapsed / parTime)
                lastSpeedBonus = Int(ratio * 300)
            } else {
                lastSpeedBonus = 0
            }
        }
        print("LEVEL COMPLETE - flips: \(flipCount), word: \(word), speedBonus: \(lastSpeedBonus)")

        // Check if should trigger intermission
        if gameState.shouldTriggerIntermission(world: world.id, level: definition.levelId) == true {
            gameState.isIntermissionActive = true
        } else {
            // Mark level as completed
            gameState.markLevelCompleted(world: world.id, level: definition.levelId)
        }
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
}
