import Testing
import Foundation
import CoreGraphics
@testable import PickleQuest

@Suite("Pressure Drop Shot Balance")
struct PressureDropShotBalanceTests {

    // MARK: - Anchor Targets
    // Targets are linearized from the design doc's S-curve to fit the
    // `rate = clamp(base + (dupr-4)*slope, floor, ceiling)` formula.
    // Tolerance is ±0.10 to accommodate linear approximation of non-linear real behavior.

    /// Drop shot selection rate under pressure (NPC deep, opponent at net)
    static let dropSelectTargets: [(dupr: Double, rate: Double)] = [
        (2.0, 0.12), (3.0, 0.28), (3.5, 0.36),
        (4.5, 0.54), (5.5, 0.66), (6.5, 0.75)
    ]

    /// Drop quality — perfect rate (unattackable kitchen drop)
    /// Stat modifier creates natural non-linearity: low DUPR stats compress the rate down
    static let dropPerfectTargets: [(dupr: Double, rate: Double)] = [
        (2.0, 0.08), (3.0, 0.22), (3.5, 0.35),
        (4.5, 0.55), (5.5, 0.72), (6.5, 0.85)
    ]

    /// Drop quality — error rate (net/out whiff)
    static let dropErrorTargets: [(dupr: Double, rate: Double)] = [
        (2.0, 0.50), (3.0, 0.32), (3.5, 0.22),
        (4.5, 0.13), (5.5, 0.06), (6.5, 0.03)
    ]

    /// Drive quality — clean pass rate under pressure
    static let driveCleanTargets: [(dupr: Double, rate: Double)] = [
        (2.0, 0.15), (3.0, 0.30), (3.5, 0.40),
        (4.5, 0.58), (5.5, 0.72), (6.5, 0.82)
    ]

    /// Kitchen approach after successful drop
    static let kitchenApproachTargets: [(dupr: Double, rate: Double)] = [
        (2.0, 0.12), (3.0, 0.33), (3.5, 0.45),
        (4.5, 0.65), (5.5, 0.85), (6.5, 0.95)
    ]

    static let tolerance: Double = 0.10
    static let trialsPerDUPR = 3000

    // MARK: - Simulation Helpers

    /// Compute rate = clamp(base + (dupr - 4.0) * slope, floor, ceiling)
    private static func duprRate(
        dupr: Double,
        base: CGFloat, slope: CGFloat,
        floor: CGFloat, ceiling: CGFloat
    ) -> CGFloat {
        let raw = base + CGFloat(dupr - 4.0) * slope
        return max(floor, min(ceiling, raw))
    }

    // MARK: - Drop Selection Simulation

    static func simulateDropSelection(
        dupr: Double, count: Int,
        dropBase: CGFloat, dropSlope: CGFloat,
        lobBase: CGFloat, lobSlope: CGFloat
    ) -> Double {
        let PS = GameConstants.PressureShots.self
        var drops = 0
        for _ in 0..<count {
            let dropRate = duprRate(
                dupr: dupr, base: dropBase, slope: dropSlope,
                floor: PS.dropSelectFloor, ceiling: PS.dropSelectCeiling
            )
            let roll = CGFloat.random(in: 0...1)
            if roll < dropRate {
                drops += 1
            }
        }
        return Double(drops) / Double(count)
    }

    // MARK: - Drop Quality Simulation

    static func simulateDropPerfect(
        dupr: Double, count: Int,
        perfectBase: CGFloat, perfectSlope: CGFloat
    ) -> Double {
        let PS = GameConstants.PressureShots.self
        let npc = NPC.practiceOpponent(dupr: dupr)
        let stats = npc.stats

        let avgTouchStat = CGFloat(
            stats.stat(.accuracy) + stats.stat(.consistency) +
            stats.stat(.focus) + stats.stat(.spin)
        ) / 4.0
        let statModifier = avgTouchStat / 99.0

        var perfects = 0
        for _ in 0..<count {
            let rawPerfect = duprRate(
                dupr: dupr, base: perfectBase, slope: perfectSlope,
                floor: PS.dropPerfectFloor, ceiling: PS.dropPerfectCeiling
            )
            let perfectRate = rawPerfect * (0.7 + 0.3 * statModifier)
            if CGFloat.random(in: 0...1) < perfectRate {
                perfects += 1
            }
        }
        return Double(perfects) / Double(count)
    }

    static func simulateDropError(
        dupr: Double, count: Int,
        errorBase: CGFloat, errorSlope: CGFloat
    ) -> Double {
        let PS = GameConstants.PressureShots.self
        let npc = NPC.practiceOpponent(dupr: dupr)
        let stats = npc.stats

        let avgTouchStat = CGFloat(
            stats.stat(.accuracy) + stats.stat(.consistency) +
            stats.stat(.focus) + stats.stat(.spin)
        ) / 4.0
        let statModifier = avgTouchStat / 99.0

        var errors = 0
        for _ in 0..<count {
            let rawError = duprRate(
                dupr: dupr, base: errorBase, slope: errorSlope,
                floor: PS.dropErrorFloor, ceiling: PS.dropErrorCeiling
            )
            let errorRate = rawError * (1.3 - 0.3 * statModifier)
            if CGFloat.random(in: 0...1) < errorRate {
                errors += 1
            }
        }
        return Double(errors) / Double(count)
    }

    // MARK: - Drive Quality Simulation

    static func simulateDriveClean(
        dupr: Double, count: Int,
        cleanBase: CGFloat, cleanSlope: CGFloat
    ) -> Double {
        let PS = GameConstants.PressureShots.self
        let npc = NPC.practiceOpponent(dupr: dupr)
        let stats = npc.stats

        let avgDriveStat = CGFloat(
            stats.stat(.power) + stats.stat(.accuracy) + stats.stat(.speed)
        ) / 3.0
        let statModifier = avgDriveStat / 99.0

        var cleans = 0
        for _ in 0..<count {
            let rawClean = duprRate(
                dupr: dupr, base: cleanBase, slope: cleanSlope,
                floor: PS.driveCleanFloor, ceiling: PS.driveCleanCeiling
            )
            let cleanRate = rawClean * (0.7 + 0.3 * statModifier)
            if CGFloat.random(in: 0...1) < cleanRate {
                cleans += 1
            }
        }
        return Double(cleans) / Double(count)
    }

    // MARK: - Kitchen Approach Simulation

    static func simulateKitchenApproach(
        dupr: Double, count: Int,
        approachBase: CGFloat, approachSlope: CGFloat
    ) -> Double {
        let PS = GameConstants.PressureShots.self
        var approaches = 0
        for _ in 0..<count {
            let rate = duprRate(
                dupr: dupr, base: approachBase, slope: approachSlope,
                floor: PS.kitchenApproachAfterDropFloor, ceiling: PS.kitchenApproachAfterDropCeiling
            )
            if CGFloat.random(in: 0...1) < rate {
                approaches += 1
            }
        }
        return Double(approaches) / Double(count)
    }

    // MARK: - Gradient Helpers

    /// Compute weighted average error across all DUPRs for base adjustment.
    private static func weightedBaseError(_ results: [(dupr: Double, measured: Double, target: Double)]) -> Double {
        var totalErr: Double = 0
        for r in results {
            totalErr += r.measured - r.target
        }
        return totalErr / Double(results.count)
    }

    /// Compute slope error from low vs high DUPR differential.
    private static func slopeError(
        _ results: [(dupr: Double, measured: Double, target: Double)]
    ) -> Double {
        guard let low = results.first, let high = results.last else { return 0 }
        let duprSpan = high.dupr - low.dupr
        guard duprSpan > 0 else { return 0 }
        let measuredSlope = (high.measured - low.measured) / duprSpan
        let targetSlope = (high.target - low.target) / duprSpan
        return measuredSlope - targetSlope
    }

    // MARK: - Tuning Test: Drop Selection

    @Test func tunePressureDropSelection() {
        let maxIterations = 20

        var dropBase = GameConstants.PressureShots.dropSelectBase
        var dropSlope = GameConstants.PressureShots.dropSelectSlope

        var bestDropBase = dropBase
        var bestDropSlope = dropSlope
        var bestTotalError: Double = .infinity

        print("Pressure Drop Selection Tuning")
        print("==============================")

        for iteration in 1...maxIterations {
            var results: [(dupr: Double, measured: Double, target: Double)] = []
            var totalError: Double = 0

            for (dupr, target) in Self.dropSelectTargets {
                let rate = Self.simulateDropSelection(
                    dupr: dupr, count: Self.trialsPerDUPR,
                    dropBase: dropBase, dropSlope: dropSlope,
                    lobBase: GameConstants.PressureShots.lobSelectBase,
                    lobSlope: GameConstants.PressureShots.lobSelectSlope
                )
                let diff = rate - target
                totalError += pow(diff, 2)
                results.append((dupr, rate, target))
            }

            let rmse = sqrt(totalError / Double(results.count))
            print("Iteration \(iteration): dropBase=\(String(format: "%.4f", dropBase)), dropSlope=\(String(format: "%.4f", dropSlope))")
            for r in results {
                let status = Swift.abs(r.measured - r.target) <= Self.tolerance ? "OK" : "MISS"
                print("  DUPR \(String(format: "%.1f", r.dupr)): \(String(format: "%.1f%%", r.measured * 100)) (target: \(String(format: "%.0f%%", r.target * 100))) [\(status)]")
            }
            print("  RMSE: \(String(format: "%.4f", rmse))")

            if totalError < bestTotalError {
                bestTotalError = totalError
                bestDropBase = dropBase
                bestDropSlope = dropSlope
            }

            let allGood = results.allSatisfy { Swift.abs($0.measured - $0.target) <= Self.tolerance }
            if allGood {
                print("\nAll DUPR levels within tolerance after \(iteration) iterations!")
                break
            }

            let lr: CGFloat = 0.5

            // Base: use weighted average across ALL DUPRs
            let avgErr = Self.weightedBaseError(results)
            if Swift.abs(avgErr) > 0.02 {
                dropBase -= CGFloat(avgErr) * lr * 0.5
                dropBase = max(0.10, min(1.0, dropBase))
            }

            // Slope: from low-to-high differential
            let slpErr = Self.slopeError(results)
            if Swift.abs(slpErr) > 0.01 {
                dropSlope -= CGFloat(slpErr) * lr * 0.4
                dropSlope = max(0.02, min(0.50, dropSlope))
            }

            print("")
        }

        dropBase = bestDropBase
        dropSlope = bestDropSlope

        print("\n--- Final Verification (10k trials per DUPR) ---")
        var allPassed = true
        for (dupr, target) in Self.dropSelectTargets {
            let rate = Self.simulateDropSelection(
                dupr: dupr, count: 10_000,
                dropBase: dropBase, dropSlope: dropSlope,
                lobBase: GameConstants.PressureShots.lobSelectBase,
                lobSlope: GameConstants.PressureShots.lobSelectSlope
            )
            let status = Swift.abs(rate - target) <= Self.tolerance ? "PASS" : "FAIL"
            if Swift.abs(rate - target) > Self.tolerance { allPassed = false }
            print("  DUPR \(String(format: "%.1f", dupr)): \(String(format: "%.1f%%", rate * 100)) (target: \(String(format: "%.0f%%", target * 100))) [\(status)]")
        }

        print("\nOptimal drop selection constants:")
        print("  dropSelectBase = \(String(format: "%.4f", dropBase))")
        print("  dropSelectSlope = \(String(format: "%.4f", dropSlope))")

        if allPassed {
            writePressureConstants(
                dropSelectBase: dropBase, dropSelectSlope: dropSlope,
                dropPerfectBase: nil, dropPerfectSlope: nil,
                dropErrorBase: nil, dropErrorSlope: nil,
                driveCleanBase: nil, driveCleanSlope: nil,
                kitchenApproachBase: nil, kitchenApproachSlope: nil
            )
            print("\nDrop selection constants written to GameConstants.swift")
        } else {
            print("\nWARNING: Not all targets met — constants NOT written.")
        }

        #expect(allPassed, "All DUPR drop selection rates should be within tolerance")
    }

    // MARK: - Tuning Test: Drop Quality

    @Test func tunePressureDropQuality() {
        let maxIterations = 20

        var perfectBase = GameConstants.PressureShots.dropPerfectBase
        var perfectSlope = GameConstants.PressureShots.dropPerfectSlope
        var errorBase = GameConstants.PressureShots.dropErrorBase
        var errorSlope = GameConstants.PressureShots.dropErrorSlope

        var bestPerfectBase = perfectBase
        var bestPerfectSlope = perfectSlope
        var bestErrorBase = errorBase
        var bestErrorSlope = errorSlope
        var bestTotalError: Double = .infinity

        print("Pressure Drop Quality Tuning")
        print("============================")

        for iteration in 1...maxIterations {
            var totalError: Double = 0
            var perfectResults: [(dupr: Double, measured: Double, target: Double)] = []
            var errorResults: [(dupr: Double, measured: Double, target: Double)] = []

            for (dupr, target) in Self.dropPerfectTargets {
                let rate = Self.simulateDropPerfect(
                    dupr: dupr, count: Self.trialsPerDUPR,
                    perfectBase: perfectBase, perfectSlope: perfectSlope
                )
                totalError += pow(rate - target, 2)
                perfectResults.append((dupr, rate, target))
            }

            for (dupr, target) in Self.dropErrorTargets {
                let rate = Self.simulateDropError(
                    dupr: dupr, count: Self.trialsPerDUPR,
                    errorBase: errorBase, errorSlope: errorSlope
                )
                totalError += pow(rate - target, 2)
                errorResults.append((dupr, rate, target))
            }

            let totalCount = Double(perfectResults.count + errorResults.count)
            let rmse = sqrt(totalError / totalCount)

            print("Iteration \(iteration): perfectBase=\(String(format: "%.4f", perfectBase)), perfectSlope=\(String(format: "%.4f", perfectSlope)), errorBase=\(String(format: "%.4f", errorBase)), errorSlope=\(String(format: "%.4f", errorSlope))")
            print("  Perfect drops:")
            for r in perfectResults {
                let status = Swift.abs(r.measured - r.target) <= Self.tolerance ? "OK" : "MISS"
                print("    DUPR \(String(format: "%.1f", r.dupr)): \(String(format: "%.1f%%", r.measured * 100)) (target: \(String(format: "%.0f%%", r.target * 100))) [\(status)]")
            }
            print("  Drop errors:")
            for r in errorResults {
                let status = Swift.abs(r.measured - r.target) <= Self.tolerance ? "OK" : "MISS"
                print("    DUPR \(String(format: "%.1f", r.dupr)): \(String(format: "%.1f%%", r.measured * 100)) (target: \(String(format: "%.0f%%", r.target * 100))) [\(status)]")
            }
            print("  RMSE: \(String(format: "%.4f", rmse))")

            if totalError < bestTotalError {
                bestTotalError = totalError
                bestPerfectBase = perfectBase
                bestPerfectSlope = perfectSlope
                bestErrorBase = errorBase
                bestErrorSlope = errorSlope
            }

            let allGood = perfectResults.allSatisfy { Swift.abs($0.measured - $0.target) <= Self.tolerance }
                && errorResults.allSatisfy { Swift.abs($0.measured - $0.target) <= Self.tolerance }
            if allGood {
                print("\nAll DUPR levels within tolerance after \(iteration) iterations!")
                break
            }

            let lr: CGFloat = 0.5

            // Perfect: weighted average base, slope from differential
            let pAvgErr = Self.weightedBaseError(perfectResults)
            if Swift.abs(pAvgErr) > 0.02 {
                perfectBase -= CGFloat(pAvgErr) * lr * 0.5
                perfectBase = max(0.05, min(1.0, perfectBase))
            }
            let pSlpErr = Self.slopeError(perfectResults)
            if Swift.abs(pSlpErr) > 0.01 {
                perfectSlope -= CGFloat(pSlpErr) * lr * 0.4
                perfectSlope = max(0.02, min(0.60, perfectSlope))
            }

            // Error: weighted average base, slope from differential
            let eAvgErr = Self.weightedBaseError(errorResults)
            if Swift.abs(eAvgErr) > 0.02 {
                errorBase -= CGFloat(eAvgErr) * lr * 0.5
                errorBase = max(-0.50, min(1.0, errorBase))
            }
            let eSlpErr = Self.slopeError(errorResults)
            if Swift.abs(eSlpErr) > 0.01 {
                errorSlope -= CGFloat(eSlpErr) * lr * 0.4
                errorSlope = max(-0.60, min(0.0, errorSlope))
            }

            print("")
        }

        perfectBase = bestPerfectBase
        perfectSlope = bestPerfectSlope
        errorBase = bestErrorBase
        errorSlope = bestErrorSlope

        print("\n--- Final Verification (10k trials per DUPR) ---")
        var allPassed = true
        print("  Perfect drops:")
        for (dupr, target) in Self.dropPerfectTargets {
            let rate = Self.simulateDropPerfect(
                dupr: dupr, count: 10_000,
                perfectBase: perfectBase, perfectSlope: perfectSlope
            )
            let status = Swift.abs(rate - target) <= Self.tolerance ? "PASS" : "FAIL"
            if Swift.abs(rate - target) > Self.tolerance { allPassed = false }
            print("    DUPR \(String(format: "%.1f", dupr)): \(String(format: "%.1f%%", rate * 100)) (target: \(String(format: "%.0f%%", target * 100))) [\(status)]")
        }
        print("  Drop errors:")
        for (dupr, target) in Self.dropErrorTargets {
            let rate = Self.simulateDropError(
                dupr: dupr, count: 10_000,
                errorBase: errorBase, errorSlope: errorSlope
            )
            let status = Swift.abs(rate - target) <= Self.tolerance ? "PASS" : "FAIL"
            if Swift.abs(rate - target) > Self.tolerance { allPassed = false }
            print("    DUPR \(String(format: "%.1f", dupr)): \(String(format: "%.1f%%", rate * 100)) (target: \(String(format: "%.0f%%", target * 100))) [\(status)]")
        }

        print("\nOptimal drop quality constants:")
        print("  dropPerfectBase = \(String(format: "%.4f", perfectBase))")
        print("  dropPerfectSlope = \(String(format: "%.4f", perfectSlope))")
        print("  dropErrorBase = \(String(format: "%.4f", errorBase))")
        print("  dropErrorSlope = \(String(format: "%.4f", errorSlope))")

        if allPassed {
            writePressureConstants(
                dropSelectBase: nil, dropSelectSlope: nil,
                dropPerfectBase: perfectBase, dropPerfectSlope: perfectSlope,
                dropErrorBase: errorBase, dropErrorSlope: errorSlope,
                driveCleanBase: nil, driveCleanSlope: nil,
                kitchenApproachBase: nil, kitchenApproachSlope: nil
            )
            print("\nDrop quality constants written to GameConstants.swift")
        } else {
            print("\nWARNING: Not all targets met — constants NOT written.")
        }

        #expect(allPassed, "All DUPR drop quality rates should be within tolerance")
    }

    // MARK: - Tuning Test: Drive Quality

    @Test func tunePressureDriveQuality() {
        let maxIterations = 20

        var cleanBase = GameConstants.PressureShots.driveCleanBase
        var cleanSlope = GameConstants.PressureShots.driveCleanSlope

        var bestCleanBase = cleanBase
        var bestCleanSlope = cleanSlope
        var bestTotalError: Double = .infinity

        print("Pressure Drive Quality Tuning")
        print("=============================")

        for iteration in 1...maxIterations {
            var results: [(dupr: Double, measured: Double, target: Double)] = []
            var totalError: Double = 0

            for (dupr, target) in Self.driveCleanTargets {
                let rate = Self.simulateDriveClean(
                    dupr: dupr, count: Self.trialsPerDUPR,
                    cleanBase: cleanBase, cleanSlope: cleanSlope
                )
                totalError += pow(rate - target, 2)
                results.append((dupr, rate, target))
            }

            let rmse = sqrt(totalError / Double(results.count))
            print("Iteration \(iteration): cleanBase=\(String(format: "%.4f", cleanBase)), cleanSlope=\(String(format: "%.4f", cleanSlope))")
            for r in results {
                let status = Swift.abs(r.measured - r.target) <= Self.tolerance ? "OK" : "MISS"
                print("  DUPR \(String(format: "%.1f", r.dupr)): \(String(format: "%.1f%%", r.measured * 100)) (target: \(String(format: "%.0f%%", r.target * 100))) [\(status)]")
            }
            print("  RMSE: \(String(format: "%.4f", rmse))")

            if totalError < bestTotalError {
                bestTotalError = totalError
                bestCleanBase = cleanBase
                bestCleanSlope = cleanSlope
            }

            let allGood = results.allSatisfy { Swift.abs($0.measured - $0.target) <= Self.tolerance }
            if allGood {
                print("\nAll DUPR levels within tolerance after \(iteration) iterations!")
                break
            }

            let lr: CGFloat = 0.5
            let avgErr = Self.weightedBaseError(results)
            if Swift.abs(avgErr) > 0.02 {
                cleanBase -= CGFloat(avgErr) * lr * 0.5
                cleanBase = max(0.10, min(1.0, cleanBase))
            }
            let slpErr = Self.slopeError(results)
            if Swift.abs(slpErr) > 0.01 {
                cleanSlope -= CGFloat(slpErr) * lr * 0.4
                cleanSlope = max(0.02, min(0.50, cleanSlope))
            }

            print("")
        }

        cleanBase = bestCleanBase
        cleanSlope = bestCleanSlope

        print("\n--- Final Verification (10k trials per DUPR) ---")
        var allPassed = true
        for (dupr, target) in Self.driveCleanTargets {
            let rate = Self.simulateDriveClean(
                dupr: dupr, count: 10_000,
                cleanBase: cleanBase, cleanSlope: cleanSlope
            )
            let status = Swift.abs(rate - target) <= Self.tolerance ? "PASS" : "FAIL"
            if Swift.abs(rate - target) > Self.tolerance { allPassed = false }
            print("  DUPR \(String(format: "%.1f", dupr)): \(String(format: "%.1f%%", rate * 100)) (target: \(String(format: "%.0f%%", target * 100))) [\(status)]")
        }

        print("\nOptimal drive quality constants:")
        print("  driveCleanBase = \(String(format: "%.4f", cleanBase))")
        print("  driveCleanSlope = \(String(format: "%.4f", cleanSlope))")

        if allPassed {
            writePressureConstants(
                dropSelectBase: nil, dropSelectSlope: nil,
                dropPerfectBase: nil, dropPerfectSlope: nil,
                dropErrorBase: nil, dropErrorSlope: nil,
                driveCleanBase: cleanBase, driveCleanSlope: cleanSlope,
                kitchenApproachBase: nil, kitchenApproachSlope: nil
            )
            print("\nDrive quality constants written to GameConstants.swift")
        } else {
            print("\nWARNING: Not all targets met — constants NOT written.")
        }

        #expect(allPassed, "All DUPR drive quality rates should be within tolerance")
    }

    // MARK: - Tuning Test: Kitchen Approach

    @Test func tunePressureKitchenApproach() {
        let maxIterations = 20

        var approachBase = GameConstants.PressureShots.kitchenApproachAfterDropBase
        var approachSlope = GameConstants.PressureShots.kitchenApproachAfterDropSlope

        var bestApproachBase = approachBase
        var bestApproachSlope = approachSlope
        var bestTotalError: Double = .infinity

        print("Pressure Kitchen Approach Tuning")
        print("================================")

        for iteration in 1...maxIterations {
            var results: [(dupr: Double, measured: Double, target: Double)] = []
            var totalError: Double = 0

            for (dupr, target) in Self.kitchenApproachTargets {
                let rate = Self.simulateKitchenApproach(
                    dupr: dupr, count: Self.trialsPerDUPR,
                    approachBase: approachBase, approachSlope: approachSlope
                )
                totalError += pow(rate - target, 2)
                results.append((dupr, rate, target))
            }

            let rmse = sqrt(totalError / Double(results.count))
            print("Iteration \(iteration): approachBase=\(String(format: "%.4f", approachBase)), approachSlope=\(String(format: "%.4f", approachSlope))")
            for r in results {
                let status = Swift.abs(r.measured - r.target) <= Self.tolerance ? "OK" : "MISS"
                print("  DUPR \(String(format: "%.1f", r.dupr)): \(String(format: "%.1f%%", r.measured * 100)) (target: \(String(format: "%.0f%%", r.target * 100))) [\(status)]")
            }
            print("  RMSE: \(String(format: "%.4f", rmse))")

            if totalError < bestTotalError {
                bestTotalError = totalError
                bestApproachBase = approachBase
                bestApproachSlope = approachSlope
            }

            let allGood = results.allSatisfy { Swift.abs($0.measured - $0.target) <= Self.tolerance }
            if allGood {
                print("\nAll DUPR levels within tolerance after \(iteration) iterations!")
                break
            }

            let lr: CGFloat = 0.5
            let avgErr = Self.weightedBaseError(results)
            if Swift.abs(avgErr) > 0.02 {
                approachBase -= CGFloat(avgErr) * lr * 0.5
                approachBase = max(0.05, min(1.0, approachBase))
            }
            let slpErr = Self.slopeError(results)
            if Swift.abs(slpErr) > 0.01 {
                approachSlope -= CGFloat(slpErr) * lr * 0.4
                approachSlope = max(0.05, min(0.60, approachSlope))
            }

            print("")
        }

        approachBase = bestApproachBase
        approachSlope = bestApproachSlope

        print("\n--- Final Verification (10k trials per DUPR) ---")
        var allPassed = true
        for (dupr, target) in Self.kitchenApproachTargets {
            let rate = Self.simulateKitchenApproach(
                dupr: dupr, count: 10_000,
                approachBase: approachBase, approachSlope: approachSlope
            )
            let status = Swift.abs(rate - target) <= Self.tolerance ? "PASS" : "FAIL"
            if Swift.abs(rate - target) > Self.tolerance { allPassed = false }
            print("  DUPR \(String(format: "%.1f", dupr)): \(String(format: "%.1f%%", rate * 100)) (target: \(String(format: "%.0f%%", target * 100))) [\(status)]")
        }

        print("\nOptimal kitchen approach constants:")
        print("  kitchenApproachAfterDropBase = \(String(format: "%.4f", approachBase))")
        print("  kitchenApproachAfterDropSlope = \(String(format: "%.4f", approachSlope))")

        if allPassed {
            writePressureConstants(
                dropSelectBase: nil, dropSelectSlope: nil,
                dropPerfectBase: nil, dropPerfectSlope: nil,
                dropErrorBase: nil, dropErrorSlope: nil,
                driveCleanBase: nil, driveCleanSlope: nil,
                kitchenApproachBase: approachBase, kitchenApproachSlope: approachSlope
            )
            print("\nKitchen approach constants written to GameConstants.swift")
        } else {
            print("\nWARNING: Not all targets met — constants NOT written.")
        }

        #expect(allPassed, "All DUPR kitchen approach rates should be within tolerance")
    }

    // MARK: - Write Constants

    private func writePressureConstants(
        dropSelectBase: CGFloat?, dropSelectSlope: CGFloat?,
        dropPerfectBase: CGFloat?, dropPerfectSlope: CGFloat?,
        dropErrorBase: CGFloat?, dropErrorSlope: CGFloat?,
        driveCleanBase: CGFloat?, driveCleanSlope: CGFloat?,
        kitchenApproachBase: CGFloat?, kitchenApproachSlope: CGFloat?
    ) {
        guard var source = readGameConstants() else { return }

        if let range = source.range(of: "enum PressureShots \\{[\\s\\S]*?\\n    \\}", options: .regularExpression) {
            var block = String(source[range])

            if let v = dropSelectBase {
                replace(in: &block,
                        #"static let dropSelectBase: CGFloat = [-\d.]+"#,
                        with: "static let dropSelectBase: CGFloat = \(String(format: "%.4f", v))")
            }
            if let v = dropSelectSlope {
                replace(in: &block,
                        #"static let dropSelectSlope: CGFloat = [-\d.]+"#,
                        with: "static let dropSelectSlope: CGFloat = \(String(format: "%.4f", v))")
            }
            if let v = dropPerfectBase {
                replace(in: &block,
                        #"static let dropPerfectBase: CGFloat = [-\d.]+"#,
                        with: "static let dropPerfectBase: CGFloat = \(String(format: "%.4f", v))")
            }
            if let v = dropPerfectSlope {
                replace(in: &block,
                        #"static let dropPerfectSlope: CGFloat = [-\d.]+"#,
                        with: "static let dropPerfectSlope: CGFloat = \(String(format: "%.4f", v))")
            }
            if let v = dropErrorBase {
                replace(in: &block,
                        #"static let dropErrorBase: CGFloat = [-\d.]+"#,
                        with: "static let dropErrorBase: CGFloat = \(String(format: "%.4f", v))")
            }
            if let v = dropErrorSlope {
                replace(in: &block,
                        #"static let dropErrorSlope: CGFloat = [-\d.]+"#,
                        with: "static let dropErrorSlope: CGFloat = \(String(format: "%.4f", v))")
            }
            if let v = driveCleanBase {
                replace(in: &block,
                        #"static let driveCleanBase: CGFloat = [-\d.]+"#,
                        with: "static let driveCleanBase: CGFloat = \(String(format: "%.4f", v))")
            }
            if let v = driveCleanSlope {
                replace(in: &block,
                        #"static let driveCleanSlope: CGFloat = [-\d.]+"#,
                        with: "static let driveCleanSlope: CGFloat = \(String(format: "%.4f", v))")
            }
            if let v = kitchenApproachBase {
                replace(in: &block,
                        #"static let kitchenApproachAfterDropBase: CGFloat = [-\d.]+"#,
                        with: "static let kitchenApproachAfterDropBase: CGFloat = \(String(format: "%.4f", v))")
            }
            if let v = kitchenApproachSlope {
                replace(in: &block,
                        #"static let kitchenApproachAfterDropSlope: CGFloat = [-\d.]+"#,
                        with: "static let kitchenApproachAfterDropSlope: CGFloat = \(String(format: "%.4f", v))")
            }

            source.replaceSubrange(range, with: block)
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
