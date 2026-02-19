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
    /// inline with parameterized put-away constants (since static lets can't be mutated at runtime).
    static func simulatePutAwayReturnRate(
        dupr: Double,
        count: Int,
        baseReturnRate: CGFloat,
        returnDUPRScale: CGFloat,
        stretchPenalty: CGFloat
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

            // Put-away formula with parameterized constants
            let rawReturn = baseReturnRate + CGFloat(dupr - 4.0) * returnDUPRScale
            let clampedReturn = max(PA.returnFloor, min(PA.returnCeiling, rawReturn))
            let adjustedReturn = clampedReturn * (1.0 - stretchFraction * stretchPenalty)
            errorRate = max(errorRate, 1.0 - adjustedReturn)

            let madeError = CGFloat.random(in: 0...1) < errorRate
            if !madeError {
                returns += 1
            }
        }

        return Double(returns) / Double(count)
    }

    // MARK: - Feedback Loop: Return Rates

    @Test func tunePutAwayReturnRates() {
        let testDUPRs: [Double] = Self.returnTargets.map { $0.dupr }
        let maxIterations = 20

        // Start from current constants
        var baseReturnRate = GameConstants.PutAway.baseReturnRate
        var returnDUPRScale = GameConstants.PutAway.returnDUPRScale
        var stretchPenalty = GameConstants.PutAway.stretchPenalty

        var bestBaseReturn = baseReturnRate
        var bestDUPRScale = returnDUPRScale
        var bestStretchPenalty = stretchPenalty
        var bestTotalError: Double = .infinity

        print("Put-Away Return Rate Tuning")
        print("===========================")
        print("Targets: \(Self.returnTargets.map { "DUPR \($0.dupr): \(Int($0.returnRate * 100))%" }.joined(separator: ", "))")
        print("")

        for iteration in 1...maxIterations {
            var results: [(dupr: Double, measured: Double, target: Double)] = []
            var totalError: Double = 0

            for (dupr, target) in Self.returnTargets {
                let rate = Self.simulatePutAwayReturnRate(
                    dupr: dupr,
                    count: Self.trialsPerDUPR,
                    baseReturnRate: baseReturnRate,
                    returnDUPRScale: returnDUPRScale,
                    stretchPenalty: stretchPenalty
                )
                let diff = rate - target
                totalError += diff * diff
                results.append((dupr, rate, target))
            }

            let rmse = sqrt(totalError / Double(testDUPRs.count))

            print("Iteration \(iteration): baseReturn=\(String(format: "%.4f", baseReturnRate)), duprScale=\(String(format: "%.4f", returnDUPRScale)), stretchPenalty=\(String(format: "%.4f", stretchPenalty))")
            for r in results {
                let status = Swift.abs(r.measured - r.target) <= Self.returnTolerance ? "OK" : "MISS"
                print("  DUPR \(String(format: "%.1f", r.dupr)): \(String(format: "%.1f%%", r.measured * 100)) (target: \(String(format: "%.0f%%", r.target * 100))) [\(status)]")
            }
            print("  RMSE: \(String(format: "%.4f", rmse))")

            if totalError < bestTotalError {
                bestTotalError = totalError
                bestBaseReturn = baseReturnRate
                bestDUPRScale = returnDUPRScale
                bestStretchPenalty = stretchPenalty
            }

            let allGood = results.allSatisfy { Swift.abs($0.measured - $0.target) <= Self.returnTolerance }
            if allGood {
                print("\nAll DUPR levels within tolerance after \(iteration) iterations!")
                break
            }

            // --- Gradient adjustments ---
            // Higher baseReturnRate → more returns; higher stretchPenalty → fewer returns
            let lr: CGFloat = 0.5

            // Mid-DUPR (4.0) drives baseReturnRate
            let midResult = results.first { $0.dupr == 4.0 }!
            let midError = midResult.measured - midResult.target
            if Swift.abs(midError) > Self.returnTolerance {
                // Positive midError = too many returns → decrease baseReturnRate
                baseReturnRate -= CGFloat(midError) * lr * 0.4
                baseReturnRate = max(0.10, min(2.0, baseReturnRate))
            }

            // Slope between DUPR 2.0 and 6.0 drives returnDUPRScale
            let lowResult = results.first { $0.dupr == 2.0 }!
            let highResult = results.first { $0.dupr == 6.0 }!
            let measuredSlope = (highResult.measured - lowResult.measured) / 4.0  // per 1.0 DUPR
            let targetSlope = (highResult.target - lowResult.target) / 4.0
            let slopeError = measuredSlope - targetSlope
            if Swift.abs(slopeError) > 0.02 {
                // Positive slopeError = slope too steep → decrease returnDUPRScale
                returnDUPRScale -= CGFloat(slopeError) * lr * 0.3
                returnDUPRScale = max(0.05, min(1.0, returnDUPRScale))
            }

            // High-DUPR overshoot drives stretchPenalty
            let highError = highResult.measured - highResult.target
            if Swift.abs(highError) > Self.returnTolerance {
                // Positive highError = too many returns → increase stretch penalty
                stretchPenalty += CGFloat(highError) * lr * 0.3
                stretchPenalty = max(0.05, min(0.80, stretchPenalty))
            }

            print("")
        }

        // Use best parameters
        baseReturnRate = bestBaseReturn
        returnDUPRScale = bestDUPRScale
        stretchPenalty = bestStretchPenalty

        // Final verification with more samples
        print("\n--- Final Verification (10k trials per DUPR) ---")
        var allPassed = true
        for (dupr, target) in Self.returnTargets {
            let rate = Self.simulatePutAwayReturnRate(
                dupr: dupr,
                count: 10_000,
                baseReturnRate: baseReturnRate,
                returnDUPRScale: returnDUPRScale,
                stretchPenalty: stretchPenalty
            )
            let status = Swift.abs(rate - target) <= Self.returnTolerance ? "PASS" : "FAIL"
            if Swift.abs(rate - target) > Self.returnTolerance { allPassed = false }
            print("  DUPR \(String(format: "%.1f", dupr)): \(String(format: "%.1f%%", rate * 100)) (target: \(String(format: "%.0f%%", target * 100))) [\(status)]")
        }

        print("\nOptimal return rate constants:")
        print("  baseReturnRate = \(String(format: "%.4f", baseReturnRate))")
        print("  returnDUPRScale = \(String(format: "%.4f", returnDUPRScale))")
        print("  stretchPenalty = \(String(format: "%.4f", stretchPenalty))")

        if allPassed {
            writeReturnConstants(
                baseReturnRate: baseReturnRate,
                returnDUPRScale: returnDUPRScale,
                stretchPenalty: stretchPenalty
            )
            print("\nReturn rate constants written to GameConstants.swift")
        } else {
            print("\nWARNING: Not all targets met — constants NOT written. Review and re-run.")
        }

        #expect(allPassed, "All DUPR put-away return rates should be within tolerance of targets")
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
        count: Int,
        baseReturnRate: CGFloat,
        returnDUPRScale: CGFloat,
        stretchPenalty: CGFloat
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

            // Smash formula with parameterized constants (full smash: smashFactor=1.0)
            let smashFactor: CGFloat = 1.0
            let rawReturn = baseReturnRate + CGFloat(dupr - 4.0) * returnDUPRScale
            let clampedReturn = max(SM.returnFloor, min(SM.returnCeiling, rawReturn))
            let adjustedReturn = clampedReturn * (1.0 - stretchFraction * stretchPenalty)
            let smashErrorFloor = 1.0 - adjustedReturn * smashFactor
            errorRate = max(errorRate, smashErrorFloor)

            let madeError = CGFloat.random(in: 0...1) < errorRate
            if !madeError {
                returns += 1
            }
        }

        return Double(returns) / Double(count)
    }

    // MARK: - Feedback Loop: Smash Return Rates

    @Test func tuneSmashReturnRates() {
        let testDUPRs: [Double] = Self.smashReturnTargets.map { $0.dupr }
        let maxIterations = 20

        var baseReturnRate = GameConstants.Smash.baseReturnRate
        var returnDUPRScale = GameConstants.Smash.returnDUPRScale
        var stretchPenalty = GameConstants.Smash.stretchPenalty

        var bestBaseReturn = baseReturnRate
        var bestDUPRScale = returnDUPRScale
        var bestStretchPenalty = stretchPenalty
        var bestTotalError: Double = .infinity

        print("Smash Return Rate Tuning")
        print("========================")
        print("Targets: \(Self.smashReturnTargets.map { "DUPR \($0.dupr): \(Int($0.returnRate * 100))%" }.joined(separator: ", "))")
        print("")

        for iteration in 1...maxIterations {
            var results: [(dupr: Double, measured: Double, target: Double)] = []
            var totalError: Double = 0

            for (dupr, target) in Self.smashReturnTargets {
                let rate = Self.simulateSmashReturnRate(
                    dupr: dupr,
                    count: Self.trialsPerDUPR,
                    baseReturnRate: baseReturnRate,
                    returnDUPRScale: returnDUPRScale,
                    stretchPenalty: stretchPenalty
                )
                let diff = rate - target
                totalError += diff * diff
                results.append((dupr, rate, target))
            }

            let rmse = sqrt(totalError / Double(testDUPRs.count))

            print("Iteration \(iteration): baseReturn=\(String(format: "%.4f", baseReturnRate)), duprScale=\(String(format: "%.4f", returnDUPRScale)), stretchPenalty=\(String(format: "%.4f", stretchPenalty))")
            for r in results {
                let status = Swift.abs(r.measured - r.target) <= Self.smashReturnTolerance ? "OK" : "MISS"
                print("  DUPR \(String(format: "%.1f", r.dupr)): \(String(format: "%.1f%%", r.measured * 100)) (target: \(String(format: "%.0f%%", r.target * 100))) [\(status)]")
            }
            print("  RMSE: \(String(format: "%.4f", rmse))")

            if totalError < bestTotalError {
                bestTotalError = totalError
                bestBaseReturn = baseReturnRate
                bestDUPRScale = returnDUPRScale
                bestStretchPenalty = stretchPenalty
            }

            let allGood = results.allSatisfy { Swift.abs($0.measured - $0.target) <= Self.smashReturnTolerance }
            if allGood {
                print("\nAll DUPR levels within tolerance after \(iteration) iterations!")
                break
            }

            // Gradient adjustments (same pattern as put-away tuning)
            let lr: CGFloat = 0.5

            let midResult = results.first { $0.dupr == 4.0 }!
            let midError = midResult.measured - midResult.target
            if Swift.abs(midError) > Self.smashReturnTolerance {
                baseReturnRate -= CGFloat(midError) * lr * 0.4
                baseReturnRate = max(0.10, min(2.0, baseReturnRate))
            }

            let lowResult = results.first { $0.dupr == 2.0 }!
            let highResult = results.first { $0.dupr == 6.0 }!
            let measuredSlope = (highResult.measured - lowResult.measured) / 4.0
            let targetSlope = (highResult.target - lowResult.target) / 4.0
            let slopeError = measuredSlope - targetSlope
            if Swift.abs(slopeError) > 0.02 {
                returnDUPRScale -= CGFloat(slopeError) * lr * 0.3
                returnDUPRScale = max(0.05, min(1.0, returnDUPRScale))
            }

            let highError = highResult.measured - highResult.target
            if Swift.abs(highError) > Self.smashReturnTolerance {
                stretchPenalty += CGFloat(highError) * lr * 0.3
                stretchPenalty = max(0.05, min(0.80, stretchPenalty))
            }

            print("")
        }

        baseReturnRate = bestBaseReturn
        returnDUPRScale = bestDUPRScale
        stretchPenalty = bestStretchPenalty

        print("\n--- Final Verification (10k trials per DUPR) ---")
        var allPassed = true
        for (dupr, target) in Self.smashReturnTargets {
            let rate = Self.simulateSmashReturnRate(
                dupr: dupr,
                count: 10_000,
                baseReturnRate: baseReturnRate,
                returnDUPRScale: returnDUPRScale,
                stretchPenalty: stretchPenalty
            )
            let status = Swift.abs(rate - target) <= Self.smashReturnTolerance ? "PASS" : "FAIL"
            if Swift.abs(rate - target) > Self.smashReturnTolerance { allPassed = false }
            print("  DUPR \(String(format: "%.1f", dupr)): \(String(format: "%.1f%%", rate * 100)) (target: \(String(format: "%.0f%%", target * 100))) [\(status)]")
        }

        print("\nOptimal smash return rate constants:")
        print("  baseReturnRate = \(String(format: "%.4f", baseReturnRate))")
        print("  returnDUPRScale = \(String(format: "%.4f", returnDUPRScale))")
        print("  stretchPenalty = \(String(format: "%.4f", stretchPenalty))")

        if allPassed {
            writeSmashConstants(
                baseReturnRate: baseReturnRate,
                returnDUPRScale: returnDUPRScale,
                stretchPenalty: stretchPenalty
            )
            print("\nSmash return rate constants written to GameConstants.swift")
        } else {
            print("\nWARNING: Not all targets met — constants NOT written. Review and re-run.")
        }

        #expect(allPassed, "All DUPR smash return rates should be within tolerance of targets")
    }

    // MARK: - Write Constants

    private func writeSmashConstants(
        baseReturnRate: CGFloat,
        returnDUPRScale: CGFloat,
        stretchPenalty: CGFloat
    ) {
        guard var source = readGameConstants() else { return }

        // Scope replacements to the Smash enum block to avoid clobbering PutAway constants
        if let smashRange = source.range(of: "enum Smash \\{[\\s\\S]*?\\}", options: .regularExpression) {
            var smashBlock = String(source[smashRange])
            replace(in: &smashBlock,
                    #"static let baseReturnRate: CGFloat = [\d.]+"#,
                    with: "static let baseReturnRate: CGFloat = \(String(format: "%.4f", baseReturnRate))")
            replace(in: &smashBlock,
                    #"static let returnDUPRScale: CGFloat = [\d.]+"#,
                    with: "static let returnDUPRScale: CGFloat = \(String(format: "%.4f", returnDUPRScale))")
            replace(in: &smashBlock,
                    #"static let stretchPenalty: CGFloat = [\d.]+"#,
                    with: "static let stretchPenalty: CGFloat = \(String(format: "%.4f", stretchPenalty))")
            source.replaceSubrange(smashRange, with: smashBlock)
        }

        writeGameConstants(source)
    }

    private func writeReturnConstants(
        baseReturnRate: CGFloat,
        returnDUPRScale: CGFloat,
        stretchPenalty: CGFloat
    ) {
        guard var source = readGameConstants() else { return }

        // Scope replacements to the PutAway enum block to avoid clobbering Smash constants
        if let putAwayRange = source.range(of: "enum PutAway \\{[\\s\\S]*?\\}", options: .regularExpression) {
            var putAwayBlock = String(source[putAwayRange])
            replace(in: &putAwayBlock,
                    #"static let baseReturnRate: CGFloat = [\d.]+"#,
                    with: "static let baseReturnRate: CGFloat = \(String(format: "%.4f", baseReturnRate))")
            replace(in: &putAwayBlock,
                    #"static let returnDUPRScale: CGFloat = [\d.]+"#,
                    with: "static let returnDUPRScale: CGFloat = \(String(format: "%.4f", returnDUPRScale))")
            replace(in: &putAwayBlock,
                    #"static let stretchPenalty: CGFloat = [\d.]+"#,
                    with: "static let stretchPenalty: CGFloat = \(String(format: "%.4f", stretchPenalty))")
            source.replaceSubrange(putAwayRange, with: putAwayBlock)
        }

        writeGameConstants(source)
    }

    // MARK: - File Helpers

    private func gameConstantsURL() -> URL {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent() // Engine/
            .deletingLastPathComponent() // PickleQuestTests/
            .deletingLastPathComponent() // repo root
        return repoRoot
            .appendingPathComponent("PickleQuest")
            .appendingPathComponent("Models")
            .appendingPathComponent("Common")
            .appendingPathComponent("GameConstants.swift")
    }

    private func readGameConstants() -> String? {
        guard let source = try? String(contentsOf: gameConstantsURL(), encoding: .utf8) else {
            print("ERROR: Could not read GameConstants.swift")
            return nil
        }
        return source
    }

    private func writeGameConstants(_ source: String) {
        try? source.write(to: gameConstantsURL(), atomically: true, encoding: .utf8)
    }

    private func replace(in source: inout String, _ pattern: String, with value: String) {
        if let range = source.range(of: pattern, options: .regularExpression) {
            source.replaceSubrange(range, with: value)
        }
    }
}
