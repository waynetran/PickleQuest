import Testing
import Foundation
@testable import PickleQuest

@Suite("Headless Match Simulator")
struct HeadlessMatchSimulatorTests {

    /// Match completes cleanly: no infinite loops, valid scores, bounded rally count.
    @Test func matchCompletesCleanly() {
        let npc = NPC.headlessOpponent(dupr: 4.0)
        let playerStats = StatProfileLoader.shared.toPlayerStats(dupr: 4.0)
        let sim = HeadlessMatchSimulator(npc: npc, playerStats: playerStats, playerDUPR: 4.0)
        let result = sim.simulateMatch()

        // Match must have a winner
        #expect(result.playerScore > 0 || result.opponentScore > 0)

        // At least one side reached 11+ points
        let maxScore = max(result.playerScore, result.opponentScore)
        #expect(maxScore >= 11)

        // Winner must win by 2 (or sudden death at 15)
        let diff = abs(result.playerScore - result.opponentScore)
        if maxScore < 15 {
            #expect(diff >= 2)
        }

        // Rallies are bounded
        #expect(result.totalRallies > 0)
        #expect(result.totalRallies < 200, "Too many points — possible loop")
    }

    /// Higher DUPR player should win significantly more often.
    @Test func higherDUPRWinsMore() {
        let matchCount = 100

        // Strong player (5.5) vs weak NPC (3.0)
        var strongWins = 0
        for _ in 0..<matchCount {
            let npc = NPC.headlessOpponent(dupr: 3.0)
            let playerStats = StatProfileLoader.shared.toPlayerStats(dupr: 5.5)
            let sim = HeadlessMatchSimulator(npc: npc, playerStats: playerStats, playerDUPR: 5.5)
            let result = sim.simulateMatch()
            if result.winnerSide == .player { strongWins += 1 }
        }

        // Weak player (2.5) vs strong NPC (5.5)
        var weakWins = 0
        for _ in 0..<matchCount {
            let npc = NPC.headlessOpponent(dupr: 5.5)
            let playerStats = StatProfileLoader.shared.toPlayerStats(dupr: 2.5)
            let sim = HeadlessMatchSimulator(npc: npc, playerStats: playerStats, playerDUPR: 2.5)
            let result = sim.simulateMatch()
            if result.winnerSide == .player { weakWins += 1 }
        }

        let strongWinRate = Double(strongWins) / Double(matchCount)
        let weakWinRate = Double(weakWins) / Double(matchCount)

        #expect(strongWinRate > weakWinRate,
                "Strong player (5.5 vs 3.0) win rate \(strongWinRate) should exceed weak player (2.5 vs 5.5) win rate \(weakWinRate)")
        #expect(strongWinRate > 0.5,
                "Strong player should win majority: \(strongWinRate)")
    }

    /// Diagnostic: print detailed stats per DUPR matchup to understand balance.
    @Test func diagnosticBalance() {
        let matchCount = 200
        let duprPairs: [(Double, Double)] = [
            (3.0, 3.0), (4.0, 4.0), (5.0, 5.0),
            (5.5, 3.0), (2.5, 5.5)
        ]

        for (pDUPR, nDUPR) in duprPairs {
            // Verify stats are identical at equal DUPR
            if pDUPR == nDUPR {
                let ps = StatProfileLoader.shared.toPlayerStats(dupr: pDUPR)
                let npc = NPC.headlessOpponent(dupr: nDUPR)
                let ns = npc.stats
                print("Stats at DUPR \(pDUPR): P=[con=\(ps.consistency) foc=\(ps.focus) ref=\(ps.reflexes) acc=\(ps.accuracy) pos=\(ps.positioning) spd=\(ps.speed)] N=[con=\(ns.consistency) foc=\(ns.focus) ref=\(ns.reflexes) acc=\(ns.accuracy) pos=\(ns.positioning) spd=\(ns.speed)]")
            }
            var pWins = 0
            var totalPScore = 0
            var totalNScore = 0
            var totalPErrors = 0
            var totalNErrors = 0
            var totalRally = 0.0
            var totalPAces = 0
            var totalPWinners = 0
            var totalNAces = 0
            var totalNWinners = 0
            // Diagnostic error source breakdown
            var totalPShouldMake = 0
            var totalNShouldMake = 0
            var totalPNet = 0
            var totalNNet = 0
            var totalPOut = 0
            var totalNOut = 0
            var totalPPhysicsOut = 0
            var totalNPhysicsOut = 0
            var totalPOutLong = 0
            var totalNOutLong = 0
            var totalPOutWide = 0
            var totalNOutWide = 0
            var totalPKitchenFault = 0
            var totalNKitchenFault = 0

            for _ in 0..<matchCount {
                let npc = NPC.headlessOpponent(dupr: nDUPR)
                let playerStats = StatProfileLoader.shared.toPlayerStats(dupr: pDUPR)
                let sim = HeadlessMatchSimulator(npc: npc, playerStats: playerStats, playerDUPR: pDUPR)
                let result = sim.simulateMatch()
                if result.winnerSide == .player { pWins += 1 }
                totalPScore += result.playerScore
                totalNScore += result.opponentScore
                totalPErrors += result.playerErrors
                totalNErrors += result.npcErrors
                totalRally += result.avgRallyLength
                totalPAces += result.playerAces
                totalPWinners += result.playerWinners
                totalNAces += result.npcAces
                totalNWinners += result.npcWinners
                totalPShouldMake += result.playerErrorsFromShouldMake
                totalNShouldMake += result.npcErrorsFromShouldMake
                totalPNet += result.playerNetErrors
                totalNNet += result.npcNetErrors
                totalPOut += result.playerOutErrors
                totalNOut += result.npcOutErrors
                totalPPhysicsOut += result.playerPhysicsOut
                totalNPhysicsOut += result.npcPhysicsOut
                totalPOutLong += result.playerOutLong
                totalNOutLong += result.npcOutLong
                totalPOutWide += result.playerOutWide
                totalNOutWide += result.npcOutWide
                totalPKitchenFault += result.playerKitchenFaults
                totalNKitchenFault += result.npcKitchenFaults
            }

            let n = Double(matchCount)
            let f = { (v: Int) in String(format: "%.1f", Double(v)/n) }
            let fp = { (v: Int) in String(format: "%.1f", Double(v)/n*100) }
            print("""
                P\(pDUPR) vs N\(nDUPR): WR=\(fp(pWins))% Score=\(f(totalPScore))-\(f(totalNScore)) Rally=\(String(format: "%.1f", totalRally/n))
                  Errors:  P=\(f(totalPErrors)) N=\(f(totalNErrors))
                  ShouldMake: P=\(f(totalPShouldMake)) N=\(f(totalNShouldMake))
                  Net:     P=\(f(totalPNet)) N=\(f(totalNNet))
                  Out(total): P=\(f(totalPOut)) N=\(f(totalNOut))
                  Physics(L/W): P=\(f(totalPOutLong))/\(f(totalPOutWide)) N=\(f(totalNOutLong))/\(f(totalNOutWide))
                  Kitchen:  P=\(f(totalPKitchenFault)) N=\(f(totalNKitchenFault))
                  Aces:    P=\(f(totalPAces)) N=\(f(totalNAces))
                  Winners: P=\(f(totalPWinners)) N=\(f(totalNWinners))
                """)
        }
    }

    // MARK: - Hit Detection Diagnostics

    /// Diagnostic: simulate balls aimed directly at the player/NPC at various speeds,
    /// heights, and spin values. Reports hit rate, error rate, and miss classification
    /// to debug why rallies are short (balls passing players who appear to be in position).
    @Test func ballAtReceiverHitDetection() {
        let dt: CGFloat = 1.0 / 120.0
        let maxTime: CGFloat = 5.0
        let trialsPerCombo = 50
        typealias P = GameConstants.DrillPhysics

        let duprLevels: [Double] = [2.0, 3.5, 5.0, 6.5, 8.0]
        let shotPowers: [CGFloat] = [0.2, 0.5, 0.8, 1.0]
        let arcMultipliers: [CGFloat] = [1.0, 1.5, 2.5]  // flat, medium, lob
        let spinValues: [CGFloat] = [0.0, 0.5, 1.0]

        // ── Player-side: ball from NPC (y=0.85) aimed at player (y=0.08) ──
        print("\n=== PLAYER Hit Detection (ball aimed straight at player) ===")
        print("DUPR  Power ArcM Spin  HitRate ErrRate  PreBn Hght  Dist  Other AvgClose HitboxR")

        for dupr in duprLevels {
            let stats = StatProfileLoader.shared.toPlayerStats(dupr: dupr)

            for power in shotPowers {
                for arcMult in arcMultipliers {
                    for spin in spinValues {
                        var hits = 0
                        var errors = 0
                        var preBounceBlocked = 0
                        var heightBlocked = 0
                        var distanceBlocked = 0
                        var otherMiss = 0
                        var totalClosest: CGFloat = 0

                        // Compute the arc that makes the ball land at the target
                        let distNY: CGFloat = 0.77
                        let baseArc = DrillShotCalculator.arcToLandAt(distanceNY: distNY, power: power)
                        let arc = baseArc * arcMult

                        // Player's height reach for miss classification
                        let speedStat = CGFloat(stats.stat(.speed))
                        let reflexesStat = CGFloat(stats.stat(.reflexes))
                        let athleticism = (speedStat + reflexesStat) / 2.0 / 99.0
                        let heightReach = P.baseHeightReach + athleticism * P.maxHeightReachBonus

                        for _ in 0..<trialsPerCombo {
                            let player = SimulatedPlayerAI(stats: stats, dupr: dupr)
                            let ball = DrillBallSimulation()

                            // Player at center baseline
                            player.currentNX = 0.5
                            player.currentNY = 0.08

                            // Launch ball from NPC side directly at player position
                            ball.launch(
                                from: CGPoint(x: 0.5, y: 0.85),
                                toward: CGPoint(x: 0.5, y: 0.08),
                                power: power,
                                arc: arc,
                                spin: spin
                            )
                            ball.lastHitByPlayer = false

                            var closestDist: CGFloat = 999
                            var closestWasPreBounce = false
                            var closestBallHeight: CGFloat = 0
                            var hitDetected = false

                            var elapsed: CGFloat = 0
                            while ball.isActive && !ball.isDoubleBounce && !ball.isOutOfBounds && elapsed < maxTime {
                                ball.update(dt: dt)
                                player.update(dt: dt, ball: ball)

                                if player.canHit(ball: ball) {
                                    hitDetected = true
                                    if player.shouldMakeError(ball: ball, npcDUPR: dupr) {
                                        errors += 1
                                    }
                                    break
                                }

                                // Track closest approach when ball is on player's half
                                if ball.courtY < 0.5 {
                                    let dx = ball.courtX - player.currentNX
                                    let dy = ball.courtY - player.currentNY
                                    let excessH = max(0, ball.height - heightReach)
                                    let dist3d = sqrt(dx * dx + dy * dy + excessH * excessH)
                                    if dist3d < closestDist {
                                        closestDist = dist3d
                                        closestWasPreBounce = ball.bounceCount == 0 && ball.courtY > player.currentNY
                                        closestBallHeight = ball.height
                                    }
                                }

                                elapsed += dt
                            }

                            if hitDetected {
                                hits += 1
                            } else {
                                totalClosest += closestDist
                                if closestWasPreBounce {
                                    preBounceBlocked += 1
                                } else if closestBallHeight > heightReach {
                                    heightBlocked += 1
                                } else if closestDist > player.hitboxRadius {
                                    distanceBlocked += 1
                                } else {
                                    otherMiss += 1
                                }
                            }
                        }

                        let n = Double(trialsPerCombo)
                        let hitRate = Double(hits) / n * 100
                        let errRate = hits > 0 ? Double(errors) / Double(hits) * 100 : 0
                        let misses = trialsPerCombo - hits
                        let avgClose = misses > 0 ? totalClosest / CGFloat(misses) : 0

                        // Only print rows with misses or interesting data
                        if hitRate < 100 || spin > 0 {
                            let positioningStat = CGFloat(stats.stat(.positioning))
                            let hbr = P.baseHitboxRadius + (positioningStat / 99.0) * P.positioningHitboxBonus
                            print(String(format: "%4.1f  %4.2f %4.2f %4.2f  %5.1f%%  %5.1f%%  %4d  %4d  %4d  %4d  %8.4f %8.4f",
                                dupr, power, arcMult, spin, hitRate, errRate,
                                preBounceBlocked, heightBlocked, distanceBlocked, otherMiss,
                                avgClose, hbr))
                        }
                    }
                }
            }
        }

        // ── NPC-side: ball from player (y=0.08) aimed at NPC (y=0.92) ──
        print("\n=== NPC Hit Detection (ball aimed straight at NPC) ===")
        print("DUPR  Power ArcM Spin  HitRate ErrRate  PreBn Hght  Dist  Other AvgClose HitboxR")

        for dupr in duprLevels {
            // Pre-compute NPC stats for this DUPR (same for all trials)
            let npcStats = StatProfileLoader.shared.toPlayerStats(dupr: dupr)
            let npcSpeedStat = CGFloat(npcStats.stat(.speed))
            let npcReflexesStat = CGFloat(npcStats.stat(.reflexes))
            let npcAthleticism = (npcSpeedStat + npcReflexesStat) / 2.0 / 99.0
            let npcHeightReach = P.baseHeightReach + npcAthleticism * P.maxHeightReachBonus
            let npcPosStat = CGFloat(npcStats.stat(.positioning))
            let npcHitboxR = P.baseHitboxRadius + (npcPosStat / 99.0) * P.positioningHitboxBonus

            for power in shotPowers {
                for arcMult in arcMultipliers {
                    for spin in spinValues {
                        var hits = 0
                        var errors = 0
                        var preBounceBlocked = 0
                        var heightBlocked = 0
                        var distanceBlocked = 0
                        var otherMiss = 0
                        var totalClosest: CGFloat = 0

                        let distNY: CGFloat = 0.77
                        let baseArc = DrillShotCalculator.arcToLandAt(distanceNY: distNY, power: power)
                        let arc = baseArc * arcMult

                        for _ in 0..<trialsPerCombo {
                            let npc = NPC.headlessOpponent(dupr: dupr)
                            let npcAI = MatchAI(npc: npc, playerDUPR: dupr, headless: true)
                            let ball = DrillBallSimulation()

                            // NPC at center far baseline
                            npcAI.currentNX = 0.5
                            npcAI.currentNY = 0.92

                            // Launch ball from player side toward NPC position
                            ball.launch(
                                from: CGPoint(x: 0.5, y: 0.08),
                                toward: CGPoint(x: 0.5, y: 0.92),
                                power: power,
                                arc: arc,
                                spin: spin
                            )
                            ball.lastHitByPlayer = true

                            var closestDist: CGFloat = 999
                            var closestWasPreBounce = false
                            var closestBallHeight: CGFloat = 0
                            var hitDetected = false

                            var elapsed: CGFloat = 0
                            while ball.isActive && !ball.isDoubleBounce && !ball.isOutOfBounds && elapsed < maxTime {
                                ball.update(dt: dt)
                                npcAI.update(dt: dt, ball: ball)

                                if npcAI.shouldSwing(ball: ball) {
                                    hitDetected = true
                                    if npcAI.shouldMakeError(ball: ball) {
                                        errors += 1
                                    }
                                    break
                                }

                                // Track closest approach on NPC half
                                if ball.courtY > 0.5 {
                                    let dx = ball.courtX - npcAI.currentNX
                                    let dy = ball.courtY - npcAI.currentNY
                                    let excessH = max(0, ball.height - npcHeightReach)
                                    let dist3d = sqrt(dx * dx + dy * dy + excessH * excessH)
                                    if dist3d < closestDist {
                                        closestDist = dist3d
                                        closestWasPreBounce = ball.bounceCount == 0 && ball.courtY < npcAI.currentNY
                                        closestBallHeight = ball.height
                                    }
                                }

                                elapsed += dt
                            }

                            if hitDetected {
                                hits += 1
                            } else {
                                totalClosest += closestDist
                                if closestWasPreBounce {
                                    preBounceBlocked += 1
                                } else if closestBallHeight > npcHeightReach {
                                    heightBlocked += 1
                                } else if closestDist > npcHitboxR {
                                    distanceBlocked += 1
                                } else {
                                    otherMiss += 1
                                }
                            }
                        }

                        let n = Double(trialsPerCombo)
                        let hitRate = Double(hits) / n * 100
                        let errRate = hits > 0 ? Double(errors) / Double(hits) * 100 : 0
                        let misses = trialsPerCombo - hits
                        let avgClose = misses > 0 ? totalClosest / CGFloat(misses) : 0

                        if hitRate < 100 || spin > 0 {
                            print(String(format: "%4.1f  %4.2f %4.2f %4.2f  %5.1f%%  %5.1f%%  %4d  %4d  %4d  %4d  %8.4f %8.4f",
                                dupr, power, arcMult, spin, hitRate, errRate,
                                preBounceBlocked, heightBlocked, distanceBlocked, otherMiss,
                                avgClose, npcHitboxR))
                        }
                    }
                }
            }
        }

        // ── Detailed trace: single ball at 5.0 DUPR player, medium speed ──
        print("\n=== Detailed Ball Trace (DUPR 5.0, power=0.5, arcMult=1.0, spin=0.0) ===")
        print("  Time   BallX   BallY  BallH  Bounce  PlyrX  PlyrY  Dist3D  CanHit  Reacted")
        do {
            let stats = StatProfileLoader.shared.toPlayerStats(dupr: 5.0)
            let player = SimulatedPlayerAI(stats: stats, dupr: 5.0)
            let ball = DrillBallSimulation()
            player.currentNX = 0.5
            player.currentNY = 0.08

            let distNY: CGFloat = 0.77
            let baseArc = DrillShotCalculator.arcToLandAt(distanceNY: distNY, power: 0.5)
            ball.launch(from: CGPoint(x: 0.5, y: 0.85), toward: CGPoint(x: 0.5, y: 0.08),
                        power: 0.5, arc: baseArc, spin: 0.0)
            ball.lastHitByPlayer = false

            let speedStat = CGFloat(stats.stat(.speed))
            let reflexesStat = CGFloat(stats.stat(.reflexes))
            let athleticism = (speedStat + reflexesStat) / 2.0 / 99.0
            let heightReach = P.baseHeightReach + athleticism * P.maxHeightReachBonus

            var elapsed: CGFloat = 0
            var frameCount = 0
            while ball.isActive && !ball.isDoubleBounce && !ball.isOutOfBounds && elapsed < 5.0 {
                ball.update(dt: dt)
                player.update(dt: dt, ball: ball)

                let canHit = player.canHit(ball: ball)
                let dx = ball.courtX - player.currentNX
                let dy = ball.courtY - player.currentNY
                let excessH = max(0, ball.height - heightReach)
                let dist3d = sqrt(dx * dx + dy * dy + excessH * excessH)

                // Print every 12 frames (~10 fps output) or at key events
                let isBounce = ball.didBounceThisFrame
                let isClose = dist3d < player.hitboxRadius * 2
                if frameCount % 12 == 0 || isBounce || canHit || isClose {
                    let reacted = ball.courtY < 0.5 ? "Y" : "-"
                    print(String(format: "  %5.3f  %6.3f  %6.3f  %5.3f  %d       %6.3f %6.3f  %6.4f  %@     %@",
                        elapsed, ball.courtX, ball.courtY, ball.height, ball.bounceCount,
                        player.currentNX, player.currentNY, dist3d,
                        canHit ? "HIT" : "  -", reacted))
                }
                if canHit { break }

                elapsed += dt
                frameCount += 1
            }
            print("  Hitbox radius: \(String(format: "%.4f", player.hitboxRadius))")
            print("  Height reach:  \(String(format: "%.4f", heightReach))")
            print("  Final ball state: bounceCount=\(ball.bounceCount), isActive=\(ball.isActive)")
        }

        // ── Cross-court ball trace: ball aimed at offset from player ──
        print("\n=== Cross-Court Ball Trace (DUPR 5.0, power=0.5, target=(0.75, 0.15)) ===")
        print("  Time   BallX   BallY  BallH  Bounce  PlyrX  PlyrY  Dist3D  CanHit")
        do {
            let stats = StatProfileLoader.shared.toPlayerStats(dupr: 5.0)
            let player = SimulatedPlayerAI(stats: stats, dupr: 5.0)
            let ball = DrillBallSimulation()
            // Player starts at left receive position (cross-court from NPC serve at right)
            player.currentNX = 0.25
            player.currentNY = 0.08

            let distNY: CGFloat = 0.70
            let baseArc = DrillShotCalculator.arcToLandAt(distanceNY: distNY, power: 0.5)
            ball.launch(from: CGPoint(x: 0.25, y: 0.85), toward: CGPoint(x: 0.75, y: 0.15),
                        power: 0.5, arc: baseArc, spin: 0.0)
            ball.lastHitByPlayer = false

            let speedStat = CGFloat(stats.stat(.speed))
            let reflexesStat = CGFloat(stats.stat(.reflexes))
            let athleticism = (speedStat + reflexesStat) / 2.0 / 99.0
            let heightReach = P.baseHeightReach + athleticism * P.maxHeightReachBonus

            var elapsed: CGFloat = 0
            var frameCount = 0
            while ball.isActive && !ball.isDoubleBounce && !ball.isOutOfBounds && elapsed < 5.0 {
                ball.update(dt: dt)
                player.update(dt: dt, ball: ball)

                let canHit = player.canHit(ball: ball)
                let dx = ball.courtX - player.currentNX
                let dy = ball.courtY - player.currentNY
                let excessH = max(0, ball.height - heightReach)
                let dist3d = sqrt(dx * dx + dy * dy + excessH * excessH)

                let isBounce = ball.didBounceThisFrame
                let isClose = dist3d < player.hitboxRadius * 2
                if frameCount % 12 == 0 || isBounce || canHit || isClose {
                    print(String(format: "  %5.3f  %6.3f  %6.3f  %5.3f  %d       %6.3f %6.3f  %6.4f  %@",
                        elapsed, ball.courtX, ball.courtY, ball.height, ball.bounceCount,
                        player.currentNX, player.currentNY, dist3d,
                        canHit ? "HIT" : "  -"))
                }
                if canHit { break }

                elapsed += dt
                frameCount += 1
            }
            print("  Hitbox radius: \(String(format: "%.4f", player.hitboxRadius))")
            print("  Height reach:  \(String(format: "%.4f", heightReach))")
            print("  Final ball state: bounceCount=\(ball.bounceCount), isActive=\(ball.isActive)")
        }
    }

    /// Verify serve positions and pickleball rule compliance.
    /// - Server must be at or behind their baseline (foot fault check)
    /// - Two-bounce rule: no volleys before both sides have let the ball bounce
    /// - Zero violations expected across all DUPR levels
    @Test func servePositionsAndRuleCompliance() {
        let matchCount = 100
        let duprLevels: [Double] = [2.0, 3.0, 4.0, 5.0, 6.0, 7.0]

        var totalPlayerFootFaults = 0
        var totalNPCFootFaults = 0
        var totalPlayerTwoBounce = 0
        var totalNPCTwoBounce = 0

        print("\n=== Serve Positions & Rule Compliance ===")
        print("DUPR  PServeNY  NServeNY  PRecvNY  NRecvNY  PFootF  NFootF  P2Bnc  N2Bnc")

        for dupr in duprLevels {
            var pFootFaults = 0
            var nFootFaults = 0
            var pTwoBounce = 0
            var nTwoBounce = 0
            var sumPServeNY = 0.0
            var sumNServeNY = 0.0
            var sumPRecvNY = 0.0
            var sumNRecvNY = 0.0

            for _ in 0..<matchCount {
                let npc = NPC.headlessOpponent(dupr: dupr)
                let playerStats = StatProfileLoader.shared.toPlayerStats(dupr: dupr)
                let sim = HeadlessMatchSimulator(npc: npc, playerStats: playerStats, playerDUPR: dupr)
                let result = sim.simulateMatch()

                pFootFaults += result.playerServeFootFaults
                nFootFaults += result.npcServeFootFaults
                pTwoBounce += result.playerTwoBounceViolations
                nTwoBounce += result.npcTwoBounceViolations
                sumPServeNY += result.avgPlayerServeNY
                sumNServeNY += result.avgNPCServeNY
                sumPRecvNY += result.avgPlayerReceiveNY
                sumNRecvNY += result.avgNPCReceiveNY
            }

            totalPlayerFootFaults += pFootFaults
            totalNPCFootFaults += nFootFaults
            totalPlayerTwoBounce += pTwoBounce
            totalNPCTwoBounce += nTwoBounce

            let n = Double(matchCount)
            print(String(format: "%4.1f  %8.4f  %8.4f  %7.4f  %7.4f  %6d  %6d  %5d  %5d",
                dupr,
                sumPServeNY / n, sumNServeNY / n,
                sumPRecvNY / n, sumNRecvNY / n,
                pFootFaults, nFootFaults,
                pTwoBounce, nTwoBounce))
        }

        print("\nTotals across \(matchCount * duprLevels.count) matches:")
        print("  Player foot faults:       \(totalPlayerFootFaults)")
        print("  NPC foot faults:          \(totalNPCFootFaults)")
        print("  Player 2-bounce violations: \(totalPlayerTwoBounce)")
        print("  NPC 2-bounce violations:    \(totalNPCTwoBounce)")

        // Strict assertions: zero rule violations
        #expect(totalPlayerFootFaults == 0,
                "Player committed \(totalPlayerFootFaults) serve foot faults (serving from inside court)")
        #expect(totalNPCFootFaults == 0,
                "NPC committed \(totalNPCFootFaults) serve foot faults (serving from inside court)")
        #expect(totalPlayerTwoBounce == 0,
                "Player committed \(totalPlayerTwoBounce) two-bounce rule violations")
        #expect(totalNPCTwoBounce == 0,
                "NPC committed \(totalNPCTwoBounce) two-bounce rule violations")
    }

    /// Average rally length should be bounded reasonably.
    /// In headless mode, NPC stat boost is disabled so both sides play on equal footing.
    @Test func rallyLengthIsReasonable() {
        let matchCount = 50
        var totalAvgRally = 0.0

        for _ in 0..<matchCount {
            let npc = NPC.headlessOpponent(dupr: 4.0)
            let playerStats = StatProfileLoader.shared.toPlayerStats(dupr: 4.0)
            let sim = HeadlessMatchSimulator(npc: npc, playerStats: playerStats, playerDUPR: 4.0)
            let result = sim.simulateMatch()
            totalAvgRally += result.avgRallyLength
        }

        let overallAvgRally = totalAvgRally / Double(matchCount)

        #expect(overallAvgRally >= 0.5,
                "Average rally \(overallAvgRally) too short — points ending without any returns")
        #expect(overallAvgRally <= 30.0,
                "Average rally \(overallAvgRally) too long")
    }
}
