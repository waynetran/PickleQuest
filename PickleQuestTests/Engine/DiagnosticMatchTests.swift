import Testing
import Foundation
import CoreGraphics
@testable import PickleQuest

/// Full-physics diagnostic match between two AI players with shot-by-shot logging.
/// Replicates HeadlessMatchSimulator's exact game loop but prints detailed debug
/// info at every decision point — serves, hits, errors, bounces, ball state, and positions.
@Suite("Diagnostic Match")
struct DiagnosticMatchTests {

    private typealias P = GameConstants.DrillPhysics
    private typealias IM = GameConstants.InteractiveMatch

    // MARK: - Configurable Test

    /// Run a single diagnostic match between two DUPR levels with full logging.
    /// Change these values to test different matchups.
    @Test func diagnosticMatch() {
        let playerDUPR: Double = 4.0
        let npcDUPR: Double = 2.5

        let result = runDiagnosticMatch(playerDUPR: playerDUPR, npcDUPR: npcDUPR)

        print("""

        ═══════════════════════════════════════════════
         FINAL RESULT: \(result.winnerSide == .player ? "PLAYER" : "NPC") WINS  \(result.playerScore)-\(result.opponentScore)
        ═══════════════════════════════════════════════
         Points played: \(result.totalRallies)
         Avg rally length: \(String(format: "%.1f", result.avgRallyLength))
         Player: aces=\(result.playerAces) winners=\(result.playerWinners) errors=\(result.playerErrors)
           shouldMakeErrors=\(result.playerErrorsFromShouldMake) net=\(result.playerNetErrors) out=\(result.playerOutErrors) physOut=\(result.playerPhysicsOut)
           outLong=\(result.playerOutLong) outWide=\(result.playerOutWide) kitchenFault=\(result.playerKitchenFaults)
         NPC:    aces=\(result.npcAces) winners=\(result.npcWinners) errors=\(result.npcErrors)
           shouldMakeErrors=\(result.npcErrorsFromShouldMake) net=\(result.npcNetErrors) out=\(result.npcOutErrors) physOut=\(result.npcPhysicsOut)
           outLong=\(result.npcOutLong) outWide=\(result.npcOutWide) kitchenFault=\(result.npcKitchenFaults)
        ═══════════════════════════════════════════════
        """)

        #expect(result.totalRallies > 0, "Match should play at least one point")
    }

    // MARK: - Diagnostic Match Runner

    struct DiagnosticResult {
        let winnerSide: MatchSide
        let playerScore: Int
        let opponentScore: Int
        let totalRallies: Int
        let avgRallyLength: Double
        let playerAces: Int
        let playerWinners: Int
        let playerErrors: Int
        let npcAces: Int
        let npcWinners: Int
        let npcErrors: Int
        let playerErrorsFromShouldMake: Int
        let npcErrorsFromShouldMake: Int
        let playerNetErrors: Int
        let npcNetErrors: Int
        let playerOutErrors: Int
        let npcOutErrors: Int
        let playerPhysicsOut: Int
        let npcPhysicsOut: Int
        let playerOutLong: Int
        let npcOutLong: Int
        let playerOutWide: Int
        let npcOutWide: Int
        let playerKitchenFaults: Int
        let npcKitchenFaults: Int
    }

    func runDiagnosticMatch(playerDUPR: Double, npcDUPR: Double) -> DiagnosticResult {
        let tag = "[DIAG]"
        let dt: CGFloat = 1.0 / 120.0
        let maxPointTime: CGFloat = 30.0

        // Create components
        let npc = NPC.practiceOpponent(dupr: npcDUPR)
        let playerStats = StatProfileLoader.shared.toNPCStats(dupr: playerDUPR)
        let npcAI = MatchAI(npc: npc, playerDUPR: playerDUPR, headless: true)
        let playerAI = SimulatedPlayerAI(stats: playerStats, dupr: playerDUPR)
        let ballSim = DrillBallSimulation()

        // Format helpers
        func f(_ v: CGFloat) -> String { String(format: "%.2f", v) }
        func f3(_ v: CGFloat) -> String { String(format: "%.3f", v) }
        func modesStr(_ modes: DrillShotCalculator.ShotMode) -> String {
            var parts: [String] = []
            if modes.contains(.power) { parts.append("PWR") }
            if modes.contains(.touch) { parts.append("TCH") }
            if modes.contains(.slice) { parts.append("SLC") }
            if modes.contains(.topspin) { parts.append("TOP") }
            if modes.contains(.angled) { parts.append("ANG") }
            if modes.contains(.focus) { parts.append("FOC") }
            if modes.contains(.lob) { parts.append("LOB") }
            return parts.isEmpty ? "none" : parts.joined(separator: "|")
        }
        func errTypeStr(_ errType: NPCErrorType) -> String {
            switch errType {
            case .net: return "net"
            case .long: return "long"
            case .wide: return "wide"
            }
        }

        // Match state
        var playerScore = 0
        var npcScore = 0
        var servingSide: MatchSide = .player
        var rallyLength = 0
        var totalPointsPlayed = 0
        var totalRallyShots = 0
        var previousBallNY: CGFloat = 0.5
        var checkedFirstBounce = false
        var firstBounceCourtX: CGFloat = 0.5
        var firstBounceCourtY: CGFloat = 0.5

        // Stats
        var playerAces = 0, playerWinners = 0, playerErrors = 0
        var npcAces = 0, npcWinners = 0, npcErrors = 0
        var playerErrorsFromShouldMake = 0, npcErrorsFromShouldMake = 0
        var playerNetErrors = 0, npcNetErrors = 0
        var playerOutErrors = 0, npcOutErrors = 0
        var playerPhysicsOut = 0, npcPhysicsOut = 0
        var playerOutLong = 0, npcOutLong = 0
        var playerOutWide = 0, npcOutWide = 0
        var playerKitchenFaults = 0, npcKitchenFaults = 0

        // Log match start
        print("""
        \(tag) ═══════════════════════════════════════════════
        \(tag) DIAGNOSTIC MATCH: Player (DUPR \(String(format: "%.1f", playerDUPR))) vs NPC (DUPR \(String(format: "%.1f", npcDUPR)))
        \(tag) ═══════════════════════════════════════════════
        \(tag) PLAYER STATS: pow=\(playerStats.power) acc=\(playerStats.accuracy) spn=\(playerStats.spin) spd=\(playerStats.speed) def=\(playerStats.defense) ref=\(playerStats.reflexes) pos=\(playerStats.positioning) clu=\(playerStats.clutch) foc=\(playerStats.focus) sta=\(playerStats.stamina) con=\(playerStats.consistency)
        \(tag) NPC STATS:    pow=\(npc.stats.power) acc=\(npc.stats.accuracy) spn=\(npc.stats.spin) spd=\(npc.stats.speed) def=\(npc.stats.defense) ref=\(npc.stats.reflexes) pos=\(npc.stats.positioning) clu=\(npc.stats.clutch) foc=\(npc.stats.focus) sta=\(npc.stats.stamina) con=\(npc.stats.consistency)
        \(tag) Player hitbox=\(f(playerAI.hitboxRadius)) NPC hitbox=\(f(npcAI.hitboxRadius))
        \(tag) ═══════════════════════════════════════════════
        """)

        // MARK: - Match Over Check

        func isMatchOver() -> Bool {
            let ptsToWin = IM.pointsToWin
            let margin = IM.winByMargin
            if playerScore >= ptsToWin && playerScore - npcScore >= margin { return true }
            if npcScore >= ptsToWin && npcScore - playerScore >= margin { return true }
            if playerScore >= IM.maxScore && npcScore >= IM.maxScore {
                return playerScore != npcScore
            }
            return false
        }

        // MARK: - Resolve Point

        func resolvePoint(_ result: String) {
            let rallyInfo = "rally=\(rallyLength)"
            ballSim.reset()
            totalPointsPlayed += 1
            totalRallyShots += rallyLength

            if result == "playerWon" {
                if servingSide == .player {
                    playerScore += 1
                    print("\(tag)   → PLAYER SCORES (server won) \(playerScore)-\(npcScore) [\(rallyInfo)]")
                } else {
                    servingSide = .player
                    print("\(tag)   → Side out → Player now serving \(playerScore)-\(npcScore) [\(rallyInfo)]")
                }
            } else {
                if servingSide == .opponent {
                    npcScore += 1
                    print("\(tag)   → NPC SCORES (server won) \(playerScore)-\(npcScore) [\(rallyInfo)]")
                } else {
                    servingSide = .opponent
                    print("\(tag)   → Side out → NPC now serving \(playerScore)-\(npcScore) [\(rallyInfo)]")
                }
            }

            playerAI.recoverBetweenPoints()
            npcAI.recoverBetweenPoints()
        }

        // MARK: - Serve

        func executeServe(
            shot: DrillShotCalculator.ShotResult,
            serverStats: PlayerStats,
            score: Int,
            originX: CGFloat,
            originNY: CGFloat,
            targetBaseNY: CGFloat,
            faultNYRange: ClosedRange<CGFloat>,
            isPlayerServing: Bool
        ) {
            let consistencyStat = CGFloat(serverStats.stat(.consistency))
            let accuracyStat = CGFloat(serverStats.stat(.accuracy))
            let serveStat = (consistencyStat + accuracyStat) / 2.0
            let baseFaultRate = P.npcBaseServeFaultRate * (1.0 - serveStat / 99.0)
            let isDoubleFault = CGFloat.random(in: 0...1) < baseFaultRate

            let evenScore = score % 2 == 0
            let baseTargetNX: CGFloat = evenScore ? 0.25 : 0.75

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
                let minNY = min(targetBaseNY - 0.12, targetBaseNY + 0.12)
                let maxNY = max(targetBaseNY - 0.12, targetBaseNY + 0.12)
                serveTargetNY = max(minNY, min(maxNY, targetBaseNY + scatterY))
            }

            let servePower = min(P.servePowerCap, shot.power)
            let serveDistNX = abs(serveTargetNX - originX)
            let serveDistNY = abs(serveTargetNY - originNY)
            let serveArc = DrillShotCalculator.arcToLandAt(
                distanceNY: serveDistNY,
                distanceNX: serveDistNX,
                power: servePower,
                arcMargin: 1.0
            )

            let server = isPlayerServing ? "PLAYER" : "NPC"
            let faultStr = isDoubleFault ? " *** DOUBLE FAULT ***" : ""
            print("""
            \(tag)   [SERVE] \(server)\(faultStr)
            \(tag)     from=(\(f(originX)),\(f(originNY))) → target=(\(f(serveTargetNX)),\(f(serveTargetNY)))
            \(tag)     power=\(f(servePower)) arc=\(f(serveArc)) faultRate=\(f3(baseFaultRate)) scatter=\(f3(scatter))
            """)

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

            let hint = CGPoint(x: serveTargetNX, y: serveTargetNY)
            if isPlayerServing {
                npcAI.serveTargetHint = hint
            } else {
                playerAI.serveTargetHint = hint
            }
        }

        // MARK: - Main Loop

        while !isMatchOver() {
            // Reset point state
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

            let serverStr = servingSide == .player ? "PLAYER" : "NPC"
            print("""
            \(tag) ──── POINT #\(totalPointsPlayed + 1) ────  Score: \(playerScore)-\(npcScore)  Server: \(serverStr)
            \(tag)   Player pos=(\(f(playerAI.currentNX)),\(f(playerAI.currentNY))) stamina=\(f(playerAI.stamina))
            \(tag)   NPC    pos=(\(f(npcAI.currentNX)),\(f(npcAI.currentNY))) stamina=\(f(npcAI.stamina))
            """)

            // Serve
            if servingSide == .player {
                let shot = playerAI.generateServe(playerScore: playerScore)
                executeServe(
                    shot: shot, serverStats: playerAI.stats, score: playerScore,
                    originX: playerAI.currentNX, originNY: playerAI.currentNY,
                    targetBaseNY: 0.85, faultNYRange: 0.52...0.66,
                    isPlayerServing: true
                )
            } else {
                let shot = npcAI.generateServe(npcScore: npcScore)
                executeServe(
                    shot: shot, serverStats: npcAI.npcStats, score: npcScore,
                    originX: npcAI.currentNX, originNY: npcAI.currentNY,
                    targetBaseNY: 0.15, faultNYRange: 0.35...0.48,
                    isPlayerServing: false
                )
            }

            // Game loop
            var elapsed: CGFloat = 0
            var pointOver = false

            while ballSim.isActive && elapsed < maxPointTime && !pointOver {
                let prevBounces = ballSim.bounceCount
                previousBallNY = ballSim.courtY

                ballSim.update(dt: dt)

                // First bounce tracking + receiver teleport
                if ballSim.didBounceThisFrame && prevBounces == 0 {
                    firstBounceCourtX = ballSim.lastBounceCourtX
                    firstBounceCourtY = ballSim.lastBounceCourtY

                    let hitter = ballSim.lastHitByPlayer ? "Player" : "NPC"
                    let isOut = ballSim.isLandingOut
                    print("\(tag)   [BOUNCE] #1 at (\(f3(firstBounceCourtX)),\(f3(firstBounceCourtY))) hit by \(hitter)\(isOut ? " OUT" : "")")

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
                } else if ballSim.didBounceThisFrame && prevBounces == 1 {
                    print("\(tag)   [BOUNCE] #2 at (\(f3(ballSim.lastBounceCourtX)),\(f3(ballSim.lastBounceCourtY)))")
                }

                playerAI.update(dt: dt, ball: ballSim)
                npcAI.playerPositionNX = playerAI.currentNX
                npcAI.playerPositionNY = playerAI.currentNY
                npcAI.update(dt: dt, ball: ballSim)

                // --- Player Hit Check ---
                if rallyLength >= 2 || ballSim.bounceCount > 0 {
                    if playerAI.canHit(ball: ballSim) {
                        let shotModes = playerAI.selectShotModes(ball: ballSim)

                        if playerAI.shouldMakeError(ball: ballSim, npcDUPR: npcAI.npcDUPR) {
                            playerErrors += 1
                            playerErrorsFromShouldMake += 1
                            rallyLength += 1
                            let errType = playerAI.errorType(for: shotModes)
                            switch errType {
                            case .net: playerNetErrors += 1
                            case .long, .wide: playerOutErrors += 1
                            }

                            let dx = ballSim.courtX - playerAI.currentNX
                            let dy = ballSim.courtY - playerAI.currentNY
                            let dist = sqrt(dx * dx + dy * dy)
                            let stretch = min(dist / playerAI.hitboxRadius, 1.0)

                            print("""
                            \(tag)   *** PLAYER ERROR *** type=\(errTypeStr(errType)) modes=\(modesStr(shotModes))
                            \(tag)     ball=(\(f(ballSim.courtX)),\(f(ballSim.courtY))) h=\(f3(ballSim.height))
                            \(tag)     player=(\(f(playerAI.currentNX)),\(f(playerAI.currentNY))) stretch=\(f3(stretch))
                            \(tag)     isPutAway=\(ballSim.isPutAway ? "T" : "F") smash=\(f3(ballSim.smashFactor))
                            \(tag)     stamina=\(f(playerAI.stamina))
                            """)
                            resolvePoint("npcWon")
                            pointOver = true
                            continue
                        }

                        rallyLength += 1
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

                        print("""
                        \(tag)   [HIT] Player #\(rallyLength) modes=\(modesStr(shotModes)) stamina=\(f(playerAI.stamina))
                        \(tag)     from=(\(f(playerAI.currentNX)),\(f(playerAI.currentNY))) → target=(\(f(shot.targetNX)),\(f(shot.targetNY)))
                        \(tag)     pow=\(f(shot.power)) arc=\(f(shot.arc)) spin=\(f(shot.spinCurve)) topspin=\(f(shot.topspinFactor))
                        \(tag)     smashFactor=\(f3(shot.smashFactor)) isPutAway=\(shot.isPutAway ? "T" : "F") scatter=\(f3(shot.scatter))
                        """)

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

                        npcAI.playerShotHistory.append(shot.targetNX)
                        if npcAI.playerShotHistory.count > 5 {
                            npcAI.playerShotHistory.removeFirst()
                        }
                        if rallyLength <= 2 {
                            npcAI.serveTargetHint = CGPoint(x: shot.targetNX, y: shot.targetNY)
                        }
                    }
                }

                // --- NPC Hit Check ---
                if !pointOver && ballSim.isActive && ballSim.lastHitByPlayer && ballSim.bounceCount < 2 {
                    if rallyLength >= 2 || ballSim.bounceCount > 0 {
                        if npcAI.shouldSwing(ball: ballSim) {
                            npcAI.preselectModes(ball: ballSim)

                            // Compute debug info
                            let errDbg = npcAI.computeErrorDebugInfo(ball: ballSim)

                            if npcAI.shouldMakeError(ball: ballSim) {
                                npcErrors += 1
                                npcErrorsFromShouldMake += 1
                                rallyLength += 1
                                let errType = npcAI.errorType(for: npcAI.lastShotModes)
                                switch errType {
                                case .net: npcNetErrors += 1
                                case .long, .wide: npcOutErrors += 1
                                }

                                print("""
                                \(tag)   *** NPC ERROR *** type=\(errTypeStr(errType)) modes=\(modesStr(npcAI.lastShotModes))
                                \(tag)     errorRate=\(f3(errDbg.errorRate)) base=\(f3(errDbg.baseError)) pressure=\(f3(errDbg.pressureError))
                                \(tag)     isPutAway=\(errDbg.isPutAway ? "T" : "F") smash=\(f3(errDbg.smashFactor)) final=\(f3(errDbg.finalErrorRate))
                                \(tag)     shotDifficulty=\(f3(errDbg.shotDifficulty)): speedFrac=\(f3(errDbg.speedFrac)) stretchMult=\(f3(errDbg.stretchMultiplier)) (stretch=\(f3(errDbg.stretchFrac)))
                                \(tag)     spinPressure=\(f3(errDbg.spinPressure)) staminaPct=\(f3(errDbg.staminaPct)) shotQuality=\(f3(errDbg.shotQuality)) duprMult=\(f3(errDbg.duprMultiplier))
                                \(tag)     ball=(\(f(ballSim.courtX)),\(f(ballSim.courtY))) h=\(f3(ballSim.height))
                                \(tag)     npc=(\(f(npcAI.currentNX)),\(f(npcAI.currentNY))) stamina=\(f(npcAI.stamina))
                                """)
                                resolvePoint("playerWon")
                                pointOver = true
                                continue
                            }

                            rallyLength += 1
                            let shot = npcAI.generateShot(ball: ballSim)

                            print("""
                            \(tag)   [HIT] NPC #\(rallyLength) modes=\(modesStr(npcAI.lastShotModes)) stamina=\(f(npcAI.stamina))
                            \(tag)     errorRate=\(f3(errDbg.errorRate)) → survived
                            \(tag)     from=(\(f(npcAI.currentNX)),\(f(npcAI.currentNY))) → target=(\(f(shot.targetNX)),\(f(shot.targetNY)))
                            \(tag)     pow=\(f(shot.power)) arc=\(f(shot.arc)) spin=\(f(shot.spinCurve)) topspin=\(f(shot.topspinFactor))
                            \(tag)     smashFactor=\(f3(shot.smashFactor)) isPutAway=\(shot.isPutAway ? "T" : "F") scatter=\(f3(shot.scatter))
                            """)

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

                            if rallyLength <= 2 {
                                playerAI.serveTargetHint = CGPoint(x: shot.targetNX, y: shot.targetNY)
                            }
                        }
                    }
                }

                // --- Ball State Check ---
                if !pointOver && ballSim.isActive {
                    // Net collision
                    if ballSim.checkNetCollision(previousY: previousBallNY) {
                        let hitter = ballSim.lastHitByPlayer ? "Player" : "NPC"
                        print("\(tag)   [NET] collision — hit by \(hitter)")
                        if ballSim.lastHitByPlayer {
                            playerNetErrors += 1; playerErrors += 1
                            resolvePoint("npcWon")
                        } else {
                            npcNetErrors += 1; npcErrors += 1
                            resolvePoint("playerWon")
                        }
                        pointOver = true
                        continue
                    }

                    // Bounce-time line call
                    if ballSim.didBounceThisFrame && !checkedFirstBounce {
                        checkedFirstBounce = true

                        if ballSim.isLandingOut {
                            let bx = ballSim.lastBounceCourtX
                            let by = ballSim.lastBounceCourtY
                            let isLong = by < 0.0 || by > 1.0
                            let hitter = ballSim.lastHitByPlayer ? "Player" : "NPC"
                            let dir = isLong ? "LONG" : "WIDE"
                            print("\(tag)   [OUT] \(dir) at (\(f3(bx)),\(f3(by))) — hit by \(hitter)")
                            if ballSim.lastHitByPlayer {
                                playerOutErrors += 1; playerPhysicsOut += 1
                                if isLong { playerOutLong += 1 } else { playerOutWide += 1 }
                                playerErrors += 1
                                resolvePoint("npcWon")
                            } else {
                                npcOutErrors += 1; npcPhysicsOut += 1
                                if isLong { npcOutLong += 1 } else { npcOutWide += 1 }
                                npcErrors += 1
                                resolvePoint("playerWon")
                            }
                            pointOver = true
                            continue
                        }

                        // Kitchen fault on serve
                        if rallyLength == 0 {
                            let kitchenNear: CGFloat = 0.318
                            let kitchenFar: CGFloat = 0.682
                            if ballSim.lastHitByPlayer && firstBounceCourtY >= 0.5 && firstBounceCourtY < kitchenFar {
                                print("\(tag)   [KITCHEN FAULT] Player serve landed in kitchen at Y=\(f3(firstBounceCourtY))")
                                playerErrors += 1; playerKitchenFaults += 1
                                resolvePoint("npcWon")
                                pointOver = true
                                continue
                            }
                            if !ballSim.lastHitByPlayer && firstBounceCourtY <= 0.5 && firstBounceCourtY > kitchenNear {
                                print("\(tag)   [KITCHEN FAULT] NPC serve landed in kitchen at Y=\(f3(firstBounceCourtY))")
                                npcErrors += 1; npcKitchenFaults += 1
                                resolvePoint("playerWon")
                                pointOver = true
                                continue
                            }
                        }
                    }

                    // Double bounce
                    if ballSim.isDoubleBounce {
                        let bounceY = ballSim.lastBounceCourtY
                        if bounceY < 0.5 {
                            let hitter = ballSim.lastHitByPlayer ? "self-error" : "winner"
                            print("\(tag)   [DOUBLE_BOUNCE] player side — \(hitter)")
                            if ballSim.lastHitByPlayer {
                                playerErrors += 1
                            } else {
                                if rallyLength <= 1 { npcAces += 1 } else { npcWinners += 1 }
                            }
                            resolvePoint("npcWon")
                        } else {
                            let hitter = ballSim.lastHitByPlayer ? "winner" : "self-error"
                            print("\(tag)   [DOUBLE_BOUNCE] NPC side — \(hitter)")
                            if ballSim.lastHitByPlayer {
                                if rallyLength <= 1 { playerAces += 1 } else { playerWinners += 1 }
                            } else {
                                npcErrors += 1
                            }
                            resolvePoint("playerWon")
                        }
                        pointOver = true
                        continue
                    }

                    // Out of bounds (safety)
                    if ballSim.isOutOfBounds {
                        let isLong = ballSim.courtY < -0.5 || ballSim.courtY > 1.5
                        let hitter = ballSim.lastHitByPlayer ? "Player" : "NPC"
                        print("\(tag)   [OOB] \(isLong ? "LONG" : "WIDE") at (\(f3(ballSim.courtX)),\(f3(ballSim.courtY))) — hit by \(hitter)")
                        if ballSim.lastHitByPlayer {
                            playerOutErrors += 1; playerPhysicsOut += 1
                            if isLong { playerOutLong += 1 } else { playerOutWide += 1 }
                            playerErrors += 1
                            resolvePoint("npcWon")
                        } else {
                            npcOutErrors += 1; npcPhysicsOut += 1
                            if isLong { npcOutLong += 1 } else { npcOutWide += 1 }
                            npcErrors += 1
                            resolvePoint("playerWon")
                        }
                        pointOver = true
                        continue
                    }

                    // Stalled
                    if ballSim.isStalled {
                        let hitter = ballSim.lastHitByPlayer ? "Player" : "NPC"
                        print("\(tag)   [STALLED] ball stopped — last hit by \(hitter)")
                        if ballSim.lastHitByPlayer {
                            playerErrors += 1
                            resolvePoint("npcWon")
                        } else {
                            npcErrors += 1
                            resolvePoint("playerWon")
                        }
                        pointOver = true
                        continue
                    }
                }

                elapsed += dt
            }

            // Timeout safety
            if ballSim.isActive && !pointOver {
                print("\(tag)   [TIMEOUT] point exceeded \(Int(maxPointTime))s")
                let result = ballSim.lastHitByPlayer ? "npcWon" : "playerWon"
                resolvePoint(result)
            }
        }

        let winnerSide: MatchSide = playerScore > npcScore ? .player : .opponent
        let avgRally = totalPointsPlayed > 0
            ? Double(totalRallyShots) / Double(totalPointsPlayed) : 0

        return DiagnosticResult(
            winnerSide: winnerSide,
            playerScore: playerScore,
            opponentScore: npcScore,
            totalRallies: totalPointsPlayed,
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
            npcKitchenFaults: npcKitchenFaults
        )
    }
}
