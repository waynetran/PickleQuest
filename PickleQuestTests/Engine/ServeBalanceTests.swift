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
    static let servesPerTrial = 5000            // serves per DUPR level for stats
    static let avgServesPerMatch: Double = 11.0 // ~22 points, each side serves ~11

    // MARK: - Simulate Serves

    /// Simulate `count` NPC serves at the given DUPR and return the fraction that fault.
    static func simulateServeFaultRate(
        dupr: Double,
        count: Int,
        baseFaultRate: CGFloat,
        serveMinNY: CGFloat,
        serveMaxNY_Low: CGFloat,
        serveMaxNY_High: CGFloat
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
        let statFaultRate = baseFaultRate * pow(1.0 - serveStat / 99.0, P.npcServeFaultStatExponent)

        // Serve mode selection (same as InteractiveMatchScene.npcServe)
        let duprFrac = CGFloat(max(0, min(1, (dupr - 2.0) / 6.0)))
        let maxNY = serveMaxNY_Low + duprFrac * (serveMaxNY_High - serveMaxNY_Low)

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
        var dbgDoubleFault = 0, dbgKitchen = 0, dbgOutX = 0, dbgOutY = 0, dbgTimeout = 0
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

            if isDoubleFault {
                totalFaults += 1
                // Classify fault type (matches npcServe logic)
                let hasSpin = modes.contains(.topspin) || modes.contains(.slice)
                let kitchenFaultChance = hasSpin ? duprFrac * 0.4 : 0.0
                if CGFloat.random(in: 0...1) < kitchenFaultChance {
                    dbgKitchen += 1
                } else if CGFloat.random(in: 0...1) < 0.6 {
                    dbgOutY += 1  // long
                } else {
                    dbgOutX += 1  // wide
                }
                continue
            }

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

            // Override target (same as InteractiveMatchScene.npcServe)
            let evenScore = i % 2 == 0
            let originNX: CGFloat = evenScore ? 0.75 : 0.25
            let targetNX: CGFloat = evenScore ? 0.25 : 0.75
            let targetNY = CGFloat.random(in: serveMinNY...maxNY)

            // Physics-based arc (matches InteractiveMatchScene.npcServe — flat, no spin)
            let serveDistNY = abs(serveOriginNY - targetNY)
            let serveDistNX = abs(originNX - targetNX)
            let serveArc = DrillShotCalculator.arcToLandAt(
                distanceNY: serveDistNY,
                distanceNX: serveDistNX,
                power: shot.power
            )

            let servePower = shot.power

            // Flat serve launch — spin/topspin modeled by stat-based fault rate (matches npcServe)
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
                    dbgKitchen += 1
                }
                if ballSim.isLandingOut {
                    totalFaults += 1
                    if bounceX < 0 || bounceX > 1 { dbgOutX += 1 }
                    else { dbgOutY += 1 }
                }
            } else {
                totalFaults += 1
                dbgTimeout += 1
            }
        }

        if count >= 5000 {
            print("    [DBG DUPR \(String(format: "%.1f", dupr))]: faults=\(dbgDoubleFault) (long=\(dbgOutY) wide=\(dbgOutX) kitchen=\(dbgKitchen)) physics: outX=\(dbgOutX) outY=\(dbgOutY) timeout=\(dbgTimeout) total=\(totalFaults)/\(count)")
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

    // MARK: - Feedback Loop Test

    /// Iteratively adjust serve constants until fault rates match targets at all DUPR levels.
    ///
    /// Run explicitly:
    /// ```
    /// xcodebuild test -project PickleQuest.xcodeproj -scheme PickleQuest \
    ///   -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    ///   -only-testing 'PickleQuestTests/ServeBalanceTests'
    /// ```
    @Test func tuneServeFaultRates() {
        let testDUPRs: [Double] = [2.0, 3.0, 3.5, 5.0, 6.5, 8.0]
        let maxIterations = 20

        // Start from current constants
        var baseFaultRate = GameConstants.DrillPhysics.npcBaseServeFaultRate
        var serveMinNY = GameConstants.NPCStrategy.npcServeTargetMinNY
        var serveMaxNY_Low = GameConstants.NPCStrategy.npcServeTargetMaxNY_Low
        var serveMaxNY_High = GameConstants.NPCStrategy.npcServeTargetMaxNY_High

        var bestBaseFaultRate = baseFaultRate
        var bestMaxNY_Low = serveMaxNY_Low
        var bestMaxNY_High = serveMaxNY_High
        var bestTotalError: Double = .infinity

        print("Serve Balance Tuning")
        print("====================")
        print("Targets: \(Self.faultTargets.map { "DUPR \($0.dupr): \($0.faultsPerMatch)/match" }.joined(separator: ", "))")
        print("")

        for iteration in 1...maxIterations {
            // Measure current fault rates
            var results: [(dupr: Double, faultRate: Double, faultsPerMatch: Double, target: Double)] = []
            var totalError: Double = 0

            for dupr in testDUPRs {
                let rate = Self.simulateServeFaultRate(
                    dupr: dupr,
                    count: Self.servesPerTrial,
                    baseFaultRate: baseFaultRate,
                    serveMinNY: serveMinNY,
                    serveMaxNY_Low: serveMaxNY_Low,
                    serveMaxNY_High: serveMaxNY_High
                )
                let faultsPerMatch = rate * Self.avgServesPerMatch
                let target = Self.targetFaultsPerMatch(dupr: dupr)
                let diff = faultsPerMatch - target
                totalError += diff * diff
                results.append((dupr, rate, faultsPerMatch, target))
            }

            let rmse = sqrt(totalError / Double(testDUPRs.count))

            print("Iteration \(iteration): baseFaultRate=\(String(format: "%.4f", baseFaultRate)), maxNY_Low=\(String(format: "%.3f", serveMaxNY_Low)), maxNY_High=\(String(format: "%.3f", serveMaxNY_High))")
            for r in results {
                let status = abs(r.faultsPerMatch - r.target) <= Self.tolerance ? "OK" : "MISS"
                print("  DUPR \(String(format: "%.1f", r.dupr)): \(String(format: "%.2f", r.faultsPerMatch))/match (target: \(String(format: "%.1f", r.target))) [\(status)]")
            }
            print("  RMSE: \(String(format: "%.3f", rmse))")

            if totalError < bestTotalError {
                bestTotalError = totalError
                bestBaseFaultRate = baseFaultRate
                bestMaxNY_Low = serveMaxNY_Low
                bestMaxNY_High = serveMaxNY_High
            }

            // Check if all within tolerance
            let allGood = results.allSatisfy { abs($0.faultsPerMatch - $0.target) <= Self.tolerance }
            if allGood {
                print("\nAll DUPR levels within tolerance after \(iteration) iterations!")
                break
            }

            // Adjust constants based on errors
            // Low DUPR error → adjust baseFaultRate (dominant factor for low stats)
            // High DUPR error → adjust serveMaxNY_High (kitchen proximity)
            let lowDUPRResult = results.first { $0.dupr == 2.0 }!
            let highDUPRResult = results.first { $0.dupr >= 5.0 }!

            let lowError = lowDUPRResult.faultsPerMatch - lowDUPRResult.target
            let highError = highDUPRResult.faultsPerMatch - highDUPRResult.target

            // Gradient-style adjustment (aggressive lr for fast convergence)
            let lr: CGFloat = 0.5
            if abs(lowError) > Self.tolerance {
                // Too many faults → reduce baseFaultRate; too few → increase
                baseFaultRate -= CGFloat(lowError) * lr * 0.05
                baseFaultRate = max(0.01, min(0.50, baseFaultRate))

                // Also adjust maxNY_Low (closer to baseline = safer)
                serveMaxNY_Low -= CGFloat(lowError) * lr * 0.02
                serveMaxNY_Low = max(0.08, min(0.25, serveMaxNY_Low))
            }

            if abs(highError) > Self.tolerance {
                serveMaxNY_High -= CGFloat(highError) * lr * 0.02
                serveMaxNY_High = max(0.10, min(0.30, serveMaxNY_High))
            }

            print("")
        }

        // Use best parameters found
        baseFaultRate = bestBaseFaultRate
        serveMaxNY_Low = bestMaxNY_Low
        serveMaxNY_High = bestMaxNY_High

        // Final verification with more samples
        print("\n--- Final Verification (10k serves per DUPR) ---")
        var allPassed = true
        for dupr in testDUPRs {
            let rate = Self.simulateServeFaultRate(
                dupr: dupr,
                count: 10_000,
                baseFaultRate: baseFaultRate,
                serveMinNY: serveMinNY,
                serveMaxNY_Low: serveMaxNY_Low,
                serveMaxNY_High: serveMaxNY_High
            )
            let faultsPerMatch = rate * Self.avgServesPerMatch
            let target = Self.targetFaultsPerMatch(dupr: dupr)
            let status = abs(faultsPerMatch - target) <= Self.tolerance ? "PASS" : "FAIL"
            if abs(faultsPerMatch - target) > Self.tolerance { allPassed = false }
            print("  DUPR \(String(format: "%.1f", dupr)): \(String(format: "%.2f", faultsPerMatch))/match (target: \(String(format: "%.1f", target))) [\(status)]")
        }

        print("\nOptimal constants:")
        print("  npcBaseServeFaultRate = \(String(format: "%.4f", baseFaultRate))")
        print("  npcServeTargetMinNY = \(String(format: "%.3f", serveMinNY))")
        print("  npcServeTargetMaxNY_Low = \(String(format: "%.3f", serveMaxNY_Low))")
        print("  npcServeTargetMaxNY_High = \(String(format: "%.3f", serveMaxNY_High))")

        // Write back to GameConstants source file
        if allPassed {
            writeConstants(
                baseFaultRate: baseFaultRate,
                serveMinNY: serveMinNY,
                maxNY_Low: serveMaxNY_Low,
                maxNY_High: serveMaxNY_High
            )
            print("\nConstants written to GameConstants.swift")
        } else {
            print("\nWARNING: Not all targets met — constants NOT written. Review and re-run.")
        }

        #expect(allPassed, "All DUPR serve fault rates should be within tolerance of targets")
    }

    // MARK: - Write Constants

    private func writeConstants(
        baseFaultRate: CGFloat,
        serveMinNY: CGFloat,
        maxNY_Low: CGFloat,
        maxNY_High: CGFloat
    ) {
        let testFilePath = #filePath
        let testFileURL = URL(fileURLWithPath: testFilePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent() // Engine/
            .deletingLastPathComponent() // PickleQuestTests/
            .deletingLastPathComponent() // repo root
        let constantsURL = repoRoot
            .appendingPathComponent("PickleQuest")
            .appendingPathComponent("Models")
            .appendingPathComponent("Common")
            .appendingPathComponent("GameConstants.swift")

        guard var source = try? String(contentsOf: constantsURL, encoding: .utf8) else {
            print("ERROR: Could not read GameConstants.swift")
            return
        }

        // Replace each constant value using regex
        func replace(_ pattern: String, with value: String) {
            if let range = source.range(of: pattern, options: .regularExpression) {
                source.replaceSubrange(range, with: value)
            }
        }

        replace(
            #"static let npcServeTargetMinNY: CGFloat = [\d.]+"#,
            with: "static let npcServeTargetMinNY: CGFloat = \(String(format: "%.3f", serveMinNY))"
        )
        replace(
            #"static let npcServeTargetMaxNY_Low: CGFloat = [\d.]+"#,
            with: "static let npcServeTargetMaxNY_Low: CGFloat = \(String(format: "%.3f", maxNY_Low))"
        )
        replace(
            #"static let npcServeTargetMaxNY_High: CGFloat = [\d.]+"#,
            with: "static let npcServeTargetMaxNY_High: CGFloat = \(String(format: "%.3f", maxNY_High))"
        )
        replace(
            #"static let npcBaseServeFaultRate: CGFloat = [\d.]+"#,
            with: "static let npcBaseServeFaultRate: CGFloat = \(String(format: "%.4f", baseFaultRate))"
        )

        try? source.write(to: constantsURL, atomically: true, encoding: .utf8)
    }
}
