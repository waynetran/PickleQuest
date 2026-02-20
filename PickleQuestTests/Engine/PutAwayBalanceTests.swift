import Testing
import Foundation
import CoreGraphics
@testable import PickleQuest

@Suite("Put-Away Balance")
struct PutAwayBalanceTests {

    // MARK: - Return Rate Targets

    /// Target return rates for same-DUPR put-away scenarios.
    /// Put-aways are meant to be winners — even skilled players shouldn't return most of them.
    static let returnTargets: [(dupr: Double, returnRate: Double)] = [
        (2.0, 0.00),   // beginners can't return put-aways
        (3.0, 0.10),   // novices rarely get one back
        (4.0, 0.30),   // intermediate returns some
        (5.0, 0.50),   // advanced returns half
        (6.0, 0.60),   // expert returns more but put-aways still win
    ]

    static let returnTolerance: Double = 0.06
    static let trialsPerDUPR = 3000

    // MARK: - Simulate Return Rate

    /// Simulate put-away return rate at a given DUPR by replicating the shouldMakeError formula
    /// inline with the locked put-away constants from GameConstants.
    static func simulatePutAwayReturnRate(
        dupr: Double,
        count: Int
    ) -> Double {
        let PA = GameConstants.PutAway.self
        let P = GameConstants.DrillPhysics.self

        // Create NPC at this DUPR (same-DUPR matchup)
        let npc = NPC.practiceOpponent(dupr: dupr)
        let stats = npc.stats

        // In headless mode: statBoost = 0, hitbox uses player-equivalent formula
        let positioningStat = CGFloat(stats.stat(.positioning))
        let hitboxRadius = P.baseHitboxRadius + (positioningStat / 99.0) * P.positioningHitboxBonus

        let consistencyStat = CGFloat(stats.stat(.consistency))
        let focusStat = CGFloat(stats.stat(.focus))
        let reflexesStat = CGFloat(stats.stat(.reflexes))
        let avgStat = (consistencyStat + focusStat + reflexesStat) / 3.0
        let statFraction = avgStat / 99.0

        var returns = 0

        for _ in 0..<count {
            // Defender positioned at back-court
            let defenderNX = CGFloat.random(in: 0.25...0.75)
            let defenderNY: CGFloat = 0.85

            // Random put-away ball on defender's court half
            let ballX = CGFloat.random(in: 0.10...0.90)
            let ballY = CGFloat.random(in: 0.55...0.90)

            // --- Replicate shouldMakeError formula inline ---
            let baseError: CGFloat = P.npcBaseErrorRate * (1.0 - statFraction)

            // Stretch
            let dx = ballX - defenderNX
            let dy = ballY - defenderNY
            let dist = sqrt(dx * dx + dy * dy)
            let stretchFraction = min(dist / hitboxRadius, 1.0)

            // Simulated ball speed (moderate put-away)
            let ballSpeed = CGFloat.random(in: P.baseShotSpeed...P.maxShotSpeed)
            let maxBallSpeed = P.baseShotSpeed + 2.0 * (P.maxShotSpeed - P.baseShotSpeed)
            let speedFraction = max(0, min(1, (ballSpeed - P.baseShotSpeed) / (maxBallSpeed - P.baseShotSpeed)))
            let spinPressure: CGFloat = CGFloat.random(in: 0...0.3)
            let stretchMultiplier = 0.2 + stretchFraction * 0.8
            let shotDifficulty = min(1.0, speedFraction * 0.8 * stretchMultiplier + spinPressure * 0.3)

            let pressureError: CGFloat = shotDifficulty * P.npcPowerErrorScale * (1.0 - statFraction)
            var errorRate = max(shotDifficulty * P.npcMinPowerErrorFloor, baseError + pressureError)

            // Stretch penalty
            if stretchFraction > 0.6 {
                errorRate *= 1.0 + (stretchFraction - 0.6) * 1.5
            }

            // No DUPR gap (same-DUPR matchup)

            // Put-away formula with locked constants
            let rawReturn = PA.baseReturnRate + CGFloat(dupr - 4.0) * PA.returnDUPRScale
            let clampedReturn = max(PA.returnFloor, min(PA.returnCeiling, rawReturn))
            let adjustedReturn = clampedReturn * (1.0 - stretchFraction * PA.stretchPenalty)
            errorRate = max(errorRate, 1.0 - adjustedReturn)

            let madeError = CGFloat.random(in: 0...1) < errorRate
            if !madeError {
                returns += 1
            }
        }

        return Double(returns) / Double(count)
    }

    // MARK: - Verify Put-Away Return Rates (validation-only)
    //
    // If this test fails, adjust stat curves in stat_profiles.json (offsets/slopes) or
    // NPCStrategyProfile parameters. Do NOT reintroduce mutable GameConstants.

    @Test func verifyPutAwayReturnRates() {
        print("Put-Away Return Rate Verification")
        print("==================================")
        print("Targets: \(Self.returnTargets.map { "DUPR \($0.dupr): \(Int($0.returnRate * 100))%" }.joined(separator: ", "))")
        print("")

        var allPassed = true
        for (dupr, target) in Self.returnTargets {
            let rate = Self.simulatePutAwayReturnRate(dupr: dupr, count: 10_000)
            let pass = Swift.abs(rate - target) <= Self.returnTolerance
            if !pass { allPassed = false }
            let status = pass ? "PASS" : "FAIL"
            print("  DUPR \(String(format: "%.1f", dupr)): \(String(format: "%.1f%%", rate * 100)) (target: \(String(format: "%.0f%%", target * 100))) [\(status)]")
        }

        #expect(allPassed, "All DUPR put-away return rates should be within tolerance. Fix: adjust stat_profiles.json or NPCStrategyProfile.")
    }

    // MARK: - Scatter Validation

    /// Validate that put-away scatter keeps shots in-bounds for reasonable players.
    /// Put-aways are easy balls to place — scatter should be LOW (multiplier < 1.0).
    @Test func validatePutAwayScatter() {
        let scatterMultiplier = GameConstants.PutAway.scatterMultiplier
        print("Put-Away Scatter Validation")
        print("===========================")
        print("scatterMultiplier = \(scatterMultiplier)")

        // Scatter multiplier should be < 1.0 (put-aways are easier to place than normal shots)
        #expect(scatterMultiplier < 1.0, "Put-away scatter multiplier should be < 1.0 (easier to place)")
        #expect(scatterMultiplier > 0.05, "Put-away scatter multiplier should be > 0.05 (not zero)")

        // Validate that DUPR 4.0+ players land 90%+ of put-aways in-bounds
        for dupr in [4.0, 5.0, 6.0] {
            let stats = StatProfileLoader.shared.toNPCStats(dupr: dupr)
            let avgControl = (CGFloat(stats.stat(.accuracy)) + CGFloat(stats.stat(.consistency)) + CGFloat(stats.stat(.focus))) / 3.0
            let scatter = GameConstants.PlayerBalance.baseScatter * (1.0 - avgControl / 99.0) * scatterMultiplier

            var inBounds = 0
            let count = 5000
            for _ in 0..<count {
                let targetNX = CGFloat.random(in: 0.25...0.75)
                let targetNY = CGFloat.random(in: 0.75...0.90)
                let finalNX = targetNX + CGFloat.random(in: -scatter...scatter)
                let finalNY = targetNY + CGFloat.random(in: -scatter...scatter)
                if finalNX >= 0 && finalNX <= 1.0 && finalNY > 0.5 && finalNY <= 1.0 {
                    inBounds += 1
                }
            }
            let rate = Double(inBounds) / Double(count)
            print("  DUPR \(dupr): \(String(format: "%.1f%%", rate * 100)) in-bounds (scatter=\(String(format: "%.4f", scatter)))")
            #expect(rate > 0.90, "DUPR \(dupr) should land 90%+ of put-aways in-bounds")
        }
    }

    // MARK: - Smash Return Rate Targets

    static let smashReturnTargets: [(dupr: Double, returnRate: Double)] = [
        (2.0, 0.10),   // beginners rarely return smashes
        (3.0, 0.25),   // novices get some back
        (4.0, 0.50),   // intermediate returns half
        (5.0, 0.70),   // advanced returns most
        (6.0, 0.80),   // expert returns reliably
    ]

    static let smashReturnTolerance: Double = 0.06

    // MARK: - Simulate Smash Return Rate

    static func simulateSmashReturnRate(
        dupr: Double,
        count: Int
    ) -> Double {
        let SM = GameConstants.Smash.self
        let P = GameConstants.DrillPhysics.self

        let npc = NPC.practiceOpponent(dupr: dupr)
        let stats = npc.stats

        let positioningStat = CGFloat(stats.stat(.positioning))
        let hitboxRadius = P.baseHitboxRadius + (positioningStat / 99.0) * P.positioningHitboxBonus

        let consistencyStat = CGFloat(stats.stat(.consistency))
        let focusStat = CGFloat(stats.stat(.focus))
        let reflexesStat = CGFloat(stats.stat(.reflexes))
        let avgStat = (consistencyStat + focusStat + reflexesStat) / 3.0
        let statFraction = avgStat / 99.0

        var returns = 0

        for _ in 0..<count {
            let defenderNX = CGFloat.random(in: 0.25...0.75)
            let defenderNY: CGFloat = 0.85

            let ballX = CGFloat.random(in: 0.10...0.90)
            let ballY = CGFloat.random(in: 0.55...0.90)

            let baseError: CGFloat = P.npcBaseErrorRate * (1.0 - statFraction)

            let dx = ballX - defenderNX
            let dy = ballY - defenderNY
            let dist = sqrt(dx * dx + dy * dy)
            let stretchFraction = min(dist / hitboxRadius, 1.0)

            let ballSpeed = CGFloat.random(in: P.baseShotSpeed...P.maxShotSpeed)
            let maxBallSpeed = P.baseShotSpeed + 2.0 * (P.maxShotSpeed - P.baseShotSpeed)
            let speedFraction = max(0, min(1, (ballSpeed - P.baseShotSpeed) / (maxBallSpeed - P.baseShotSpeed)))
            let spinPressure: CGFloat = CGFloat.random(in: 0...0.3)
            let stretchMultiplier = 0.2 + stretchFraction * 0.8
            let shotDifficulty = min(1.0, speedFraction * 0.8 * stretchMultiplier + spinPressure * 0.3)

            let pressureError: CGFloat = shotDifficulty * P.npcPowerErrorScale * (1.0 - statFraction)
            var errorRate = max(shotDifficulty * P.npcMinPowerErrorFloor, baseError + pressureError)

            if stretchFraction > 0.6 {
                errorRate *= 1.0 + (stretchFraction - 0.6) * 1.5
            }

            // Smash formula with locked constants (full smash: smashFactor=1.0)
            let smashFactor: CGFloat = 1.0
            let rawReturn = SM.baseReturnRate + CGFloat(dupr - 4.0) * SM.returnDUPRScale
            let clampedReturn = max(SM.returnFloor, min(SM.returnCeiling, rawReturn))
            let adjustedReturn = clampedReturn * (1.0 - stretchFraction * SM.stretchPenalty)
            let smashErrorFloor = 1.0 - adjustedReturn * smashFactor
            errorRate = max(errorRate, smashErrorFloor)

            let madeError = CGFloat.random(in: 0...1) < errorRate
            if !madeError {
                returns += 1
            }
        }

        return Double(returns) / Double(count)
    }

    // MARK: - Verify Smash Return Rates (validation-only)
    //
    // If this test fails, adjust stat curves in stat_profiles.json (offsets/slopes) or
    // NPCStrategyProfile parameters. Do NOT reintroduce mutable GameConstants.

    @Test func verifySmashReturnRates() {
        print("Smash Return Rate Verification")
        print("===============================")
        print("Targets: \(Self.smashReturnTargets.map { "DUPR \($0.dupr): \(Int($0.returnRate * 100))%" }.joined(separator: ", "))")
        print("")

        var allPassed = true
        for (dupr, target) in Self.smashReturnTargets {
            let rate = Self.simulateSmashReturnRate(dupr: dupr, count: 10_000)
            let pass = Swift.abs(rate - target) <= Self.smashReturnTolerance
            if !pass { allPassed = false }
            let status = pass ? "PASS" : "FAIL"
            print("  DUPR \(String(format: "%.1f", dupr)): \(String(format: "%.1f%%", rate * 100)) (target: \(String(format: "%.0f%%", target * 100))) [\(status)]")
        }

        #expect(allPassed, "All DUPR smash return rates should be within tolerance. Fix: adjust stat_profiles.json or NPCStrategyProfile.")
    }
}
