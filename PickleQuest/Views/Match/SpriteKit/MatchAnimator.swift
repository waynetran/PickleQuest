import SpriteKit

@MainActor
final class MatchAnimator {
    private typealias AC = MatchAnimationConstants
    private typealias T = MatchAnimationConstants.Timing
    private typealias Pos = MatchAnimationConstants.Positions

    private weak var scene: MatchCourtScene?

    init(scene: MatchCourtScene) {
        self.scene = scene
    }

    // MARK: - Public

    func animate(event: MatchEvent) async {
        guard scene != nil else { return }

        switch event {
        case .matchStart(let playerName, let opponentName):
            await animateMatchStart(playerName: playerName, opponentName: opponentName)
        case .gameStart(let gameNumber):
            await animateGameStart(gameNumber: gameNumber)
        case .pointPlayed(let point):
            await animatePoint(point)
        case .streakAlert(let side, let count):
            await animateStreak(side: side, count: count)
        case .fatigueWarning(let side, let energyPercent):
            await animateFatigue(side: side, energyPercent: energyPercent)
        case .abilityTriggered(let side, let abilityName, _):
            await animateAbility(side: side, name: abilityName)
        case .gameEnd(let gameNumber, let winnerSide, _):
            await animateGameEnd(gameNumber: gameNumber, winnerSide: winnerSide)
        case .matchEnd(let result):
            await animateMatchEnd(didPlayerWin: result.didPlayerWin)
        }
    }

    // MARK: - Match Start

    private func animateMatchStart(playerName: String, opponentName: String) async {
        guard let scene else { return }

        // Slide players in from off-screen
        let nearTarget = CourtRenderer.courtPoint(nx: Pos.playerCenterNX, ny: Pos.nearPlayerNY)
        let farTarget = CourtRenderer.courtPoint(nx: Pos.playerCenterNX, ny: Pos.farPlayerNY)

        scene.nearPlayer.position = CGPoint(x: nearTarget.x, y: -100)
        scene.farPlayer.position = CGPoint(x: farTarget.x, y: AC.sceneHeight + 100)
        scene.nearPlayer.alpha = 1
        scene.farPlayer.alpha = 1

        // Slide both in simultaneously using runAsync
        await scene.nearPlayer.runAsync(.move(to: nearTarget, duration: 0.6))
        // Far player slides in too — the 0.6s overlap from near is close enough
        await scene.farPlayer.runAsync(.move(to: farTarget, duration: 0.1)) // catch up (already mostly there from near anim)

        // "VS" text
        await scene.showAnnouncement("VS")
    }

    // MARK: - Game Start

    private func animateGameStart(gameNumber: Int) async {
        guard let scene else { return }
        scene.resetPlayerPositions()
        scene.ball.alpha = 0
        scene.ballShadow.alpha = 0
        await scene.showAnnouncement("Game \(gameNumber)", fontSize: AC.Text.calloutFontSize)
    }

    // MARK: - Point Animation

    private func animatePoint(_ point: MatchPoint) async {
        guard let scene else { return }

        let serverIsNear = point.servingSide == .player
        let serverNode = serverIsNear ? scene.nearPlayer! : scene.farPlayer!
        let receiverNode = serverIsNear ? scene.farPlayer! : scene.nearPlayer!

        let serverNY = serverIsNear ? Pos.nearPlayerNY : Pos.farPlayerNY
        let receiverNY = serverIsNear ? Pos.farPlayerNY : Pos.nearPlayerNY

        // Position server slightly to one side
        let serverPos = CourtRenderer.courtPoint(nx: Pos.serverOffsetNX, ny: serverNY)
        let receiverPos = CourtRenderer.courtPoint(nx: Pos.receiverOffsetNX, ny: receiverNY)
        serverNode.position = serverPos
        receiverNode.position = receiverPos

        // Show ball at server
        scene.ball.position = serverPos
        scene.ball.alpha = 1
        scene.ballShadow.position = serverPos
        scene.ballShadow.alpha = 0.5

        // Phase 1: Serve (swing then ball arc)
        await animateServe(from: serverPos, to: receiverPos, serverNY: serverNY, receiverNY: receiverNY, serverNode: serverNode)

        // Phase 2: Rally bounces (if rally length > 1)
        let bounces = min(point.rallyLength - 1, T.maxVisualBounces)
        if bounces > 0 && point.pointType != .ace {
            await animateRally(
                bounces: bounces,
                serverIsNear: serverIsNear
            )
        }

        // Phase 3: Outcome
        await animateOutcome(point: point, serverIsNear: serverIsNear)

        // Brief pause between points
        try? await Task.sleep(for: .milliseconds(Int(T.pointPause * 1000)))

        // Hide ball
        scene.ball.alpha = 0
        scene.ballShadow.alpha = 0
    }

    private func animateServe(
        from: CGPoint,
        to: CGPoint,
        serverNY: CGFloat,
        receiverNY: CGFloat,
        serverNode: SKSpriteNode
    ) async {
        // Server swing animation (quick scale pulse, then ball follows)
        await serverNode.runAsync(.sequence([
            .scaleX(by: 1.2, y: 1.0, duration: 0.08),
            .scaleX(by: 1.0 / 1.2, y: 1.0, duration: 0.08)
        ]))

        // Ball arc from server to receiver
        await animateBallArc(from: from, to: to, duration: T.serveDuration, arcHeight: T.arcPeak)
    }

    private func animateRally(
        bounces: Int,
        serverIsNear: Bool
    ) async {
        guard let scene else { return }

        var goingToFar = !serverIsNear // after serve, ball goes to receiver; next bounce goes other way
        for _ in 0..<bounces {
            // Randomize lateral position for variety
            let lateralOffset = CGFloat.random(in: -Pos.lateralRangeNX...Pos.lateralRangeNX)
            let nx = 0.5 + lateralOffset

            let targetNY: CGFloat
            let hitter: SKSpriteNode
            if goingToFar {
                targetNY = Pos.farPlayerNY - 0.05
                hitter = scene.farPlayer
            } else {
                targetNY = Pos.nearPlayerNY + 0.05
                hitter = scene.nearPlayer
            }

            let target = CourtRenderer.courtPoint(nx: nx, ny: targetNY)
            let current = scene.ball.position

            // Move hitter toward ball (short move, then ball arc)
            let hitterTarget = CGPoint(x: target.x, y: hitter.position.y)
            await hitter.runAsync(.move(to: hitterTarget, duration: T.bounceDuration * 0.3))

            // Ball arc
            let arcHeight = T.arcPeak * 0.6 // lower arc for rallies
            await animateBallArc(from: current, to: target, duration: T.bounceDuration, arcHeight: arcHeight)

            goingToFar.toggle()
        }
    }

    private func animateOutcome(point: MatchPoint, serverIsNear: Bool) async {
        guard let scene else { return }

        let winnerIsNear = point.winnerSide == .player
        let winnerNode = winnerIsNear ? scene.nearPlayer! : scene.farPlayer!
        let loserNode = winnerIsNear ? scene.farPlayer! : scene.nearPlayer!

        switch point.pointType {
        case .ace:
            // Ball whizzes past receiver
            let receiverIsNear = !serverIsNear
            let missPos: CGPoint
            if receiverIsNear {
                missPos = CGPoint(x: scene.ball.position.x + 30, y: -20)
            } else {
                missPos = CGPoint(x: scene.ball.position.x + 30, y: AC.sceneHeight + 20)
            }
            await animateBallArc(from: scene.ball.position, to: missPos, duration: 0.3, arcHeight: 10)

            // Receiver flinch
            await loserNode.runAsync(.sequence([
                .moveBy(x: -5, y: 0, duration: 0.05),
                .moveBy(x: 10, y: 0, duration: 0.05),
                .moveBy(x: -5, y: 0, duration: 0.05)
            ]))

            await scene.showCallout("ACE!", at: scene.ball.position, color: .yellow)

        case .winner:
            // Emphatic winning shot — ball hits ground hard
            let groundPos = CourtRenderer.courtPoint(
                nx: CGFloat.random(in: 0.2...0.8),
                ny: winnerIsNear ? Pos.farPlayerNY - 0.1 : Pos.nearPlayerNY + 0.1
            )
            await animateBallArc(from: scene.ball.position, to: groundPos, duration: 0.3, arcHeight: T.arcPeak * 0.4)

            // Winner pump
            await winnerNode.runAsync(.sequence([
                .moveBy(x: 0, y: 8, duration: 0.1),
                .moveBy(x: 0, y: -8, duration: 0.15)
            ]))

            // Dust effect
            spawnDustParticle(at: groundPos)

            await scene.showCallout("WINNER!", at: groundPos, color: .green)

        case .unforcedError:
            // Ball into net or out
            let isNetError = Bool.random()
            if isNetError {
                let netPos = CourtRenderer.courtPoint(nx: 0.5, ny: 0.5)
                await animateBallArc(from: scene.ball.position, to: netPos, duration: 0.3, arcHeight: 5)
                await scene.showCallout("NET", at: netPos, color: .red)
            } else {
                // Out of bounds
                let outX = Bool.random() ? AC.sceneWidth + 20 : -20
                let outPos = CGPoint(x: outX, y: scene.ball.position.y)
                await animateBallArc(from: scene.ball.position, to: outPos, duration: 0.3, arcHeight: T.arcPeak * 0.3)
                await scene.showCallout("OUT!", at: CGPoint(x: AC.sceneWidth / 2, y: scene.ball.position.y), color: .red)
            }

        case .forcedError:
            // Aggressive shot forces ball wide
            let wideX: CGFloat = Bool.random() ? AC.sceneWidth + 20 : -20
            let errorPos = CGPoint(x: wideX, y: scene.ball.position.y)
            await animateBallArc(from: scene.ball.position, to: errorPos, duration: 0.35, arcHeight: T.arcPeak * 0.5)

            // Winner slight pump
            await winnerNode.runAsync(.sequence([
                .moveBy(x: 0, y: 5, duration: 0.08),
                .moveBy(x: 0, y: -5, duration: 0.12)
            ]))

        case .rally:
            // Final winning shot after long exchange
            let winPos = CourtRenderer.courtPoint(
                nx: CGFloat.random(in: 0.15...0.85),
                ny: winnerIsNear ? Pos.farPlayerNY - 0.08 : Pos.nearPlayerNY + 0.08
            )
            await animateBallArc(from: scene.ball.position, to: winPos, duration: 0.35, arcHeight: T.arcPeak * 0.5)

            spawnDustParticle(at: winPos)

            if point.rallyLength >= 8 {
                await scene.showCallout("\(point.rallyLength) shots!", at: winPos, color: .cyan)
            }
        }
    }

    // MARK: - Ball Arc

    private func animateBallArc(from: CGPoint, to: CGPoint, duration: TimeInterval, arcHeight: CGFloat) async {
        guard let scene else { return }

        let steps = max(Int(duration / 0.016), 4) // ~60fps steps
        let dt = duration / Double(steps)

        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = from.x + (to.x - from.x) * t
            let baseY = from.y + (to.y - from.y) * t
            let arcOffset = arcHeight * sin(.pi * t) // parabolic arc
            let y = baseY + arcOffset

            scene.ball.position = CGPoint(x: x, y: y)

            // Shadow stays on ground
            let shadowScale = 1.0 - (arcOffset / (arcHeight * 2))
            scene.ballShadow.position = CGPoint(x: x, y: baseY)
            scene.ballShadow.setScale(max(0.3, shadowScale))

            // Scale ball slightly by perspective (approximate depth from y position)
            let ny = (baseY - AC.Court.courtBottomY) / AC.Court.courtHeight
            let pScale = CourtRenderer.perspectiveScale(ny: max(0, min(1, ny)))
            scene.ball.setScale(AC.Sprites.ballScale * pScale)

            try? await Task.sleep(for: .milliseconds(Int(dt * 1000)))
        }
    }

    // MARK: - Event Animations

    private func animateStreak(side: MatchSide, count: Int) async {
        guard let scene else { return }

        let node = side == .player ? scene.nearPlayer! : scene.farPlayer!

        // Fire-colored glow
        let glow = SKShapeNode(circleOfRadius: 30)
        glow.fillColor = UIColor.orange.withAlphaComponent(0.4)
        glow.strokeColor = UIColor.orange.withAlphaComponent(0.6)
        glow.lineWidth = 2
        glow.position = node.position
        glow.zPosition = AC.ZPositions.effects
        scene.addChild(glow)

        await glow.runAsync(
            .sequence([
                .group([
                    .scale(to: 2.5, duration: 0.4),
                    .fadeOut(withDuration: 0.4)
                ]),
                .removeFromParent()
            ])
        )

        let streakText = "\(count)-point streak!"
        await scene.showCallout(streakText, at: CGPoint(x: node.position.x, y: node.position.y + 50), color: .orange)
    }

    private func animateFatigue(side: MatchSide, energyPercent: Double) async {
        guard let scene else { return }

        let node = side == .player ? scene.nearPlayer! : scene.farPlayer!

        // Dim the player slightly
        await node.runAsync(
            .sequence([
                .fadeAlpha(to: 0.6, duration: 0.2),
                .fadeAlpha(to: 1.0, duration: 0.3)
            ])
        )

        // Sweat drop
        let sweat = SKLabelNode(text: "💧")
        sweat.fontSize = 16
        sweat.position = CGPoint(x: node.position.x + 15, y: node.position.y + 30)
        sweat.zPosition = AC.ZPositions.effects
        scene.addChild(sweat)

        await sweat.runAsync(
            .sequence([
                .moveBy(x: 0, y: -20, duration: 0.5),
                .fadeOut(withDuration: 0.2),
                .removeFromParent()
            ])
        )
    }

    private func animateAbility(side: MatchSide, name: String) async {
        guard let scene else { return }

        let node = side == .player ? scene.nearPlayer! : scene.farPlayer!

        // Purple flash ring
        let ring = SKShapeNode(circleOfRadius: 20)
        ring.fillColor = .clear
        ring.strokeColor = UIColor.purple.withAlphaComponent(0.8)
        ring.lineWidth = 3
        ring.position = node.position
        ring.zPosition = AC.ZPositions.effects
        scene.addChild(ring)

        await ring.runAsync(
            .sequence([
                .group([
                    .scale(to: 3.0, duration: 0.4),
                    .fadeOut(withDuration: 0.5)
                ]),
                .removeFromParent()
            ])
        )

        await scene.showCallout(name, at: CGPoint(x: node.position.x, y: node.position.y + 50), color: .purple)
    }

    private func animateGameEnd(gameNumber: Int, winnerSide: MatchSide) async {
        guard let scene else { return }

        let winnerNode = winnerSide == .player ? scene.nearPlayer! : scene.farPlayer!

        // Small celebration jump
        await winnerNode.runAsync(
            .sequence([
                .moveBy(x: 0, y: 15, duration: 0.15),
                .moveBy(x: 0, y: -15, duration: 0.2)
            ])
        )

        await scene.showAnnouncement("Game Over")
    }

    private func animateMatchEnd(didPlayerWin: Bool) async {
        guard let scene else { return }

        let winnerNode = didPlayerWin ? scene.nearPlayer! : scene.farPlayer!

        // Winner celebration — bigger jump + scale pulse
        await winnerNode.runAsync(
            .sequence([
                .group([
                    .moveBy(x: 0, y: 25, duration: 0.2),
                    .scale(by: 1.15, duration: 0.2)
                ]),
                .group([
                    .moveBy(x: 0, y: -25, duration: 0.25),
                    .scale(by: 1.0 / 1.15, duration: 0.25)
                ])
            ])
        )

        let text = didPlayerWin ? "VICTORY!" : "DEFEAT"
        let color: UIColor = didPlayerWin ? .green : .red
        scene.announcementLabel.fontColor = color
        await scene.showAnnouncement(text)
        scene.announcementLabel.fontColor = .white
    }

    // MARK: - Particles

    /// Fire-and-forget dust particles — uses SKAction system so no async needed
    private func spawnDustParticle(at position: CGPoint) {
        guard let scene else { return }

        for _ in 0..<3 {
            let dust = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            dust.fillColor = UIColor.white.withAlphaComponent(0.4)
            dust.strokeColor = .clear
            dust.position = position
            dust.zPosition = AC.ZPositions.effects
            scene.addChild(dust)

            let dx = CGFloat.random(in: -15...15)
            let dy = CGFloat.random(in: 5...15)
            // Use scene.run with an action that runs the dust animation to avoid async requirement
            let dustAction = SKAction.sequence([
                .group([
                    .moveBy(x: dx, y: dy, duration: 0.3),
                    .fadeOut(withDuration: 0.3),
                    .scale(to: 0.3, duration: 0.3)
                ]),
                .removeFromParent()
            ])
            dust.run(dustAction)
        }
    }
}
