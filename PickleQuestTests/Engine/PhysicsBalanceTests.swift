import Testing
import Foundation
import CoreGraphics
@testable import PickleQuest

@Suite("Physics Balance")
struct PhysicsBalanceTests {

    // MARK: - Shared Targets (must match PutAwayBalanceTests)

    static let returnTargets: [(dupr: Double, returnRate: Double)] = [
        (2.0, 0.00),
        (3.0, 0.10),
        (4.0, 0.30),
        (5.0, 0.50),
        (6.0, 0.60),
    ]

    static let smashReturnTargets: [(dupr: Double, returnRate: Double)] = [
        (2.0, 0.10),
        (3.0, 0.25),
        (4.0, 0.50),
        (5.0, 0.70),
        (6.0, 0.80),
    ]

    static let tolerance: Double = 0.06
    static let tuningTrials = 1000
    static let verifyTrials = 3000
    static let maxIterations = 15

    // MARK: - Trial Outcome

    enum TrialOutcome {
        case returned       // NPC swung and returned successfully
        case error          // NPC swung but made an error (whiff)
        case doubleBounce   // ball bounced twice before NPC reached it
        case outOfBounds    // ball's first bounce was out of bounds (attacker error)
        case timeout        // ball never resolved within time limit
    }

    // MARK: - Physics Put-Away Trial

    static func physicsPutAwayTrial(defenderDUPR: Double) -> TrialOutcome {
        let npc = NPC.practiceOpponent(dupr: defenderDUPR)
        let npcAI = MatchAI(npc: npc, playerDUPR: defenderDUPR, headless: true)
        npcAI.reset(npcScore: 0, isServing: false)

        let defenderNX = CGFloat.random(in: 0.35...0.65)
        let defenderNY: CGFloat = 0.85
        npcAI.currentNX = defenderNX
        npcAI.currentNY = defenderNY

        let attackerStats = StatProfileLoader.shared.toNPCStats(dupr: defenderDUPR)

        let shot = DrillShotCalculator.calculatePlayerShot(
            stats: attackerStats,
            ballApproachFromLeft: Bool.random(),
            drillType: .baselineRally,
            ballHeight: 0.20,
            courtNX: CGFloat.random(in: 0.35...0.65),
            courtNY: 0.30,
            modes: [.power],
            shooterDUPR: defenderDUPR
        )

        let ball = DrillBallSimulation()
        let attackerOrigin = CGPoint(x: CGFloat.random(in: 0.35...0.65), y: 0.30)
        ball.launch(
            from: attackerOrigin,
            toward: CGPoint(x: shot.targetNX, y: shot.targetNY),
            power: shot.power,
            arc: shot.arc,
            spin: shot.spinCurve,
            topspin: shot.topspinFactor
        )

        // Set flags AFTER launch (launch() resets them)
        ball.lastHitByPlayer = true
        ball.isPutAway = true
        ball.smashFactor = shot.smashFactor

        let dt: CGFloat = 1.0 / 120.0
        let maxFrames = Int(3.0 / dt)
        var firstBounceChecked = false

        for _ in 0..<maxFrames {
            ball.update(dt: dt)
            npcAI.update(dt: dt, ball: ball)

            // Check first bounce for out-of-bounds (attacker's error)
            if ball.didBounceThisFrame && !firstBounceChecked {
                firstBounceChecked = true
                if ball.isLandingOut {
                    return .outOfBounds
                }
            }

            if npcAI.shouldSwing(ball: ball) {
                npcAI.preselectModes(ball: ball)
                let madeError = npcAI.shouldMakeError(ball: ball)
                return madeError ? .error : .returned
            }

            if ball.bounceCount >= 2 { return .doubleBounce }
            if !ball.isActive { return .outOfBounds }
            if ball.isStalled { return .timeout }
        }

        return .timeout
    }

    // MARK: - Physics Smash Trial

    static func physicsSmashTrial(defenderDUPR: Double) -> TrialOutcome {
        let npc = NPC.practiceOpponent(dupr: defenderDUPR)
        let npcAI = MatchAI(npc: npc, playerDUPR: defenderDUPR, headless: true)
        npcAI.reset(npcScore: 0, isServing: false)

        let defenderNX = CGFloat.random(in: 0.35...0.65)
        let defenderNY: CGFloat = 0.85
        npcAI.currentNX = defenderNX
        npcAI.currentNY = defenderNY

        let attackerStats = StatProfileLoader.shared.toNPCStats(dupr: defenderDUPR)

        let shot = DrillShotCalculator.calculatePlayerShot(
            stats: attackerStats,
            ballApproachFromLeft: Bool.random(),
            drillType: .baselineRally,
            ballHeight: 0.20,
            courtNX: CGFloat.random(in: 0.35...0.65),
            courtNY: 0.10,
            modes: [.power],
            shooterDUPR: defenderDUPR
        )

        let ball = DrillBallSimulation()
        let attackerOrigin = CGPoint(x: CGFloat.random(in: 0.35...0.65), y: 0.10)
        ball.launch(
            from: attackerOrigin,
            toward: CGPoint(x: shot.targetNX, y: shot.targetNY),
            power: shot.power,
            arc: shot.arc,
            spin: shot.spinCurve,
            topspin: shot.topspinFactor
        )

        ball.lastHitByPlayer = true
        ball.isPutAway = false
        ball.smashFactor = shot.smashFactor

        let dt: CGFloat = 1.0 / 120.0
        let maxFrames = Int(3.0 / dt)
        var firstBounceChecked = false

        for _ in 0..<maxFrames {
            ball.update(dt: dt)
            npcAI.update(dt: dt, ball: ball)

            if ball.didBounceThisFrame && !firstBounceChecked {
                firstBounceChecked = true
                if ball.isLandingOut {
                    return .outOfBounds
                }
            }

            if npcAI.shouldSwing(ball: ball) {
                npcAI.preselectModes(ball: ball)
                let madeError = npcAI.shouldMakeError(ball: ball)
                return madeError ? .error : .returned
            }

            if ball.bounceCount >= 2 { return .doubleBounce }
            if !ball.isActive { return .outOfBounds }
            if ball.isStalled { return .timeout }
        }

        return .timeout
    }

    // MARK: - Outcome Aggregation

    struct TrialResults {
        var returned = 0
        var error = 0
        var doubleBounce = 0
        var outOfBounds = 0
        var timeout = 0

        mutating func record(_ outcome: TrialOutcome) {
            switch outcome {
            case .returned: returned += 1
            case .error: error += 1
            case .doubleBounce: doubleBounce += 1
            case .outOfBounds: outOfBounds += 1
            case .timeout: timeout += 1
            }
        }

        /// Return rate among shots where NPC swung (matches probabilistic formula scope)
        var returnRate: Double {
            let swung = returned + error
            guard swung > 0 else { return 0 }
            return Double(returned) / Double(swung)
        }

        var total: Int { returned + error + doubleBounce + outOfBounds + timeout }

        var swingCount: Int { returned + error }

        func summary(label: String) -> String {
            let t = total
            let swingPct = t > 0 ? String(format: "%.0f%%", Double(swingCount) / Double(t) * 100) : "0%"
            let oobPct = t > 0 ? String(format: "%.0f%%", Double(outOfBounds) / Double(t) * 100) : "0%"
            let dbPct = t > 0 ? String(format: "%.0f%%", Double(doubleBounce) / Double(t) * 100) : "0%"
            return "\(label): returnRate=\(String(format: "%.1f%%", returnRate * 100)) (swung=\(swingCount)/\(t) [\(swingPct)], oob=\(outOfBounds) [\(oobPct)], 2bounce=\(doubleBounce) [\(dbPct)])"
        }
    }

    // MARK: - Tune Physics Put-Away Return Rates

    @Test func tunePhysicsPutAwayReturnRates() {
        let maxIter = Self.maxIterations

        let origBase = GameConstants.PutAway.baseReturnRate
        let origScale = GameConstants.PutAway.returnDUPRScale
        let origStretch = GameConstants.PutAway.stretchPenalty

        var baseReturnRate = origBase
        var returnDUPRScale = origScale
        var stretchPenalty = origStretch

        var bestBase = baseReturnRate
        var bestScale = returnDUPRScale
        var bestStretch = stretchPenalty
        var bestTotalError: Double = .infinity

        print("Physics Put-Away Return Rate Tuning")
        print("====================================")
        print("Targets: \(Self.returnTargets.map { "DUPR \($0.dupr): \(Int($0.returnRate * 100))%" }.joined(separator: ", "))")
        print("Trials per DUPR: \(Self.tuningTrials)")
        print("Return rate = returned / (returned + error), excluding OOB and double-bounce")
        print("")

        for iteration in 1...maxIter {
            GameConstants.PutAway.baseReturnRate = baseReturnRate
            GameConstants.PutAway.returnDUPRScale = returnDUPRScale
            GameConstants.PutAway.stretchPenalty = stretchPenalty

            var results: [(dupr: Double, measured: Double, target: Double)] = []
            var totalError: Double = 0

            for (dupr, target) in Self.returnTargets {
                var tr = TrialResults()
                for _ in 0..<Self.tuningTrials {
                    tr.record(Self.physicsPutAwayTrial(defenderDUPR: dupr))
                }
                let rate = tr.returnRate
                let diff = rate - target
                totalError += diff * diff
                results.append((dupr, rate, target))
                if iteration == 1 {
                    print("    \(tr.summary(label: "DUPR \(String(format: "%.1f", dupr))"))")
                }
            }

            let rmse = sqrt(totalError / Double(Self.returnTargets.count))

            print("Iteration \(iteration): baseReturn=\(String(format: "%.4f", baseReturnRate)), duprScale=\(String(format: "%.4f", returnDUPRScale)), stretchPenalty=\(String(format: "%.4f", stretchPenalty))")
            for r in results {
                let status = Swift.abs(r.measured - r.target) <= Self.tolerance ? "OK" : "MISS"
                print("  DUPR \(String(format: "%.1f", r.dupr)): \(String(format: "%.1f%%", r.measured * 100)) (target: \(String(format: "%.0f%%", r.target * 100))) [\(status)]")
            }
            print("  RMSE: \(String(format: "%.4f", rmse))")

            if totalError < bestTotalError {
                bestTotalError = totalError
                bestBase = baseReturnRate
                bestScale = returnDUPRScale
                bestStretch = stretchPenalty
            }

            let allGood = results.allSatisfy { Swift.abs($0.measured - $0.target) <= Self.tolerance }
            if allGood {
                print("\nAll DUPR levels within tolerance after \(iteration) iterations!")
                break
            }

            let lr: CGFloat = 0.5

            let midResult = results.first { $0.dupr == 4.0 }!
            let midError = midResult.measured - midResult.target
            if Swift.abs(midError) > Self.tolerance {
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
            if Swift.abs(highError) > Self.tolerance {
                stretchPenalty += CGFloat(highError) * lr * 0.3
                stretchPenalty = max(0.05, min(0.80, stretchPenalty))
            }

            print("")
        }

        GameConstants.PutAway.baseReturnRate = bestBase
        GameConstants.PutAway.returnDUPRScale = bestScale
        GameConstants.PutAway.stretchPenalty = bestStretch

        print("\n--- Final Physics Verification (\(Self.verifyTrials) trials per DUPR) ---")
        var allPassed = true
        for (dupr, target) in Self.returnTargets {
            var tr = TrialResults()
            for _ in 0..<Self.verifyTrials {
                tr.record(Self.physicsPutAwayTrial(defenderDUPR: dupr))
            }
            let rate = tr.returnRate
            let status = Swift.abs(rate - target) <= Self.tolerance ? "PASS" : "FAIL"
            if Swift.abs(rate - target) > Self.tolerance { allPassed = false }
            print("  \(tr.summary(label: "DUPR \(String(format: "%.1f", dupr))"))")
            print("    → \(String(format: "%.1f%%", rate * 100)) (target: \(String(format: "%.0f%%", target * 100))) [\(status)]")
        }

        print("\nOptimal physics put-away constants:")
        print("  baseReturnRate = \(String(format: "%.4f", bestBase))")
        print("  returnDUPRScale = \(String(format: "%.4f", bestScale))")
        print("  stretchPenalty = \(String(format: "%.4f", bestStretch))")

        if allPassed {
            writeReturnConstants(
                baseReturnRate: bestBase,
                returnDUPRScale: bestScale,
                stretchPenalty: bestStretch
            )
            print("\nPhysics put-away constants written to GameConstants.swift")
        } else {
            GameConstants.PutAway.baseReturnRate = origBase
            GameConstants.PutAway.returnDUPRScale = origScale
            GameConstants.PutAway.stretchPenalty = origStretch
            print("\nWARNING: Not all targets met — constants NOT written. Review and re-run.")
        }

        #expect(allPassed, "All DUPR physics put-away return rates should be within tolerance of targets")
    }

    // MARK: - Tune Physics Smash Return Rates

    @Test func tunePhysicsSmashReturnRates() {
        let maxIter = Self.maxIterations

        let origBase = GameConstants.Smash.baseReturnRate
        let origScale = GameConstants.Smash.returnDUPRScale
        let origStretch = GameConstants.Smash.stretchPenalty

        var baseReturnRate = origBase
        var returnDUPRScale = origScale
        var stretchPenalty = origStretch

        var bestBase = baseReturnRate
        var bestScale = returnDUPRScale
        var bestStretch = stretchPenalty
        var bestTotalError: Double = .infinity

        print("Physics Smash Return Rate Tuning")
        print("=================================")
        print("Targets: \(Self.smashReturnTargets.map { "DUPR \($0.dupr): \(Int($0.returnRate * 100))%" }.joined(separator: ", "))")
        print("Trials per DUPR: \(Self.tuningTrials)")
        print("Return rate = returned / (returned + error), excluding OOB and double-bounce")
        print("")

        for iteration in 1...maxIter {
            GameConstants.Smash.baseReturnRate = baseReturnRate
            GameConstants.Smash.returnDUPRScale = returnDUPRScale
            GameConstants.Smash.stretchPenalty = stretchPenalty

            var results: [(dupr: Double, measured: Double, target: Double)] = []
            var totalError: Double = 0

            for (dupr, target) in Self.smashReturnTargets {
                var tr = TrialResults()
                for _ in 0..<Self.tuningTrials {
                    tr.record(Self.physicsSmashTrial(defenderDUPR: dupr))
                }
                let rate = tr.returnRate
                let diff = rate - target
                totalError += diff * diff
                results.append((dupr, rate, target))
                if iteration == 1 {
                    print("    \(tr.summary(label: "DUPR \(String(format: "%.1f", dupr))"))")
                }
            }

            let rmse = sqrt(totalError / Double(Self.smashReturnTargets.count))

            print("Iteration \(iteration): baseReturn=\(String(format: "%.4f", baseReturnRate)), duprScale=\(String(format: "%.4f", returnDUPRScale)), stretchPenalty=\(String(format: "%.4f", stretchPenalty))")
            for r in results {
                let status = Swift.abs(r.measured - r.target) <= Self.tolerance ? "OK" : "MISS"
                print("  DUPR \(String(format: "%.1f", r.dupr)): \(String(format: "%.1f%%", r.measured * 100)) (target: \(String(format: "%.0f%%", r.target * 100))) [\(status)]")
            }
            print("  RMSE: \(String(format: "%.4f", rmse))")

            if totalError < bestTotalError {
                bestTotalError = totalError
                bestBase = baseReturnRate
                bestScale = returnDUPRScale
                bestStretch = stretchPenalty
            }

            let allGood = results.allSatisfy { Swift.abs($0.measured - $0.target) <= Self.tolerance }
            if allGood {
                print("\nAll DUPR levels within tolerance after \(iteration) iterations!")
                break
            }

            let lr: CGFloat = 0.5

            let midResult = results.first { $0.dupr == 4.0 }!
            let midError = midResult.measured - midResult.target
            if Swift.abs(midError) > Self.tolerance {
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
            if Swift.abs(highError) > Self.tolerance {
                stretchPenalty += CGFloat(highError) * lr * 0.3
                stretchPenalty = max(0.05, min(0.80, stretchPenalty))
            }

            print("")
        }

        GameConstants.Smash.baseReturnRate = bestBase
        GameConstants.Smash.returnDUPRScale = bestScale
        GameConstants.Smash.stretchPenalty = bestStretch

        print("\n--- Final Physics Verification (\(Self.verifyTrials) trials per DUPR) ---")
        var allPassed = true
        for (dupr, target) in Self.smashReturnTargets {
            var tr = TrialResults()
            for _ in 0..<Self.verifyTrials {
                tr.record(Self.physicsSmashTrial(defenderDUPR: dupr))
            }
            let rate = tr.returnRate
            let status = Swift.abs(rate - target) <= Self.tolerance ? "PASS" : "FAIL"
            if Swift.abs(rate - target) > Self.tolerance { allPassed = false }
            print("  \(tr.summary(label: "DUPR \(String(format: "%.1f", dupr))"))")
            print("    → \(String(format: "%.1f%%", rate * 100)) (target: \(String(format: "%.0f%%", target * 100))) [\(status)]")
        }

        print("\nOptimal physics smash constants:")
        print("  baseReturnRate = \(String(format: "%.4f", bestBase))")
        print("  returnDUPRScale = \(String(format: "%.4f", bestScale))")
        print("  stretchPenalty = \(String(format: "%.4f", bestStretch))")

        if allPassed {
            writeSmashConstants(
                baseReturnRate: bestBase,
                returnDUPRScale: bestScale,
                stretchPenalty: bestStretch
            )
            print("\nPhysics smash constants written to GameConstants.swift")
        } else {
            GameConstants.Smash.baseReturnRate = origBase
            GameConstants.Smash.returnDUPRScale = origScale
            GameConstants.Smash.stretchPenalty = origStretch
            print("\nWARNING: Not all targets met — constants NOT written. Review and re-run.")
        }

        #expect(allPassed, "All DUPR physics smash return rates should be within tolerance of targets")
    }

    // MARK: - Validate Physics Put-Away Scatter

    /// Put-aways are kitchen volleys — the NPC intercepts in the air before bounce.
    /// smashArcBonus causes balls to land long if unintercepted (by design — steep angle).
    /// This test validates: (1) ball reaches opponent's court half, (2) NPC can swing (reachable).
    @Test func validatePhysicsPutAwayScatter() {
        print("Physics Put-Away Scatter Validation")
        print("====================================")
        print("Put-aways are volleys — checking NPC reachability, not first-bounce in-bounds")
        print("")

        for dupr in [4.0, 5.0, 6.0] {
            var tr = TrialResults()
            let count = 3000

            for _ in 0..<count {
                tr.record(Self.physicsPutAwayTrial(defenderDUPR: dupr))
            }

            let reachRate = Double(tr.swingCount) / Double(count)
            let status = reachRate > 0.50 ? "PASS" : "FAIL"
            print("  \(tr.summary(label: "DUPR \(String(format: "%.1f", dupr))"))")
            print("    NPC reach rate: \(String(format: "%.1f%%", reachRate * 100)) [\(status)]")

            // NPC should physically reach 50%+ of put-away shots (volley before bounce)
            #expect(reachRate > 0.50, "DUPR \(dupr): NPC should reach 50%+ of put-away shots")
        }
    }

    // MARK: - Write Constants

    private func writeReturnConstants(
        baseReturnRate: CGFloat,
        returnDUPRScale: CGFloat,
        stretchPenalty: CGFloat
    ) {
        guard var source = readGameConstants() else { return }

        if let putAwayRange = source.range(of: "enum PutAway \\{[\\s\\S]*?\\}", options: .regularExpression) {
            var putAwayBlock = String(source[putAwayRange])
            replace(in: &putAwayBlock,
                    #"static var baseReturnRate: CGFloat = [\d.]+"#,
                    with: "static var baseReturnRate: CGFloat = \(String(format: "%.4f", baseReturnRate))")
            replace(in: &putAwayBlock,
                    #"static var returnDUPRScale: CGFloat = [\d.]+"#,
                    with: "static var returnDUPRScale: CGFloat = \(String(format: "%.4f", returnDUPRScale))")
            replace(in: &putAwayBlock,
                    #"static var stretchPenalty: CGFloat = [\d.]+"#,
                    with: "static var stretchPenalty: CGFloat = \(String(format: "%.4f", stretchPenalty))")
            source.replaceSubrange(putAwayRange, with: putAwayBlock)
        }

        writeGameConstants(source)
    }

    private func writeSmashConstants(
        baseReturnRate: CGFloat,
        returnDUPRScale: CGFloat,
        stretchPenalty: CGFloat
    ) {
        guard var source = readGameConstants() else { return }

        if let smashRange = source.range(of: "enum Smash \\{[\\s\\S]*?\\}", options: .regularExpression) {
            var smashBlock = String(source[smashRange])
            replace(in: &smashBlock,
                    #"static var baseReturnRate: CGFloat = [\d.]+"#,
                    with: "static var baseReturnRate: CGFloat = \(String(format: "%.4f", baseReturnRate))")
            replace(in: &smashBlock,
                    #"static var returnDUPRScale: CGFloat = [\d.]+"#,
                    with: "static var returnDUPRScale: CGFloat = \(String(format: "%.4f", returnDUPRScale))")
            replace(in: &smashBlock,
                    #"static var stretchPenalty: CGFloat = [\d.]+"#,
                    with: "static var stretchPenalty: CGFloat = \(String(format: "%.4f", stretchPenalty))")
            source.replaceSubrange(smashRange, with: smashBlock)
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
