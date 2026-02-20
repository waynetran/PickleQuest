import Testing
import Foundation
import CoreGraphics
@testable import PickleQuest

@Suite("Serve Balance")
struct ServeBalanceTests {

    // MARK: - Targets

    /// Target faults per match (each side serves ~10-12 times in a typical match)
    /// Interpolated linearly between anchor points.
    static let faultTargets: [(dupr: Double, faultsPerMatch: Double)] = [
        (2.0, 1.1),   // beginners: ~10% fault rate → ~1.1 per match (long/wide, never kitchen)
        (3.5, 0.6),
        (5.0, 0.3),   // intermediate: rare faults
        (6.5, 0.15),
        (8.0, 0.05),  // pros: almost never fault
    ]

    static let tolerance: Double = 0.25         // acceptable deviation from target
    static let servesPerTrial = 10_000          // serves per DUPR level for verification
    static let avgServesPerMatch: Double = 11.0 // ~22 points, each side serves ~11

    // MARK: - Simulate Serves

    /// Simulate `count` NPC serves at the given DUPR and return the fraction that fault.
    static func simulateServeFaultRate(
        dupr: Double,
        count: Int
    ) -> Double {
        let params = StatProfileLoader.shared
        let stats = params.toNPCStats(dupr: dupr)
        let npc = NPC.practiceOpponent(dupr: dupr)
        let strategy = NPCStrategyProfile.build(dupr: dupr, personality: npc.playerType)
        let P = GameConstants.DrillPhysics.self
        let S = GameConstants.NPCStrategy.self

        let boost = P.npcStatBoost(forBaseStatAverage: CGFloat(stats.average))
        let consistencyStat = CGFloat(min(99, stats.stat(.consistency) + boost))
        let accuracyStat = CGFloat(min(99, stats.stat(.accuracy) + boost))
        let serveStat = (consistencyStat + accuracyStat) / 2.0

        // Base double fault rate from stats (exponential scaling for DUPR separation)
        let baseFaultRate = P.npcBaseServeFaultRate
        let statFaultRate = baseFaultRate * pow(1.0 - serveStat / 99.0, P.npcServeFaultStatExponent)

        // Serve mode selection (same as InteractiveMatchScene.npcServe)
        let duprFrac = CGFloat(max(0, min(1, (dupr - 2.0) / 6.0)))
        let serveMinNY = S.npcServeTargetMinNY
        let maxNY = S.npcServeTargetMaxNY_Low + duprFrac * (S.npcServeTargetMaxNY_High - S.npcServeTargetMaxNY_Low)

        // NPC serve origin (behind baseline — matches MatchAI.positionForServe)
        let serveOriginNY: CGFloat = 1.0

        // Boosted stats for shot calculation (matches MatchAI.effectiveStats)
        let boostedStats = PlayerStats(
            power: min(99, stats.power + boost),
            accuracy: min(99, stats.accuracy + boost),
            spin: min(99, stats.spin + boost),
            speed: min(99, stats.speed + boost),
            defense: min(99, stats.defense + boost),
            reflexes: min(99, stats.reflexes + boost),
            positioning: min(99, stats.positioning + boost),
            clutch: min(99, stats.clutch + boost),
            focus: min(99, stats.focus + boost),
            stamina: min(99, stats.stamina + boost),
            consistency: min(99, stats.consistency + boost)
        )

        var totalFaults = 0
        let ballSim = DrillBallSimulation()
        let kitchenNear: CGFloat = 0.318

        for i in 0..<count {
            // Randomize serve modes (same logic as InteractiveMatchScene)
            var modes: DrillShotCalculator.ShotMode = []
            let roll1 = CGFloat.random(in: 0...1)
            let roll2 = CGFloat.random(in: 0...1)
            let roll3 = CGFloat.random(in: 0...1)
            if roll1 < strategy.driveOnHighBall { modes.insert(.power) }
            if roll2 < strategy.placementAwareness * 0.8 {
                modes.insert(Bool.random() ? .topspin : .slice)
            }
            if roll3 < strategy.placementAwareness * 0.5 { modes.insert(.angled) }

            // Mode fault penalty
            var rawPenalty: CGFloat = 0
            if modes.contains(.power) { rawPenalty += S.npcServePowerFaultPenalty }
            if modes.contains(.topspin) || modes.contains(.slice) { rawPenalty += S.npcServeSpinFaultPenalty }
            let controlFactor = pow(1.0 - strategy.aggressionControl, S.npcServeControlExponent)
            let modePenalty = rawPenalty * controlFactor

            let faultRate = statFaultRate + modePenalty
            let isDoubleFault = CGFloat.random(in: 0...1) < faultRate

            // Generate serve using DrillShotCalculator (matches MatchAI.generateServe)
            var shot = DrillShotCalculator.calculatePlayerShot(
                stats: boostedStats,
                ballApproachFromLeft: false,
                drillType: .baselineRally,
                ballHeight: 0.05,
                courtNX: i % 2 == 0 ? 0.75 : 0.25,
                courtNY: serveOriginNY,
                modes: modes,
                staminaFraction: 1.0
            )

            // Power reduction for skilled NPCs (applied before arc — same as MatchAI.generateServe)
            shot.power *= (1.0 - strategy.aggressionControl * 0.45)

            // Serve power: floor + cap (matches npcServe)
            shot.power = max(P.serveMinPower, min(P.servePowerCap, shot.power))

            // Target selection (matches InteractiveMatchScene.npcServe exactly)
            let evenScore = i % 2 == 0
            let originNX: CGFloat = evenScore ? 0.75 : 0.25
            var targetNX: CGFloat = evenScore ? 0.25 : 0.75
            var targetNY: CGFloat
            var faultPowerOverride: CGFloat? = nil

            if isDoubleFault {
                let hasSpin = modes.contains(.topspin) || modes.contains(.slice)
                let kitchenFaultChance = hasSpin ? duprFrac * 0.4 : 0.0

                if CGFloat.random(in: 0...1) < kitchenFaultChance {
                    targetNY = CGFloat.random(in: 0.35...0.48)
                } else {
                    let longVsWide = CGFloat.random(in: 0...1)
                    if longVsWide < 0.6 {
                        // Long: NPC swings too hard
                        targetNY = CGFloat.random(in: 0.05...0.15)
                        faultPowerOverride = CGFloat.random(in: 0.55...0.70)
                    } else {
                        // Wide: NPC aims past sideline
                        targetNY = CGFloat.random(in: serveMinNY...0.20)
                        targetNX = evenScore
                            ? CGFloat.random(in: -0.10...(-0.03))
                            : CGFloat.random(in: 1.03...1.10)
                    }
                }
            } else {
                targetNY = CGFloat.random(in: serveMinNY...maxNY)
            }

            // Arc computed with normal power — fault power override creates overshoot
            let normalServePower = max(P.serveMinPower, min(P.servePowerCap, shot.power))
            let servePower = faultPowerOverride ?? normalServePower

            let serveDistNY = abs(serveOriginNY - targetNY)
            let serveDistNX = abs(originNX - targetNX)
            let serveArc = DrillShotCalculator.arcToLandAt(
                distanceNY: serveDistNY,
                distanceNX: serveDistNX,
                power: normalServePower
            )

            ballSim.reset()
            ballSim.launch(
                from: CGPoint(x: originNX, y: serveOriginNY),
                toward: CGPoint(x: targetNX, y: targetNY),
                power: servePower,
                arc: serveArc,
                spin: 0
            )

            // Step physics until first bounce or timeout
            let dt: CGFloat = 1.0 / 120.0
            var steps = 0
            let maxSteps = 120 * 5 // 5 seconds max
            while steps < maxSteps && ballSim.isActive && !ballSim.didBounceThisFrame {
                ballSim.update(dt: dt)
                steps += 1
            }

            // Check kitchen fault: bounce on player's side in kitchen zone
            if ballSim.didBounceThisFrame {
                let bounceY = ballSim.lastBounceCourtY
                let bounceX = ballSim.lastBounceCourtX
                if bounceY <= 0.5 && bounceY > kitchenNear {
                    totalFaults += 1
                }
                if ballSim.isLandingOut {
                    totalFaults += 1
                    let _ = bounceX // suppress unused warning
                }
            } else {
                totalFaults += 1
            }
        }

        return Double(totalFaults) / Double(count)
    }

    /// Interpolate fault target for a given DUPR.
    static func targetFaultsPerMatch(dupr: Double) -> Double {
        let targets = faultTargets
        if dupr <= targets.first!.dupr { return targets.first!.faultsPerMatch }
        if dupr >= targets.last!.dupr { return targets.last!.faultsPerMatch }
        for i in 0..<(targets.count - 1) {
            let lo = targets[i]
            let hi = targets[i + 1]
            if dupr >= lo.dupr && dupr <= hi.dupr {
                let t = (dupr - lo.dupr) / (hi.dupr - lo.dupr)
                return lo.faultsPerMatch + t * (hi.faultsPerMatch - lo.faultsPerMatch)
            }
        }
        return targets.last!.faultsPerMatch
    }

    // MARK: - Verify Serve Fault Rates (validation-only)
    //
    // If this test fails, adjust stat curves in stat_profiles.json (offsets/slopes) or
    // NPCStrategyProfile parameters. Do NOT reintroduce mutable GameConstants.

    @Test func verifyServeFaultRates() {
        let testDUPRs: [Double] = [2.0, 3.0, 3.5, 5.0, 6.5, 8.0]

        print("Serve Fault Rate Verification")
        print("==============================")
        print("Targets: \(Self.faultTargets.map { "DUPR \($0.dupr): \($0.faultsPerMatch)/match" }.joined(separator: ", "))")
        print("")

        var allPassed = true
        for dupr in testDUPRs {
            let rate = Self.simulateServeFaultRate(dupr: dupr, count: Self.servesPerTrial)
            let faultsPerMatch = rate * Self.avgServesPerMatch
            let target = Self.targetFaultsPerMatch(dupr: dupr)
            let pass = abs(faultsPerMatch - target) <= Self.tolerance
            if !pass { allPassed = false }
            let status = pass ? "PASS" : "FAIL"
            print("  DUPR \(String(format: "%.1f", dupr)): \(String(format: "%.2f", faultsPerMatch))/match (target: \(String(format: "%.1f", target))) [\(status)]")
        }

        #expect(allPassed, "All DUPR serve fault rates should be within tolerance. Fix: adjust stat_profiles.json or NPCStrategyProfile.")
    }
}
