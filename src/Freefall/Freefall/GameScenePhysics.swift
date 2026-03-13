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
        // Auto-collect any collectibles near the goal before completing
        // (fixes bug where collectibles inside the goal ring are impossible to get)
        autoCollectNearGoal()
        enterCompleteState()
    }

    /// Instantly collect any remaining collectibles within the goal radius
    private func autoCollectNearGoal() {
        guard let goal = goalNode, let level = levelDefinition else { return }
        let goalRadius = level.goalRadius + 10  // slight buffer
        let goalPos = goal.position
        for node in collectibleNodes where node.parent != nil && node.physicsBody != nil {
            let dx = node.position.x - goalPos.x
            let dy = node.position.y - goalPos.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < goalRadius {
                // Simulate a collectible contact
                handleCollectibleContact(with: node.physicsBody!)
            }
        }
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

        // Combo system: increment count, compute multiplied score
        collectibleComboCount += 1
        let basePoints = 50
        let points = Int(CGFloat(basePoints) * comboMultiplier)

        // Scale burst particles with combo (10 → 15 → 20)
        let burstCount = min(20, 10 + (collectibleComboCount - 1) * 5)
        spawnCollectBurst(at: collectPos, color: worldColor, count: burstCount)

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
        gameState.addScore(points)
        updateScoreLabel(animated: true)

        // Show combo text when multiplier > 1
        if collectibleComboCount > 1 {
            let comboText = "+\(points) ×\(collectibleComboCount)"
            spawnScorePopup(comboText, at: collectPos, color: worldColor)
        } else {
            spawnScorePopup("+\(points)", at: collectPos, color: worldColor)
        }

        // Check if all collectibles collected — bonus!
        if collectibleNodes.isEmpty && collectiblesCollectedThisAttempt > 1 {
            let bonusPos = CGPoint(x: collectPos.x, y: collectPos.y + 30)
            gameState.addScore(100)
            updateScoreLabel(animated: true)
            spawnScorePopup("ALL COLLECTED +100", at: bonusPos, color: .white)
            playSFX("all-collected")
        }

        // SFX
        playSFX("collectible")

        // Haptic ping
        if hapticsEnabled {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred(intensity: 0.5)
        }
    }

    private func spawnCollectBurst(at position: CGPoint, color: UIColor, count: Int = 10) {
        for _ in 0..<count {
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

        // Record stats
        gameState.recordDeath()

        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

        playSFX("death")

        // Sphere death animation — flash red, scale up, then explode
        if let sphere = sphereNode {
            sphere.run(SKAction.sequence([
                SKAction.group([
                    SKAction.colorize(with: .red, colorBlendFactor: 1.0, duration: 0.06),
                    SKAction.scale(to: 1.5, duration: 0.06)
                ]),
                SKAction.group([
                    SKAction.scale(to: 0.0, duration: 0.12),
                    SKAction.fadeOut(withDuration: 0.12)
                ])
            ]))
        }

        createDeathParticleBurst()
        shakeScreen()
        fadeOutTrailNodes()
        resetBackgroundPosition(animated: true)
        scheduleDeathReset()
    }

    private func shakeScreen() {
        guard let bg = backgroundNode else { return }
        let shakeAmount: CGFloat = 8
        let shakeDuration: TimeInterval = 0.08
        let shake = SKAction.sequence([
            SKAction.moveBy(x: shakeAmount, y: shakeAmount, duration: shakeDuration),
            SKAction.moveBy(x: -shakeAmount * 2, y: -shakeAmount, duration: shakeDuration),
            SKAction.moveBy(x: shakeAmount, y: -shakeAmount, duration: shakeDuration),
            SKAction.move(to: bg.position, duration: shakeDuration)
        ])
        bg.run(shake)
    }

    private func createDeathParticleBurst() {
        guard let sphere = sphereNode else { return }
        let worldColor = UIColor(worldDefinition?.primaryColor ?? .cyan)

        for _ in 0..<Constants.deathParticleCount {
            let radius = CGFloat.random(in: Constants.deathParticleRadiusRange)
            let diameter = radius * 2

            // Use cached texture — avoids UIGraphicsImageRenderer per particle
            let roundedDiameter = ceil(diameter)
            let texture: SKTexture
            if let cached = GameScene.cachedDeathTextures[roundedDiameter] {
                texture = cached
            } else {
                let newTexture = GameScene.makeSphereTexture(diameter: roundedDiameter)
                GameScene.cachedDeathTextures[roundedDiameter] = newTexture
                texture = newTexture
            }

            let particle = SKSpriteNode(texture: texture)
            particle.size = CGSize(width: diameter, height: diameter)
            particle.color = worldColor
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
        stopBeatTimer()
        pauseBackgroundMovement()

        // Disable sphere physics immediately
        sphereNode?.physicsBody?.isDynamic = false

        // Heavy haptic chain — initial slam + aftershock
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
        }

        playSFX("level-complete")

        // Goal: expand ring, then suck ball in
        let goalPos = goalNode?.position ?? CGPoint(x: size.width / 2, y: size.height / 2)
        if let goal = goalNode {
            goal.removeAction(forKey: Constants.goalPulseActionKey)
            goal.run(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.6, duration: 0.18),
                    SKAction.run { goal.strokeColor = .white }
                ]),
                SKAction.scale(to: 0.1, duration: 0.25)
            ]))
        }

        // Sphere flies to goal centre, shrinks, disappears
        if let sphere = sphereNode {
            sphere.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.08),
                SKAction.group([
                    SKAction.move(to: goalPos, duration: 0.22),
                    SKAction.scale(to: 0.1, duration: 0.22)
                ]),
                SKAction.removeFromParent()
            ]))
        }

        // === MASSIVE EXPLOSION at goal after ball absorbed ===

        // 1) Full-screen WHITE flash — hard slam
        run(SKAction.sequence([SKAction.wait(forDuration: 0.32), SKAction.run { [weak self] in
            guard let self else { return }
            let flash = SKSpriteNode(color: .white, size: self.size)
            flash.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
            flash.zPosition = 50
            flash.alpha = 0.9
            flash.blendMode = .add
            self.addChild(flash)
            flash.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.35), .removeFromParent()]))
        }]))

        // 2) Heavy screen shake — earthquake feel
        run(SKAction.sequence([SKAction.wait(forDuration: 0.33), SKAction.run { [weak self] in
            guard let bg = self?.backgroundNode else { return }
            let originalPos = bg.position
            let shakeAmt: CGFloat = 14
            let shakeSeq = SKAction.sequence([
                SKAction.moveBy(x: shakeAmt, y: shakeAmt, duration: 0.04),
                SKAction.moveBy(x: -shakeAmt * 2, y: -shakeAmt * 0.5, duration: 0.04),
                SKAction.moveBy(x: shakeAmt * 1.5, y: -shakeAmt, duration: 0.04),
                SKAction.moveBy(x: -shakeAmt, y: shakeAmt * 1.5, duration: 0.04),
                SKAction.moveBy(x: shakeAmt * 0.5, y: -shakeAmt * 0.5, duration: 0.04),
                SKAction.move(to: originalPos, duration: 0.06)
            ])
            bg.run(shakeSeq)
            // Haptic aftershock
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
        }]))

        // 3) Shockwave ring — expands from goal
        run(SKAction.sequence([SKAction.wait(forDuration: 0.34), SKAction.run { [weak self] in
            guard let self else { return }
            let worldColor = UIColor(self.worldDefinition?.primaryColor ?? .cyan)
            let shockwave = SKShapeNode(circleOfRadius: 10)
            shockwave.position = goalPos
            shockwave.strokeColor = worldColor
            shockwave.fillColor = .clear
            shockwave.lineWidth = 4
            shockwave.zPosition = 30
            shockwave.blendMode = .add
            self.addChild(shockwave)
            shockwave.run(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 25.0, duration: 0.6),
                    SKAction.sequence([
                        SKAction.wait(forDuration: 0.15),
                        SKAction.fadeOut(withDuration: 0.45)
                    ])
                ]),
                .removeFromParent()
            ]))
        }]))

        // 4) Second world-color flash — pulsing afterglow
        run(SKAction.sequence([SKAction.wait(forDuration: 0.5), SKAction.run { [weak self] in
            guard let self else { return }
            let worldColor = UIColor(self.worldDefinition?.primaryColor ?? .cyan)
            let flash2 = SKSpriteNode(color: worldColor.withAlphaComponent(0.6), size: self.size)
            flash2.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
            flash2.zPosition = 50
            flash2.blendMode = .add
            self.addChild(flash2)
            flash2.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.4), .removeFromParent()]))
        }]))

        // 5) Particle explosion at goal — 30 particles (capped for perf on older devices)
        run(SKAction.sequence([SKAction.wait(forDuration: 0.34), SKAction.run { [weak self] in
            guard let self else { return }
            let worldColor = UIColor(self.worldDefinition?.primaryColor ?? .cyan)
            for _ in 0..<30 {
                let sz: CGFloat = CGFloat.random(in: 4...12)
                let colors: [UIColor] = [worldColor, .white, .yellow, worldColor]
                let color = colors.randomElement() ?? worldColor
                let particle = SKSpriteNode(color: color, size: CGSize(width: sz, height: sz))
                particle.position = goalPos
                particle.zPosition = 28
                particle.blendMode = .add
                self.addChild(particle)
                let angle = CGFloat.random(in: 0..<(2 * .pi))
                let speed = CGFloat.random(in: 200...600)
                let dur = TimeInterval.random(in: 0.4...0.9)
                let dx = cos(angle) * speed * CGFloat(dur)
                let dy = sin(angle) * speed * CGFloat(dur)
                particle.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: dx, y: dy, duration: dur),
                        SKAction.sequence([
                            SKAction.wait(forDuration: dur * 0.3),
                            SKAction.fadeOut(withDuration: dur * 0.7)
                        ])
                    ]),
                    .removeFromParent()
                ]))
            }
        }]))

        // 6) Fireworks — 5 staggered bursts (capped from 7 for perf)
        createFireworksBurst(at: goalPos, delay: 0.45)
        createFireworksBurst(at: CGPoint(x: size.width * 0.15, y: size.height * 0.7), delay: 0.58)
        createFireworksBurst(at: CGPoint(x: size.width * 0.85, y: size.height * 0.3), delay: 0.71)
        createFireworksBurst(at: CGPoint(x: size.width * 0.3, y: size.height * 0.2), delay: 0.84)
        createFireworksBurst(at: CGPoint(x: size.width * 0.7, y: size.height * 0.8), delay: 0.97)

        // Show complete UI (slightly later to let explosions breathe)
        let delayAction = SKAction.sequence([
            SKAction.wait(forDuration: 1.4),
            SKAction.run { [weak self] in
                self?.emitLevelCompleteMessage()
                self?.levelCompleted?()
            }
        ])
        run(delayAction)
    }

    // Street art fireworks palette — used across all worlds
    private var fireworksPalette: [UIColor] {[
        UIColor(red: 1.0,  green: 0.84, blue: 0.0,  alpha: 1), // gold
        UIColor(red: 1.0,  green: 0.08, blue: 0.58, alpha: 1), // hot pink
        UIColor(red: 0.39, green: 1.0,  blue: 0.08, alpha: 1), // lime
        UIColor(red: 1.0,  green: 1.0,  blue: 1.0,  alpha: 1), // white
        UIColor(red: 1.0,  green: 0.4,  blue: 0.0,  alpha: 1), // orange
        UIColor(red: 0.54, green: 0.17, blue: 0.89, alpha: 1), // purple
        UIColor(red: 0.0,  green: 1.0,  blue: 1.0,  alpha: 1), // cyan
        UIColor(red: 1.0,  green: 0.25, blue: 0.25, alpha: 1), // red
    ]}

    private func createFireworksBurst(at position: CGPoint, delay: TimeInterval) {
        let worldColor = UIColor(worldDefinition?.primaryColor ?? .cyan)
        // Mix world colour with full palette for variety
        var colors = fireworksPalette
        colors.append(worldColor)
        colors.append(worldColor)  // double weight the world colour

        run(SKAction.wait(forDuration: delay)) { [weak self] in
            guard let self else { return }

            // Haptic per burst
            let haptic = UIImpactFeedbackGenerator(style: .medium)
            haptic.impactOccurred(intensity: 0.8)

            // Central flash ring — big expanding shockwave
            let ringColor = colors.randomElement() ?? worldColor
            let ring = SKShapeNode(circleOfRadius: 8)
            ring.position = position
            ring.strokeColor = ringColor
            ring.fillColor = ringColor.withAlphaComponent(0.35)
            ring.lineWidth = 4
            ring.zPosition = 25
            ring.blendMode = .add
            self.addChild(ring)
            ring.run(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 10.0, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5)
                ]),
                .removeFromParent()
            ]))

            // 24 particles per burst (capped from 48 for perf)
            for i in 0..<24 {
                let color = colors[i % colors.count]
                let sz: CGFloat = CGFloat.random(in: 4...10)
                let particle = SKSpriteNode(color: color, size: CGSize(width: sz, height: sz))
                particle.position = position
                particle.zPosition = 22
                particle.blendMode = .add
                self.addChild(particle)

                let angle = CGFloat(i) * (2 * .pi / 24) + CGFloat.random(in: -0.15...0.15)
                let speed = CGFloat.random(in: 180...450)
                let dur = TimeInterval.random(in: 0.5...1.1)
                let dx = cos(angle) * speed * CGFloat(dur)
                let dy = sin(angle) * speed * CGFloat(dur)

                particle.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: dx, y: dy, duration: dur),
                        SKAction.sequence([
                            SKAction.wait(forDuration: dur * 0.35),
                            SKAction.fadeOut(withDuration: dur * 0.65)
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
        // Speed bonus already calculated and stored in lastSpeedBonus by applyCompletionScoreIfNeeded()

        // Record best score — store for LevelCompleteView to read
        let finalScore = gameState.currentLevelScore
        lastTotalScore = finalScore
        lastIsNewBest = gameState.updateBestScoreIfNeeded(world: world.id, level: definition.levelId, score: finalScore)
        if lastIsNewBest {
            // Play excited "HIGH SCORE!" voice clip after a short delay for impact
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.playSFX("high-score")
            }
        }
        gameState.commitCurrentAttemptScore()

        // Always mark level as completed first
        gameState.markLevelCompleted(world: world.id, level: definition.levelId)

        // Record stats
        let elapsed = levelStartTime.map { CACurrentMediaTime() - $0 } ?? 0
        gameState.recordLevelComplete(
            flips: flipCount,
            collectibles: collectiblesCollectedThisAttempt,
            elapsed: elapsed
        )

        shouldOfferIntermissionAfterCompletion = gameState.shouldTriggerIntermission(world: world.id, level: definition.levelId)
    }

}
