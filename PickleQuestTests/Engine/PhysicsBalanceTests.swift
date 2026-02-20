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
    static let verifyTrials = 3000

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

    // MARK: - Verify Physics Put-Away Return Rates (validation-only)
    //
    // If this test fails, adjust stat curves in stat_profiles.json (offsets/slopes) or
    // NPCStrategyProfile parameters. Do NOT reintroduce mutable GameConstants.

    @Test func verifyPhysicsPutAwayReturnRates() {
        print("Physics Put-Away Return Rate Verification")
        print("==========================================")
        print("Targets: \(Self.returnTargets.map { "DUPR \($0.dupr): \(Int($0.returnRate * 100))%" }.joined(separator: ", "))")
        print("Trials per DUPR: \(Self.verifyTrials)")
        print("Return rate = returned / (returned + error), excluding OOB and double-bounce")
        print("")

        var allPassed = true
        for (dupr, target) in Self.returnTargets {
            var tr = TrialResults()
            for _ in 0..<Self.verifyTrials {
                tr.record(Self.physicsPutAwayTrial(defenderDUPR: dupr))
            }
            let rate = tr.returnRate
            let pass = Swift.abs(rate - target) <= Self.tolerance
            if !pass { allPassed = false }
            let status = pass ? "PASS" : "FAIL"
            print("  \(tr.summary(label: "DUPR \(String(format: "%.1f", dupr))"))")
            print("    → \(String(format: "%.1f%%", rate * 100)) (target: \(String(format: "%.0f%%", target * 100))) [\(status)]")
        }

        #expect(allPassed, "All DUPR physics put-away return rates should be within tolerance. Fix: adjust stat_profiles.json or NPCStrategyProfile.")
    }

    // MARK: - Verify Physics Smash Return Rates (validation-only)
    //
    // If this test fails, adjust stat curves in stat_profiles.json (offsets/slopes) or
    // NPCStrategyProfile parameters. Do NOT reintroduce mutable GameConstants.

    @Test func verifyPhysicsSmashReturnRates() {
        print("Physics Smash Return Rate Verification")
        print("=======================================")
        print("Targets: \(Self.smashReturnTargets.map { "DUPR \($0.dupr): \(Int($0.returnRate * 100))%" }.joined(separator: ", "))")
        print("Trials per DUPR: \(Self.verifyTrials)")
        print("Return rate = returned / (returned + error), excluding OOB and double-bounce")
        print("")

        var allPassed = true
        for (dupr, target) in Self.smashReturnTargets {
            var tr = TrialResults()
            for _ in 0..<Self.verifyTrials {
                tr.record(Self.physicsSmashTrial(defenderDUPR: dupr))
            }
            let rate = tr.returnRate
            let pass = Swift.abs(rate - target) <= Self.tolerance
            if !pass { allPassed = false }
            let status = pass ? "PASS" : "FAIL"
            print("  \(tr.summary(label: "DUPR \(String(format: "%.1f", dupr))"))")
            print("    → \(String(format: "%.1f%%", rate * 100)) (target: \(String(format: "%.0f%%", target * 100))) [\(status)]")
        }

        #expect(allPassed, "All DUPR physics smash return rates should be within tolerance. Fix: adjust stat_profiles.json or NPCStrategyProfile.")
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
}
