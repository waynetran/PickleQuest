import CoreGraphics

/// Headless version of the interactive match engine.
/// Runs the same physics, AI, and shot mechanics as `InteractiveMatchScene`
/// without SpriteKit rendering. Each instance owns its own components — not Sendable.
final class HeadlessMatchSimulator {
    private typealias P = GameConstants.DrillPhysics
    private typealias PB = GameConstants.PlayerBalance
    private typealias IM = GameConstants.InteractiveMatch
    private typealias S = GameConstants.NPCStrategy

    // MARK: - Result

    struct MatchResult: Sendable {
        let winnerSide: MatchSide
        let playerScore: Int
        let opponentScore: Int
        let totalRallies: Int
        let totalRallyShots: Int
        let avgRallyLength: Double
        let playerAces: Int
        let playerWinners: Int
        let playerErrors: Int
        let npcAces: Int
        let npcWinners: Int
        let npcErrors: Int
    }

    // MARK: - Components

    private let ballSim = DrillBallSimulation()
    private let npcAI: MatchAI
    private let playerAI: SimulatedPlayerAI

    // MARK: - Match State

    private var playerScore: Int = 0
    private var npcScore: Int = 0
    private var servingSide: MatchSide = .player
    private var rallyLength: Int = 0
    private var totalPointsPlayed: Int = 0
    private var totalRallyShots: Int = 0

    // Stats
    private var playerAces: Int = 0
    private var playerWinners: Int = 0
    private var playerErrors: Int = 0
    private var npcAces: Int = 0
    private var npcWinners: Int = 0
    private var npcErrors: Int = 0

    // First bounce tracking
    private var firstBounceCourtX: CGFloat = 0.5
    private var firstBounceCourtY: CGFloat = 0.5
    private var checkedFirstBounce: Bool = false

    // Physics
    private var previousBallNY: CGFloat = 0.5

    // Constants
    private let dt: CGFloat = 1.0 / 120.0
    private let maxPointTime: CGFloat = 30.0

    // MARK: - Init

    init(npc: NPC, playerStats: PlayerStats, playerDUPR: Double) {
        self.npcAI = MatchAI(npc: npc, playerDUPR: playerDUPR)
        self.playerAI = SimulatedPlayerAI(stats: playerStats, dupr: playerDUPR)
    }

    // MARK: - Simulate Match

    func simulateMatch() -> MatchResult {
        playerScore = 0
        npcScore = 0
        servingSide = .player
        totalPointsPlayed = 0
        totalRallyShots = 0
        playerAces = 0
        playerWinners = 0
        playerErrors = 0
        npcAces = 0
        npcWinners = 0
        npcErrors = 0

        while !isMatchOver() {
            simulatePoint()
        }

        let winnerSide: MatchSide = playerScore > npcScore ? .player : .opponent
        let avgRally = totalPointsPlayed > 0
            ? Double(totalRallyShots) / Double(totalPointsPlayed)
            : 0

        return MatchResult(
            winnerSide: winnerSide,
            playerScore: playerScore,
            opponentScore: npcScore,
            totalRallies: totalPointsPlayed,
            totalRallyShots: totalRallyShots,
            avgRallyLength: avgRally,
            playerAces: playerAces,
            playerWinners: playerWinners,
            playerErrors: playerErrors,
            npcAces: npcAces,
            npcWinners: npcWinners,
            npcErrors: npcErrors
        )
    }

    // MARK: - Point Simulation

    private func simulatePoint() {
        // Reset state
        rallyLength = 0
        ballSim.reset()
        checkedFirstBounce = false
        playerAI.reset(isServing: servingSide == .player, playerScore: playerScore, npcScore: npcScore)
        npcAI.reset(npcScore: npcScore, isServing: servingSide == .opponent)
        if servingSide == .opponent {
            npcAI.positionForServe(npcScore: npcScore)
            playerAI.positionForReceive(npcScore: npcScore)
        } else {
            playerAI.positionForServe(playerScore: playerScore)
            npcAI.positionForReceive(playerScore: playerScore)
        }

        // Execute serve
        if servingSide == .player {
            executePlayerServe()
        } else {
            executeNPCServe()
        }

        // Run game loop
        var elapsed: CGFloat = 0
        while ballSim.isActive && elapsed < maxPointTime {
            let prevBounces = ballSim.bounceCount
            previousBallNY = ballSim.courtY

            ballSim.update(dt: dt)

            // Record first bounce position
            if ballSim.didBounceThisFrame && prevBounces == 0 {
                firstBounceCourtX = ballSim.lastBounceCourtX
                firstBounceCourtY = ballSim.lastBounceCourtY
            }

            playerAI.update(dt: dt, ball: ballSim)
            npcAI.update(dt: dt, ball: ballSim)

            if checkPlayerHit() { break }
            if checkNPCHit() { break }
            if checkBallState() { break }

            elapsed += dt
        }

        // Safety: if ball still active after timeout, give point to last hitter's opponent
        if ballSim.isActive {
            let result: PointResult = ballSim.lastHitByPlayer ? .npcWon : .playerWon
            resolvePoint(result)
        }
    }

    // MARK: - Serve

    private func executePlayerServe() {
        let shot = playerAI.generateServe(playerScore: playerScore)

        // Service box target (0.682 kitchen far to ~0.95 baseline far)
        let evenScore = playerScore % 2 == 0
        let targetNX = evenScore ? 0.75 : 0.25

        // Scatter from stats
        let accuracyStat = CGFloat(playerAI.stats.stat(.accuracy))
        let focusStat = CGFloat(playerAI.stats.stat(.focus))
        let scatterReduction = ((accuracyStat + focusStat) / 2.0) / 99.0
        let scatter = (1.0 - scatterReduction * 0.7) * 0.15
        let scatterX = CGFloat.random(in: -scatter...scatter)
        let scatterY = CGFloat.random(in: -scatter...scatter)

        let serveTargetNX = max(0.15, min(0.85, CGFloat(targetNX) + scatterX))
        let serveTargetNY = max(0.73, min(0.97, 0.85 + scatterY))

        let serveDistNY = abs(serveTargetNY - playerAI.currentNY)
        let serveArc = DrillShotCalculator.arcToLandAt(
            distanceNY: serveDistNY,
            power: shot.power,
            arcMargin: 1.30
        )

        ballSim.launch(
            from: CGPoint(x: playerAI.currentNX, y: playerAI.currentNY),
            toward: CGPoint(x: serveTargetNX, y: serveTargetNY),
            power: shot.power,
            arc: serveArc,
            spin: shot.spinCurve,
            topspin: shot.topspinFactor
        )
        ballSim.lastHitByPlayer = true
        previousBallNY = ballSim.courtY
    }

    private func executeNPCServe() {
        let shot = npcAI.generateServe(npcScore: npcScore)

        // Double fault check (mirrors InteractiveMatchScene.npcServe)
        let consistencyStat = CGFloat(min(99, npcAI.npcStats.stat(.consistency) + P.npcStatBoost))
        let accuracyStat = CGFloat(min(99, npcAI.npcStats.stat(.accuracy) + P.npcStatBoost))
        let serveStat = (consistencyStat + accuracyStat) / 2.0
        let baseFaultRate = P.npcBaseServeFaultRate * (1.0 - serveStat / 99.0)

        let modes = npcAI.lastServeModes
        var rawPenalty: CGFloat = 0
        if modes.contains(.power) { rawPenalty += S.npcServePowerFaultPenalty }
        if modes.contains(.topspin) || modes.contains(.slice) { rawPenalty += S.npcServeSpinFaultPenalty }
        let controlFactor = pow(1.0 - npcAI.strategy.aggressionControl, S.npcServeControlExponent)
        let modePenalty = rawPenalty * controlFactor

        let faultRate = baseFaultRate + modePenalty
        let isDoubleFault = CGFloat.random(in: 0...1) < faultRate

        let evenScore = npcScore % 2 == 0
        let targetNX: CGFloat = evenScore ? 0.25 : 0.75
        let targetNY: CGFloat
        if isDoubleFault {
            targetNY = CGFloat.random(in: 0.35...0.48)
        } else {
            targetNY = CGFloat.random(in: 0.05...0.28)
        }

        let serveDistNY = abs(npcAI.currentNY - targetNY)
        let serveArc = DrillShotCalculator.arcToLandAt(
            distanceNY: serveDistNY,
            power: shot.power,
            arcMargin: 1.30
        )

        ballSim.launch(
            from: CGPoint(x: npcAI.currentNX, y: npcAI.currentNY),
            toward: CGPoint(x: targetNX, y: targetNY),
            power: shot.power,
            arc: serveArc,
            spin: shot.spinCurve
        )
        ballSim.lastHitByPlayer = false
        previousBallNY = ballSim.courtY
    }

    // MARK: - Hit Detection (returns true if point ended)

    private func checkPlayerHit() -> Bool {
        guard playerAI.canHit(ball: ballSim) else { return false }

        // Forced error
        if playerAI.shouldCommitForcedError(ball: ballSim, npcDUPR: npcAI.npcDUPR) {
            playerErrors += 1
            return false // ball continues — will double-bounce or go out
        }

        // Two-bounce rule: return of serve and 3rd shot must be off the bounce
        if rallyLength < 2 && ballSim.bounceCount == 0 {
            playerErrors += 1
            resolvePoint(.npcWon)
            return true
        }

        rallyLength += 1

        // Set shot context for NPC assessment
        npcAI.lastPlayerShotModes = playerAI.selectShotModes(ball: ballSim)
        npcAI.lastPlayerHitBallHeight = ballSim.height
        let pBallSpeed = sqrt(ballSim.vx * ballSim.vx + ballSim.vy * ballSim.vy)
        let pMaxSpeed = P.baseShotSpeed + 2.0 * (P.maxShotSpeed - P.baseShotSpeed)
        let pSpeedFrac = max(0, min(1, (pBallSpeed - P.baseShotSpeed) / (pMaxSpeed - P.baseShotSpeed)))
        let dx = ballSim.courtX - playerAI.currentNX
        let dy = ballSim.courtY - playerAI.currentNY
        let pDist = sqrt(dx * dx + dy * dy)
        let pStretch = min(pDist / playerAI.hitboxRadius, 1.0)
        npcAI.lastPlayerHitDifficulty = pSpeedFrac * 0.5 + pStretch * 0.5

        var shot = playerAI.generateShot(ball: ballSim)

        // Net fault
        if playerAI.shouldCommitNetFault() {
            ballSim.skipNetCorrection = true
            shot.arc *= 0.15
        }

        ballSim.launch(
            from: CGPoint(x: playerAI.currentNX, y: playerAI.currentNY),
            toward: CGPoint(x: shot.targetNX, y: shot.targetNY),
            power: shot.power,
            arc: shot.arc,
            spin: shot.spinCurve,
            topspin: shot.topspinFactor
        )
        ballSim.lastHitByPlayer = true
        previousBallNY = ballSim.courtY
        checkedFirstBounce = false

        return false
    }

    private func checkNPCHit() -> Bool {
        guard ballSim.isActive && ballSim.lastHitByPlayer else { return false }
        guard ballSim.bounceCount < 2 else { return false }
        guard ballSim.height < 0.20 else { return false }

        // Two-bounce rule
        if rallyLength < 2 && ballSim.bounceCount == 0 { return false }

        guard npcAI.shouldSwing(ball: ballSim) else { return false }

        // Error check
        if npcAI.shouldMakeError(ball: ballSim) {
            npcErrors += 1
            rallyLength += 1

            // Error ball: 50% net, 50% out (mirrors InteractiveMatchScene)
            if Bool.random() {
                ballSim.launch(
                    from: CGPoint(x: npcAI.currentNX, y: npcAI.currentNY),
                    toward: CGPoint(x: CGFloat.random(in: 0.2...0.8), y: 0.3),
                    power: 0.25,
                    arc: 0.02,
                    spin: 0
                )
            } else {
                let wideTarget = Bool.random()
                    ? CGFloat.random(in: -0.2...0.05)
                    : CGFloat.random(in: 0.95...1.2)
                ballSim.launch(
                    from: CGPoint(x: npcAI.currentNX, y: npcAI.currentNY),
                    toward: CGPoint(x: wideTarget, y: CGFloat.random(in: 0.0...0.15)),
                    power: 0.8,
                    arc: 0.15,
                    spin: 0
                )
            }
            ballSim.lastHitByPlayer = false
            previousBallNY = ballSim.courtY
            return false
        }

        rallyLength += 1
        let shot = npcAI.generateShot(ball: ballSim)

        ballSim.launch(
            from: CGPoint(x: npcAI.currentNX, y: npcAI.currentNY),
            toward: CGPoint(x: shot.targetNX, y: shot.targetNY),
            power: shot.power,
            arc: shot.arc,
            spin: shot.spinCurve,
            topspin: shot.topspinFactor
        )
        ballSim.lastHitByPlayer = false
        previousBallNY = ballSim.courtY
        checkedFirstBounce = false

        return false
    }

    // MARK: - Ball State (returns true if point ended)

    private func checkBallState() -> Bool {
        guard ballSim.isActive else { return false }

        // Net collision
        if ballSim.checkNetCollision(previousY: previousBallNY) {
            if ballSim.lastHitByPlayer {
                playerErrors += 1
                resolvePoint(.npcWon)
            } else {
                npcErrors += 1
                resolvePoint(.playerWon)
            }
            return true
        }

        // Bounce-time line call
        if ballSim.didBounceThisFrame && !checkedFirstBounce {
            checkedFirstBounce = true

            // Out of bounds
            if ballSim.isLandingOut {
                if ballSim.lastHitByPlayer {
                    playerErrors += 1
                    resolvePoint(.npcWon)
                } else {
                    npcErrors += 1
                    resolvePoint(.playerWon)
                }
                return true
            }

            // Serve kitchen fault
            if rallyLength == 0 {
                let kitchenNear: CGFloat = 0.318
                let kitchenFar: CGFloat = 0.682
                if ballSim.lastHitByPlayer && firstBounceCourtY >= 0.5 && firstBounceCourtY < kitchenFar {
                    playerErrors += 1
                    resolvePoint(.npcWon)
                    return true
                }
                if !ballSim.lastHitByPlayer && firstBounceCourtY <= 0.5 && firstBounceCourtY > kitchenNear {
                    npcErrors += 1
                    resolvePoint(.playerWon)
                    return true
                }
            }
        }

        // Double bounce
        if ballSim.isDoubleBounce {
            let bounceY = ballSim.lastBounceCourtY
            if bounceY < 0.5 {
                // Double-bounced on player's side
                if ballSim.lastHitByPlayer {
                    playerErrors += 1
                } else {
                    if rallyLength <= 1 { npcAces += 1 } else { npcWinners += 1 }
                }
                resolvePoint(.npcWon)
            } else {
                // Double-bounced on NPC's side
                if ballSim.lastHitByPlayer {
                    if rallyLength <= 1 { playerAces += 1 } else { playerWinners += 1 }
                } else {
                    npcErrors += 1
                }
                resolvePoint(.playerWon)
            }
            return true
        }

        // Out of bounds (safety)
        if ballSim.isOutOfBounds {
            if ballSim.lastHitByPlayer {
                playerErrors += 1
                resolvePoint(.npcWon)
            } else {
                npcErrors += 1
                resolvePoint(.playerWon)
            }
            return true
        }

        // Stalled
        if ballSim.isStalled {
            if ballSim.lastHitByPlayer {
                playerErrors += 1
                resolvePoint(.npcWon)
            } else {
                npcErrors += 1
                resolvePoint(.playerWon)
            }
            return true
        }

        return false
    }

    // MARK: - Point Resolution

    private enum PointResult {
        case playerWon
        case npcWon
    }

    private func resolvePoint(_ result: PointResult) {
        ballSim.reset()
        totalPointsPlayed += 1
        totalRallyShots += rallyLength

        switch result {
        case .playerWon:
            if servingSide == .player {
                playerScore += 1
            } else {
                servingSide = .player
            }
        case .npcWon:
            if servingSide == .opponent {
                npcScore += 1
            } else {
                servingSide = .opponent
            }
        }

        playerAI.recoverBetweenPoints()
        npcAI.recoverBetweenPoints()
    }

    // MARK: - Match Over

    private func isMatchOver() -> Bool {
        let ptsToWin = IM.pointsToWin
        let margin = IM.winByMargin

        if playerScore >= ptsToWin && playerScore - npcScore >= margin { return true }
        if npcScore >= ptsToWin && npcScore - playerScore >= margin { return true }

        // Sudden death at max score
        if playerScore >= IM.maxScore && npcScore >= IM.maxScore {
            return playerScore != npcScore
        }

        return false
    }
}
