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
        case .matchStart(let playerName, let opponentName, _, _):
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
        case .timeoutCalled(let side, _, _):
            await animateTimeout(side: side)
        case .consumableUsed(let side, let name, _):
            await animateConsumable(side: side, name: name)
        case .hookCallAttempt(let side, let success, _):
            await animateHookCall(side: side, success: success)
        case .sideOut(let newServingTeam, let serverNumber):
            await animateSideOut(newServingTeam: newServingTeam, serverNumber: serverNumber)
        case .resigned:
            break // no animation needed, match ends
        case .matchEnd(let result):
            await animateMatchEnd(didPlayerWin: result.didPlayerWin)
        }
    }

    // MARK: - Match Start

    private func animateMatchStart(playerName: String, opponentName: String) async {
        guard let scene else { return }

        if scene.isDoubles {
            await animateDoublesMatchStart()
        } else {
            await animateSinglesMatchStart()
        }
    }

    private func animateSinglesMatchStart() async {
        guard let scene else { return }

        let nearTarget = CourtRenderer.courtPoint(nx: Pos.playerCenterNX, ny: Pos.nearPlayerNY)
        let farTarget = CourtRenderer.courtPoint(nx: Pos.playerCenterNX, ny: Pos.farPlayerNY)

        scene.nearPlayer.position = CGPoint(x: nearTarget.x, y: -100)
        scene.farPlayer.position = CGPoint(x: farTarget.x, y: AC.sceneHeight + 100)
        scene.nearPlayer.alpha = 1
        scene.farPlayer.alpha = 1

        scene.nearAnimator?.play(.walkAway)
        scene.farAnimator?.play(.walkToward)

        await scene.nearPlayer.runAsync(.move(to: nearTarget, duration: 0.6))
        await scene.farPlayer.runAsync(.move(to: farTarget, duration: 0.1))

        scene.nearAnimator?.play(.idleBack)
        scene.farAnimator?.play(.idleFront)

        await scene.showAnnouncement("VS")
    }

    private func animateDoublesMatchStart() async {
        guard let scene else { return }

        // Near team: player (left) and partner (right)
        let nearLeftTarget = CourtRenderer.courtPoint(nx: Pos.doublesLeftNX, ny: Pos.nearPlayerNY)
        let nearRightTarget = CourtRenderer.courtPoint(nx: Pos.doublesRightNX, ny: Pos.nearPlayerNY)
        // Far team: opponent (left) and opponent2 (right)
        let farLeftTarget = CourtRenderer.courtPoint(nx: Pos.doublesLeftNX, ny: Pos.farPlayerNY)
        let farRightTarget = CourtRenderer.courtPoint(nx: Pos.doublesRightNX, ny: Pos.farPlayerNY)

        scene.nearPlayer.position = CGPoint(x: nearLeftTarget.x, y: -100)
        scene.farPlayer.position = CGPoint(x: farLeftTarget.x, y: AC.sceneHeight + 100)
        scene.nearPlayer.alpha = 1
        scene.farPlayer.alpha = 1

        if let np = scene.nearPartner {
            np.position = CGPoint(x: nearRightTarget.x, y: -100)
            np.alpha = 1
        }
        if let fp = scene.farPartner {
            fp.position = CGPoint(x: farRightTarget.x, y: AC.sceneHeight + 100)
            fp.alpha = 1
        }

        // Walk animations
        scene.nearAnimator?.play(.walkAway)
        scene.nearPartnerAnimator?.play(.walkAway)
        scene.farAnimator?.play(.walkToward)
        scene.farPartnerAnimator?.play(.walkToward)

        // Slide all 4 in (fire-and-forget for partners, await primary players)
        if let np = scene.nearPartner { fireAction(np, .move(to: nearRightTarget, duration: 0.55)) }
        await scene.nearPlayer.runAsync(.move(to: nearLeftTarget, duration: 0.6))
        if let fp = scene.farPartner { fireAction(fp, .move(to: farRightTarget, duration: 0.1)) }
        await scene.farPlayer.runAsync(.move(to: farLeftTarget, duration: 0.1))

        // Idle
        scene.nearAnimator?.play(.idleBack)
        scene.nearPartnerAnimator?.play(.idleBack)
        scene.farAnimator?.play(.idleFront)
        scene.farPartnerAnimator?.play(.idleFront)

        await scene.showAnnouncement("DOUBLES")
    }

    // MARK: - Game Start

    private func animateGameStart(gameNumber: Int) async {
        guard let scene else { return }
        scene.resetPlayerPositions()
        scene.ball.alpha = 0
        scene.ballShadow.alpha = 0

        // Ready stance between games
        scene.nearAnimator?.play(.ready)
        scene.farAnimator?.play(.ready)
        scene.nearPartnerAnimator?.play(.ready)
        scene.farPartnerAnimator?.play(.ready)

        await scene.showAnnouncement("Game \(gameNumber)", fontSize: AC.Text.calloutFontSize)
    }

    // MARK: - Point Animation

    private func animatePoint(_ point: MatchPoint) async {
        guard let scene else { return }

        let serverIsNear = point.servingSide == .player
        let serverNode = serverIsNear ? scene.nearPlayer! : scene.farPlayer!
        let receiverNode = serverIsNear ? scene.farPlayer! : scene.nearPlayer!
        let serverAnimator = serverIsNear ? scene.nearAnimator : scene.farAnimator
        let receiverAnimator = serverIsNear ? scene.farAnimator : scene.nearAnimator

        // Server behind baseline (legal serve position), receiver at baseline
        let serverNY = serverIsNear ? Pos.serverNearNY : Pos.serverFarNY
        let receiverNY = serverIsNear ? Pos.farPlayerNY : Pos.nearPlayerNY

        // Position server slightly to one side
        let serverPos = CourtRenderer.courtPoint(nx: Pos.serverOffsetNX, ny: serverNY)
        let receiverPos = CourtRenderer.courtPoint(nx: Pos.receiverOffsetNX, ny: receiverNY)
        serverNode.position = serverPos
        receiverNode.position = receiverPos

        // Reset scales for serve positions
        let serverBaseScale = serverIsNear ? AC.Sprites.nearPlayerScale : AC.Sprites.farPlayerScale
        serverNode.setScale(serverBaseScale * CourtRenderer.perspectiveScale(ny: serverNY))
        let receiverBaseScale = serverIsNear ? AC.Sprites.farPlayerScale : AC.Sprites.nearPlayerScale
        receiverNode.setScale(receiverBaseScale * CourtRenderer.perspectiveScale(ny: receiverNY))

        // Ready stance before serve
        serverAnimator?.play(.ready)
        receiverAnimator?.play(.ready)

        // Show ball at server
        scene.ball.position = serverPos
        scene.ball.alpha = 1
        scene.ballShadow.position = serverPos
        scene.ballShadow.alpha = 0.5

        // Phase 1: Serve (animation then ball arc)
        await animateServe(from: serverPos, to: receiverPos, serverNY: serverNY, receiverNY: receiverNY, serverNode: serverNode, serverAnimator: serverAnimator)

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

        // Between points: ready stance
        scene.nearAnimator?.play(.ready)
        scene.farAnimator?.play(.ready)
        scene.nearPartnerAnimator?.play(.ready)
        scene.farPartnerAnimator?.play(.ready)

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
        serverNode: SKSpriteNode,
        serverAnimator: SpriteSheetAnimator?
    ) async {
        // Serve prep animation
        await serverAnimator?.playAsync(.servePrep)

        // Serve swing (fire-and-forget, ball follows)
        serverAnimator?.play(.serveSwing)

        // Ball arc from server to receiver
        await animateBallArc(from: from, to: to, duration: T.serveDuration, arcHeight: T.arcPeak)

        // Return server to idle
        let isNear = serverNode === scene?.nearPlayer
        serverAnimator?.play(.idle(isNear: isNear))
    }

    private func animateRally(
        bounces: Int,
        serverIsNear: Bool
    ) async {
        guard let scene else { return }

        var goingToFar = !serverIsNear
        // Track which team member hits in doubles (alternates each bounce)
        var nearHitCount = 0
        var farHitCount = 0

        for bounceIndex in 0..<bounces {
            let lateralOffset = CGFloat.random(in: -Pos.lateralRangeNX...Pos.lateralRangeNX)
            let nx = 0.5 + lateralOffset

            // Progressive kitchen approach
            let isServer: Bool
            if goingToFar {
                isServer = !serverIsNear
            } else {
                isServer = serverIsNear
            }
            let approachRate: CGFloat = isServer ? 6.0 : 3.0
            let approachProgress = min(1.0, CGFloat(bounceIndex + 1) / approachRate)

            let targetNY: CGFloat
            let hitter: SKSpriteNode
            let hitterAnimator: SpriteSheetAnimator?
            let isNearSide: Bool

            if goingToFar {
                let baseNY = Pos.farPlayerNY - 0.05
                targetNY = baseNY + (Pos.kitchenApproachFarNY - baseNY) * approachProgress
                isNearSide = false

                // In doubles, alternate between far team members
                if scene.isDoubles, let fp = scene.farPartner, farHitCount % 2 == 1 {
                    hitter = fp
                    hitterAnimator = scene.farPartnerAnimator
                } else {
                    hitter = scene.farPlayer
                    hitterAnimator = scene.farAnimator
                }
                farHitCount += 1
            } else {
                let baseNY = Pos.nearPlayerNY + 0.05
                targetNY = baseNY + (Pos.kitchenApproachNearNY - baseNY) * approachProgress
                isNearSide = true

                // In doubles, alternate between near team members
                if scene.isDoubles, let np = scene.nearPartner, nearHitCount % 2 == 1 {
                    hitter = np
                    hitterAnimator = scene.nearPartnerAnimator
                } else {
                    hitter = scene.nearPlayer
                    hitterAnimator = scene.nearAnimator
                }
                nearHitCount += 1
            }

            let target = CourtRenderer.courtPoint(nx: nx, ny: targetNY)
            let current = scene.ball.position

            // Move hitter to position
            let movingLeft = target.x < hitter.position.x
            hitterAnimator?.play(movingLeft ? .walkLeft : .walkRight)
            await hitter.runAsync(.move(to: target, duration: T.bounceDuration * 0.4))

            // In doubles, also advance the teammate forward
            if scene.isDoubles {
                let teammateNX = nx > 0.5 ? Pos.doublesLeftNX : Pos.doublesRightNX
                let teammateTarget = CourtRenderer.courtPoint(nx: teammateNX, ny: targetNY)
                if isNearSide {
                    if let teammate = (hitter === scene.nearPlayer) ? scene.nearPartner : scene.nearPlayer {
                        fireAction(teammate, .move(to: teammateTarget, duration: T.bounceDuration * 0.5))
                        teammate.setScale(AC.Sprites.nearPlayerScale * CourtRenderer.perspectiveScale(ny: targetNY))
                    }
                } else {
                    if let teammate = (hitter === scene.farPlayer) ? scene.farPartner : scene.farPlayer {
                        fireAction(teammate, .move(to: teammateTarget, duration: T.bounceDuration * 0.5))
                        teammate.setScale(AC.Sprites.farPlayerScale * CourtRenderer.perspectiveScale(ny: targetNY))
                    }
                }
            }

            // Update hitter scale for new perspective position
            let baseScale = isNearSide ? AC.Sprites.nearPlayerScale : AC.Sprites.farPlayerScale
            hitter.setScale(baseScale * CourtRenderer.perspectiveScale(ny: targetNY))

            // Hit animation
            let hitAnim: CharacterAnimationState = movingLeft ? .backhand : .forehand
            hitterAnimator?.play(hitAnim)

            // Ball arc
            let arcHeight = T.arcPeak * 0.6
            await animateBallArc(from: current, to: target, duration: T.bounceDuration, arcHeight: arcHeight)

            // Return to idle
            hitterAnimator?.play(.idle(isNear: isNearSide))

            goingToFar.toggle()
        }
    }

    private func animateOutcome(point: MatchPoint, serverIsNear: Bool) async {
        guard let scene else { return }

        let winnerIsNear = point.winnerSide == .player
        let winnerNode = winnerIsNear ? scene.nearPlayer! : scene.farPlayer!
        let loserNode = winnerIsNear ? scene.farPlayer! : scene.nearPlayer!
        let winnerAnimator = winnerIsNear ? scene.nearAnimator : scene.farAnimator
        let loserAnimator = winnerIsNear ? scene.farAnimator : scene.nearAnimator

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

            // Receiver dive/flinch
            loserAnimator?.showStaticFrame(.runDive, frameIndex: 3)
            await loserNode.runAsync(.sequence([
                .moveBy(x: -5, y: 0, duration: 0.05),
                .moveBy(x: 10, y: 0, duration: 0.05),
                .moveBy(x: -5, y: 0, duration: 0.05)
            ]))

            // Server celebrate
            winnerAnimator?.play(.celebrate)

            await scene.showCallout("ACE!", at: scene.ball.position, color: .yellow)

        case .winner:
            // Emphatic winning shot
            let groundPos = CourtRenderer.courtPoint(
                nx: CGFloat.random(in: 0.2...0.8),
                ny: winnerIsNear ? Pos.farPlayerNY - 0.1 : Pos.nearPlayerNY + 0.1
            )

            // Winner hits forehand
            winnerAnimator?.play(.forehand)
            await animateBallArc(from: scene.ball.position, to: groundPos, duration: 0.3, arcHeight: T.arcPeak * 0.4)

            // Celebrate
            winnerAnimator?.play(.celebrate)
            await winnerNode.runAsync(.sequence([
                .moveBy(x: 0, y: 8, duration: 0.1),
                .moveBy(x: 0, y: -8, duration: 0.15)
            ]))

            spawnDustParticle(at: groundPos)
            await scene.showCallout("WINNER!", at: groundPos, color: .green)

        case .unforcedError:
            // Ball into net or out
            let isNetError = Bool.random()

            // Error maker stumbles
            loserAnimator?.showStaticFrame(.runDive, frameIndex: 2)

            if isNetError {
                let netPos = CourtRenderer.courtPoint(nx: 0.5, ny: 0.5)
                await animateBallArc(from: scene.ball.position, to: netPos, duration: 0.3, arcHeight: 5)
                await scene.showCallout("NET", at: netPos, color: .red)
            } else {
                let outX = Bool.random() ? AC.sceneWidth + 20 : -20
                let outPos = CGPoint(x: outX, y: scene.ball.position.y)
                await animateBallArc(from: scene.ball.position, to: outPos, duration: 0.3, arcHeight: T.arcPeak * 0.3)
                await scene.showCallout("OUT!", at: CGPoint(x: AC.sceneWidth / 2, y: scene.ball.position.y), color: .red)
            }

        case .forcedError:
            // Aggressive shot forces ball wide
            let wideX: CGFloat = Bool.random() ? AC.sceneWidth + 20 : -20
            let errorPos = CGPoint(x: wideX, y: scene.ball.position.y)

            // Winner hits forehand, loser dives
            winnerAnimator?.play(.forehand)
            await animateBallArc(from: scene.ball.position, to: errorPos, duration: 0.35, arcHeight: T.arcPeak * 0.5)

            loserAnimator?.showStaticFrame(.runDive, frameIndex: 3)
            winnerAnimator?.play(.celebrate)

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

            winnerAnimator?.play(.forehand)
            await animateBallArc(from: scene.ball.position, to: winPos, duration: 0.35, arcHeight: T.arcPeak * 0.5)

            spawnDustParticle(at: winPos)

            winnerAnimator?.play(.celebrate)

            if point.rallyLength >= 8 {
                await scene.showCallout("\(point.rallyLength) shots!", at: winPos, color: .cyan)
            }
        }
    }

    // MARK: - Ball Arc

    private func animateBallArc(from: CGPoint, to: CGPoint, duration: TimeInterval, arcHeight: CGFloat) async {
        guard let scene else { return }

        let steps = max(Int(duration / 0.016), 4)
        let dt = duration / Double(steps)

        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = from.x + (to.x - from.x) * t
            let baseY = from.y + (to.y - from.y) * t
            let arcOffset = arcHeight * sin(.pi * t)
            let y = baseY + arcOffset

            scene.ball.position = CGPoint(x: x, y: y)

            // Shadow stays on ground
            let shadowScale = 1.0 - (arcOffset / (arcHeight * 2))
            scene.ballShadow.position = CGPoint(x: x, y: baseY)
            scene.ballShadow.setScale(max(0.3, shadowScale))

            // Scale ball by perspective (use inverse mapping for correct depth)
            let ny = CourtRenderer.logicalNY(fromSceneY: baseY)
            let pScale = CourtRenderer.perspectiveScale(ny: ny)
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

        let winnerAnimator = winnerSide == .player ? scene.nearAnimator : scene.farAnimator
        let winnerNode = winnerSide == .player ? scene.nearPlayer! : scene.farPlayer!

        // Celebrate animation
        winnerAnimator?.play(.celebrate)

        await winnerNode.runAsync(
            .sequence([
                .moveBy(x: 0, y: 15, duration: 0.15),
                .moveBy(x: 0, y: -15, duration: 0.2)
            ])
        )

        await scene.showAnnouncement("Game Over")

        // Return to idle
        scene.nearAnimator?.stop()
        scene.farAnimator?.stop()
        scene.nearPartnerAnimator?.stop()
        scene.farPartnerAnimator?.stop()
    }

    private func animateMatchEnd(didPlayerWin: Bool) async {
        guard let scene else { return }

        let winnerNode = didPlayerWin ? scene.nearPlayer! : scene.farPlayer!
        let winnerAnimator = didPlayerWin ? scene.nearAnimator : scene.farAnimator

        // Winner celebration
        winnerAnimator?.play(.celebrate)

        let jumpAction = SKAction.sequence([
            .group([
                .moveBy(x: 0, y: 25, duration: 0.2),
                .scale(by: 1.15, duration: 0.2)
            ]),
            .group([
                .moveBy(x: 0, y: -25, duration: 0.25),
                .scale(by: 1.0 / 1.15, duration: 0.25)
            ])
        ])

        await winnerNode.runAsync(jumpAction)

        // In doubles, also celebrate with partner
        if scene.isDoubles {
            let winnerPartner = didPlayerWin ? scene.nearPartner : scene.farPartner
            let winnerPartnerAnimator = didPlayerWin ? scene.nearPartnerAnimator : scene.farPartnerAnimator

            winnerPartnerAnimator?.play(.celebrate)
            if let wp = winnerPartner {
                fireAction(wp, .sequence([
                    .group([
                        .moveBy(x: 0, y: 20, duration: 0.2),
                        .scale(by: 1.1, duration: 0.2)
                    ]),
                    .group([
                        .moveBy(x: 0, y: -20, duration: 0.25),
                        .scale(by: 1.0 / 1.1, duration: 0.25)
                    ])
                ]))
            }
        }

        let text = didPlayerWin ? "VICTORY!" : "DEFEAT"
        let color: UIColor = didPlayerWin ? .green : .red
        scene.announcementLabel.fontColor = color
        await scene.showAnnouncement(text)
        scene.announcementLabel.fontColor = .white
    }

    // MARK: - Action Animations

    private func animateTimeout(side: MatchSide) async {
        guard let scene else { return }

        let node = side == .player ? scene.nearPlayer! : scene.farPlayer!

        // Clock emoji callout
        let clock = SKLabelNode(text: "\u{23F0}")
        clock.fontSize = 24
        clock.position = CGPoint(x: node.position.x, y: node.position.y + 40)
        clock.zPosition = AC.ZPositions.effects
        scene.addChild(clock)

        await clock.runAsync(
            .sequence([
                .group([
                    .moveBy(x: 0, y: 20, duration: 0.5),
                    .scale(to: 1.5, duration: 0.3)
                ]),
                .fadeOut(withDuration: 0.3),
                .removeFromParent()
            ])
        )

        await scene.showCallout("TIMEOUT!", at: CGPoint(x: node.position.x, y: node.position.y + 50), color: .cyan)
    }

    private func animateConsumable(side: MatchSide, name: String) async {
        guard let scene else { return }

        let node = side == .player ? scene.nearPlayer! : scene.farPlayer!

        // Green sparkle ring
        let ring = SKShapeNode(circleOfRadius: 15)
        ring.fillColor = UIColor.green.withAlphaComponent(0.3)
        ring.strokeColor = UIColor.green.withAlphaComponent(0.7)
        ring.lineWidth = 2
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

        await scene.showCallout(name, at: CGPoint(x: node.position.x, y: node.position.y + 50), color: .green)
    }

    private func animateHookCall(side: MatchSide, success: Bool) async {
        guard let scene else { return }

        let node = side == .player ? scene.nearPlayer! : scene.farPlayer!

        // Flash effect
        let flash = SKShapeNode(rectOf: CGSize(width: AC.sceneWidth, height: AC.sceneHeight))
        flash.fillColor = success
            ? UIColor.yellow.withAlphaComponent(0.3)
            : UIColor.red.withAlphaComponent(0.3)
        flash.strokeColor = .clear
        flash.position = CGPoint(x: AC.sceneWidth / 2, y: AC.sceneHeight / 2)
        flash.zPosition = AC.ZPositions.effects
        scene.addChild(flash)

        await flash.runAsync(
            .sequence([
                .fadeOut(withDuration: 0.3),
                .removeFromParent()
            ])
        )

        let text = success ? "OVERTURNED!" : "CAUGHT!"
        let color: UIColor = success ? .yellow : .red
        await scene.showCallout(text, at: CGPoint(x: node.position.x, y: node.position.y + 50), color: color)
    }

    // MARK: - Side Out

    private func animateSideOut(newServingTeam: MatchSide, serverNumber: Int) async {
        guard let scene else { return }

        let text = "SIDE OUT!"
        await scene.showCallout(text, at: CGPoint(x: AC.sceneWidth / 2, y: AC.Court.courtBottomY + AC.Court.courtHeight / 2), color: .cyan)
    }

    // MARK: - Fire-and-forget SKAction helper (sync call to avoid async hop)

    nonisolated private func fireAction(_ node: SKNode, _ action: sending SKAction) {
        MainActor.assumeIsolated {
            node.run(action)
        }
    }

    // MARK: - Particles

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
