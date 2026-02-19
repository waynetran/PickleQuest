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
        // Diagnostic: error source breakdown
        let playerErrorsFromShouldMake: Int
        let npcErrorsFromShouldMake: Int
        let playerNetErrors: Int
        let npcNetErrors: Int
        let playerOutErrors: Int
        let npcOutErrors: Int
        // Physics-based out errors (regular shots that land out, not shouldMakeError)
        let playerPhysicsOut: Int
        let npcPhysicsOut: Int
        // Directional breakdown of physics out errors
        let playerOutLong: Int
        let npcOutLong: Int
        let playerOutWide: Int
        let npcOutWide: Int
        // Kitchen faults
        let playerKitchenFaults: Int
        let npcKitchenFaults: Int
        // Serve position diagnostics
        let playerServeFootFaults: Int
        let npcServeFootFaults: Int
        let playerTwoBounceViolations: Int
        let npcTwoBounceViolations: Int
        // Serve position aggregates (NY at serve time)
        let avgPlayerServeNY: Double
        let avgNPCServeNY: Double
        let avgPlayerReceiveNY: Double
        let avgNPCReceiveNY: Double
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
    // Diagnostic breakdown
    private var playerErrorsFromShouldMake: Int = 0
    private var npcErrorsFromShouldMake: Int = 0
    private var playerNetErrors: Int = 0
    private var npcNetErrors: Int = 0
    private var playerOutErrors: Int = 0
    private var npcOutErrors: Int = 0
    // Sub-classification: physics-based out errors (from regular shots, not shouldMakeError)
    private var playerPhysicsOut: Int = 0
    private var npcPhysicsOut: Int = 0
    // Directional: out-long (Y past baseline) vs out-wide (X past sideline)
    private var playerOutLong: Int = 0
    private var npcOutLong: Int = 0
    private var playerOutWide: Int = 0
    private var npcOutWide: Int = 0
    // Kitchen fault tracking
    private var playerKitchenFaults: Int = 0
    private var npcKitchenFaults: Int = 0
    // Serve position / rule violation tracking
    private var playerServeFootFaults: Int = 0
    private var npcServeFootFaults: Int = 0
    private var playerTwoBounceViolations: Int = 0
    private var npcTwoBounceViolations: Int = 0
    private var totalPlayerServeNY: CGFloat = 0
    private var totalNPCServeNY: CGFloat = 0
    private var totalPlayerReceiveNY: CGFloat = 0
    private var totalNPCReceiveNY: CGFloat = 0
    private var playerServeCount: Int = 0
    private var npcServeCount: Int = 0

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

    init(npc: NPC, playerStats: PlayerStats, playerDUPR: Double, params: SimulationParameters? = nil) {
        let npcScale = params?.moveSpeedScale(dupr: npc.duprRating)
        let playerScale = params?.moveSpeedScale(dupr: playerDUPR)
        self.npcAI = MatchAI(npc: npc, playerDUPR: playerDUPR, headless: true, moveSpeedScale: npcScale)
        self.playerAI = SimulatedPlayerAI(stats: playerStats, dupr: playerDUPR, moveSpeedScale: playerScale)
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
        playerErrorsFromShouldMake = 0
        npcErrorsFromShouldMake = 0
        playerNetErrors = 0
        npcNetErrors = 0
        playerOutErrors = 0
        npcOutErrors = 0
        playerPhysicsOut = 0
        npcPhysicsOut = 0
        playerOutLong = 0
        npcOutLong = 0
        playerOutWide = 0
        npcOutWide = 0
        playerKitchenFaults = 0
        npcKitchenFaults = 0
        playerServeFootFaults = 0
        npcServeFootFaults = 0
        playerTwoBounceViolations = 0
        npcTwoBounceViolations = 0
        totalPlayerServeNY = 0
        totalNPCServeNY = 0
        totalPlayerReceiveNY = 0
        totalNPCReceiveNY = 0
        playerServeCount = 0
        npcServeCount = 0

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
            npcErrors: npcErrors,
            playerErrorsFromShouldMake: playerErrorsFromShouldMake,
            npcErrorsFromShouldMake: npcErrorsFromShouldMake,
            playerNetErrors: playerNetErrors,
            npcNetErrors: npcNetErrors,
            playerOutErrors: playerOutErrors,
            npcOutErrors: npcOutErrors,
            playerPhysicsOut: playerPhysicsOut,
            npcPhysicsOut: npcPhysicsOut,
            playerOutLong: playerOutLong,
            npcOutLong: npcOutLong,
            playerOutWide: playerOutWide,
            npcOutWide: npcOutWide,
            playerKitchenFaults: playerKitchenFaults,
            npcKitchenFaults: npcKitchenFaults,
            playerServeFootFaults: playerServeFootFaults,
            npcServeFootFaults: npcServeFootFaults,
            playerTwoBounceViolations: playerTwoBounceViolations,
            npcTwoBounceViolations: npcTwoBounceViolations,
            avgPlayerServeNY: playerServeCount > 0 ? Double(totalPlayerServeNY) / Double(playerServeCount) : 0,
            avgNPCServeNY: npcServeCount > 0 ? Double(totalNPCServeNY) / Double(npcServeCount) : 0,
            avgPlayerReceiveNY: npcServeCount > 0 ? Double(totalPlayerReceiveNY) / Double(npcServeCount) : 0,
            avgNPCReceiveNY: playerServeCount > 0 ? Double(totalNPCReceiveNY) / Double(playerServeCount) : 0
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

        // Record serve positions and check for foot faults
        // Player baseline = Y=0, NPC baseline = Y=1.0
        // Server must be at or behind their baseline (player NY <= baseline, NPC NY >= baseline)
        let playerBaselineNY: CGFloat = 0.0
        let npcBaselineNY: CGFloat = 1.0
        let footFaultTolerance: CGFloat = 0.01 // small tolerance for floating point

        if servingSide == .player {
            playerServeCount += 1
            totalPlayerServeNY += playerAI.currentNY
            totalNPCReceiveNY += npcAI.currentNY
            // Foot fault: player serving from too far inside the court
            if playerAI.currentNY > playerBaselineNY + footFaultTolerance {
                playerServeFootFaults += 1
            }
        } else {
            npcServeCount += 1
            totalNPCServeNY += npcAI.currentNY
            totalPlayerReceiveNY += playerAI.currentNY
            // Foot fault: NPC serving from too far inside the court
            if npcAI.currentNY < npcBaselineNY - footFaultTolerance {
                npcServeFootFaults += 1
            }
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

                // Early rally bounce: teleport receiver to the ball's actual landing
                // position. In real pickleball, the first few shots (serve and
                // return) are expected and tracked visually. Receivers always
                // reach the ball. The shouldMakeError check still applies
                // (error on contact), so the return can still fail.
                if rallyLength <= 1 {
                    let bx = max(0.05, min(0.95, firstBounceCourtX))
                    let by = firstBounceCourtY
                    if ballSim.lastHitByPlayer {
                        npcAI.currentNX = bx
                        npcAI.currentNY = max(0.72, min(1.0, by))
                        npcAI.serveTargetHint = CGPoint(x: bx, y: by)
                    } else {
                        playerAI.currentNX = bx
                        playerAI.currentNY = max(0.0, min(0.28, by))
                        playerAI.serveTargetHint = CGPoint(x: bx, y: by)
                    }
                }
            }

            playerAI.update(dt: dt, ball: ballSim)
            npcAI.playerPositionNX = playerAI.currentNX
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

    /// Shared serve logic for both sides — ensures perfect symmetry.
    /// `serverStats`: the serving player's stats.
    /// `score`: the server's current score (determines serve side).
    /// `originNY`: the server's baseline Y position.
    /// `targetBaseNY`: where good serves land (0.85 for player→NPC, 0.15 for NPC→player).
    /// `faultNYRange`: where faults land (kitchen zone on the receiving side).
    /// `isPlayerServing`: which side hit the ball.
    private func executeServe(
        shot: DrillShotCalculator.ShotResult,
        serverStats: PlayerStats,
        score: Int,
        originX: CGFloat,
        originNY: CGFloat,
        targetBaseNY: CGFloat,
        faultNYRange: ClosedRange<CGFloat>,
        isPlayerServing: Bool
    ) {
        // Fault check
        let consistencyStat = CGFloat(serverStats.stat(.consistency))
        let accuracyStat = CGFloat(serverStats.stat(.accuracy))
        let serveStat = (consistencyStat + accuracyStat) / 2.0
        let baseFaultRate = P.npcBaseServeFaultRate * (1.0 - serveStat / 99.0)
        let isDoubleFault = CGFloat.random(in: 0...1) < baseFaultRate

        // Cross-court serve: target opposite X from serve position
        let evenScore = score % 2 == 0
        let baseTargetNX: CGFloat = evenScore ? 0.25 : 0.75

        // Scatter from stats
        let focusStat = CGFloat(serverStats.stat(.focus))
        let scatterReduction = ((accuracyStat + focusStat) / 2.0) / 99.0
        let scatter = (1.0 - scatterReduction * 0.7) * 0.15
        let scatterX = CGFloat.random(in: -scatter...scatter)
        let scatterY = CGFloat.random(in: -scatter...scatter)

        let serveTargetNX = max(0.15, min(0.85, baseTargetNX + scatterX))
        let serveTargetNY: CGFloat
        if isDoubleFault {
            serveTargetNY = CGFloat.random(in: faultNYRange)
        } else {
            // Target deep in service box, with scatter
            let minNY = min(targetBaseNY - 0.12, targetBaseNY + 0.12)
            let maxNY = max(targetBaseNY - 0.12, targetBaseNY + 0.12)
            serveTargetNY = max(minNY, min(maxNY, targetBaseNY + scatterY))
        }

        // Cap serve power — pickleball serves are underhand and much slower than rally drives
        let servePower = min(P.servePowerCap, shot.power)

        let serveDistNX = abs(serveTargetNX - originX)
        let serveDistNY = abs(serveTargetNY - originNY)
        let serveArc = DrillShotCalculator.arcToLandAt(
            distanceNY: serveDistNY,
            distanceNX: serveDistNX,
            power: servePower,
            arcMargin: 1.0  // ensureNetClearance() handles net safety
        )

        ballSim.launch(
            from: CGPoint(x: originX, y: originNY),
            toward: CGPoint(x: serveTargetNX, y: serveTargetNY),
            power: servePower,
            arc: serveArc,
            spin: shot.spinCurve,
            topspin: shot.topspinFactor
        )
        ballSim.lastHitByPlayer = isPlayerServing
        previousBallNY = ballSim.courtY

        // Set serve tracking hint so receiver skips reaction delay and
        // tracks toward the landing zone. The bounce teleport (in the game
        // loop) handles final positioning when the ball actually lands.
        let hint = CGPoint(x: serveTargetNX, y: serveTargetNY)
        if isPlayerServing {
            npcAI.serveTargetHint = hint
        } else {
            playerAI.serveTargetHint = hint
        }
    }

    private func executePlayerServe() {
        let shot = playerAI.generateServe(playerScore: playerScore)
        executeServe(
            shot: shot,
            serverStats: playerAI.stats,
            score: playerScore,
            originX: playerAI.currentNX,
            originNY: playerAI.currentNY,
            targetBaseNY: 0.85,             // deep into NPC side
            faultNYRange: 0.52...0.66,      // kitchen zone on NPC side
            isPlayerServing: true
        )
    }

    private func executeNPCServe() {
        let shot = npcAI.generateServe(npcScore: npcScore)
        executeServe(
            shot: shot,
            serverStats: npcAI.npcStats,
            score: npcScore,
            originX: npcAI.currentNX,
            originNY: npcAI.currentNY,
            targetBaseNY: 0.15,             // deep into player side
            faultNYRange: 0.35...0.48,      // kitchen zone on player side
            isPlayerServing: false
        )
    }

    // MARK: - Hit Detection (returns true if point ended)

    private func checkPlayerHit() -> Bool {
        // Two-bounce rule: return of serve and 3rd shot must bounce first
        if rallyLength < 2 && ballSim.bounceCount == 0 { return false }

        guard playerAI.canHit(ball: ballSim) else { return false }

        // Pre-select shot modes for error context
        let shotModes = playerAI.selectShotModes(ball: ballSim)

        // Symmetric error system — resolve immediately without launching a ball.
        // Previously, error balls were launched with physics (net errors got
        // boosted over the net by ensureNetClearance, creating extra rallies
        // that generated asymmetric out errors). Now errors are purely statistical.
        if playerAI.shouldMakeError(ball: ballSim, npcDUPR: npcAI.npcDUPR) {
            playerErrors += 1
            playerErrorsFromShouldMake += 1
            rallyLength += 1

            let errType = playerAI.errorType(for: shotModes)
            switch errType {
            case .net:
                playerNetErrors += 1
            case .long, .wide:
                playerOutErrors += 1
            }
            resolvePoint(.npcWon)
            return true
        }

        rallyLength += 1

        // Set shot context for NPC assessment
        npcAI.lastPlayerShotModes = shotModes
        npcAI.lastPlayerHitBallHeight = ballSim.height
        let pBallSpeed = sqrt(ballSim.vx * ballSim.vx + ballSim.vy * ballSim.vy)
        let pMaxSpeed = P.baseShotSpeed + 2.0 * (P.maxShotSpeed - P.baseShotSpeed)
        let pSpeedFrac = max(0, min(1, (pBallSpeed - P.baseShotSpeed) / (pMaxSpeed - P.baseShotSpeed)))
        let dx = ballSim.courtX - playerAI.currentNX
        let dy = ballSim.courtY - playerAI.currentNY
        let pDist = sqrt(dx * dx + dy * dy)
        let pStretch = min(pDist / playerAI.hitboxRadius, 1.0)
        npcAI.lastPlayerHitDifficulty = pSpeedFrac * 0.5 + pStretch * 0.5

        let shot = playerAI.generateShot(ball: ballSim)

        ballSim.launch(
            from: CGPoint(x: playerAI.currentNX, y: playerAI.currentNY),
            toward: CGPoint(x: shot.targetNX, y: shot.targetNY),
            power: shot.power,
            arc: shot.arc,
            spin: shot.spinCurve,
            topspin: shot.topspinFactor
        )
        ballSim.smashFactor = shot.smashFactor
        ballSim.isPutAway = shot.isPutAway
        ballSim.lastHitByPlayer = true
        previousBallNY = ballSim.courtY
        checkedFirstBounce = false

        // Push player shot X to NPC pattern memory (keep last 5)
        npcAI.playerShotHistory.append(shot.targetNX)
        if npcAI.playerShotHistory.count > 5 {
            npcAI.playerShotHistory.removeFirst()
        }

        // Early rally: give the NPC a tracking hint for the next shot.
        if rallyLength <= 2 {
            npcAI.serveTargetHint = CGPoint(x: shot.targetNX, y: shot.targetNY)
        }

        return false
    }

    private func checkNPCHit() -> Bool {
        guard ballSim.isActive && ballSim.lastHitByPlayer else { return false }
        guard ballSim.bounceCount < 2 else { return false }

        // Two-bounce rule
        if rallyLength < 2 && ballSim.bounceCount == 0 { return false }

        guard npcAI.shouldSwing(ball: ballSim) else { return false }

        // Pre-select modes so error type is context-aware
        npcAI.preselectModes(ball: ballSim)

        // Error check — resolve immediately (symmetric with player error handling)
        if npcAI.shouldMakeError(ball: ballSim) {
            npcErrors += 1
            npcErrorsFromShouldMake += 1
            rallyLength += 1

            let errType = npcAI.errorType(for: npcAI.lastShotModes)
            switch errType {
            case .net:
                npcNetErrors += 1
            case .long, .wide:
                npcOutErrors += 1
            }
            resolvePoint(.playerWon)
            return true
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
        ballSim.smashFactor = shot.smashFactor
        ballSim.isPutAway = shot.isPutAway
        ballSim.lastHitByPlayer = false
        previousBallNY = ballSim.courtY
        checkedFirstBounce = false

        // Early rally: give the server a tracking hint for the return shot.
        // In real pickleball, the server watches the return and starts moving
        // immediately — no reaction delay needed for expected shots.
        if rallyLength <= 2 {
            playerAI.serveTargetHint = CGPoint(x: shot.targetNX, y: shot.targetNY)
        }

        return false
    }

    // MARK: - Ball State (returns true if point ended)

    private func checkBallState() -> Bool {
        guard ballSim.isActive else { return false }

        // Net collision
        if ballSim.checkNetCollision(previousY: previousBallNY) {
            if ballSim.lastHitByPlayer {
                playerNetErrors += 1
                playerErrors += 1
                resolvePoint(.npcWon)
            } else {
                npcNetErrors += 1
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
                let bx = ballSim.lastBounceCourtX
                let by = ballSim.lastBounceCourtY
                let isLong = by < 0.0 || by > 1.0
                if ballSim.lastHitByPlayer {
                    playerOutErrors += 1
                    playerPhysicsOut += 1
                    if isLong { playerOutLong += 1 } else { playerOutWide += 1 }
                    playerErrors += 1
                    resolvePoint(.npcWon)
                } else {
                    npcOutErrors += 1
                    npcPhysicsOut += 1
                    if isLong { npcOutLong += 1 } else { npcOutWide += 1 }
                    npcErrors += 1
                    resolvePoint(.playerWon)
                }
                _ = bx // suppress unused warning
                return true
            }

            // Serve kitchen fault
            if rallyLength == 0 {
                let kitchenNear: CGFloat = 0.318
                let kitchenFar: CGFloat = 0.682
                if ballSim.lastHitByPlayer && firstBounceCourtY >= 0.5 && firstBounceCourtY < kitchenFar {
                    playerErrors += 1
                    playerKitchenFaults += 1
                    resolvePoint(.npcWon)
                    return true
                }
                if !ballSim.lastHitByPlayer && firstBounceCourtY <= 0.5 && firstBounceCourtY > kitchenNear {
                    npcErrors += 1
                    npcKitchenFaults += 1
                    resolvePoint(.playerWon)
                    return true
                }
            }
        }

        // Double bounce
        if ballSim.isDoubleBounce {
            let bounceY = ballSim.lastBounceCourtY
            let bounceX = ballSim.lastBounceCourtX
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
            let isLong = ballSim.courtY < -0.5 || ballSim.courtY > 1.5
            if ballSim.lastHitByPlayer {
                playerOutErrors += 1
                playerPhysicsOut += 1
                if isLong { playerOutLong += 1 } else { playerOutWide += 1 }
                playerErrors += 1
                resolvePoint(.npcWon)
            } else {
                npcOutErrors += 1
                npcPhysicsOut += 1
                if isLong { npcOutLong += 1 } else { npcOutWide += 1 }
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
