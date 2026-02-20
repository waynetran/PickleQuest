import Testing
import Foundation
import CoreGraphics
@testable import PickleQuest

@Suite("Pressure Hitbox Balance")
struct PressureHitboxBalanceTests {

    // MARK: - Same-Level Miss Rate Targets

    /// Target miss rates for same-DUPR pressure scenarios (combined hitbox miss + error).
    /// Weighted average across pressure shot counts 1, 2, 3.
    /// Miss = doubleBounce (can't reach / hitbox miss) + error (whiff).
    static let missRateTargets: [(dupr: Double, missRate: Double)] = [
        (2.0, 0.90),   // beginners can't handle net pressure
        (3.0, 0.70),   // intermediates struggle significantly
        (3.5, 0.55),   // mid-level still lose majority
        (5.0, 0.33),   // pros miss ~1 in 3 (avg 3 shots before missing)
        (6.5, 0.22),   // elite absorb sustained pressure
    ]

    /// DUPR gap multiplier targets: miss rate at gap vs same-level baseline.
    static let gapMultiplierTargets: [(gap: Double, multiplier: Double)] = [
        (0.5, 1.50),   // 50% more misses
        (1.0, 2.00),   // 100% more misses
    ]

    static let tolerance: Double = 0.10
    static let gapTolerance: Double = 0.50
    static let verifyTrials = 5000

    // MARK: - Trial Outcome

    enum TrialOutcome {
        case returned       // NPC reached ball and returned successfully
        case error          // NPC reached ball but made an error (whiff)
        case doubleBounce   // NPC couldn't reach in time or ball outside shrunk hitbox
        case outOfBounds    // Attacker's shot landed OOB (exclude from stats)
        case timeout        // Didn't resolve within time limit (exclude)
    }

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

        /// Valid trials: those where attacker's shot was in-bounds
        var validTotal: Int { returned + error + doubleBounce }

        /// Miss rate = (doubleBounce + error) / valid trials
        var missRate: Double {
            guard validTotal > 0 else { return 1.0 }
            return Double(error + doubleBounce) / Double(validTotal)
        }

        var total: Int { returned + error + doubleBounce + outOfBounds + timeout }

        func summary(label: String) -> String {
            let v = validTotal
            let retPct = v > 0 ? String(format: "%.0f%%", Double(returned) / Double(v) * 100) : "0%"
            let errPct = v > 0 ? String(format: "%.0f%%", Double(error) / Double(v) * 100) : "0%"
            let dbPct = v > 0 ? String(format: "%.0f%%", Double(doubleBounce) / Double(v) * 100) : "0%"
            let oobPct = total > 0 ? String(format: "%.0f%%", Double(outOfBounds) / Double(total) * 100) : "0%"
            return "\(label): miss=\(String(format: "%.1f%%", missRate * 100)) (ret=\(returned) [\(retPct)], err=\(error) [\(errPct)], dblBnc=\(doubleBounce) [\(dbPct)], oob=\(outOfBounds) [\(oobPct)])"
        }
    }

    // MARK: - Physics-Based Pressure Trial

    /// Run a single pressure trial with full physics: ball launched from kitchen AWAY from the NPC,
    /// NPC must react, predict, and run to intercept. Miss rate comes from:
    /// 1. Movement: NPC speed determines if they can reach the ball in time (dominant at low DUPR)
    /// 2. Hitbox: pressure-shrunk hitbox (adds misses under sustained kitchen pressure)
    /// 3. Error: unforced errors from ball speed/stretch (adds misses at low DUPR)
    ///
    /// Ball placement uses FIXED separation from the NPC (0.28 ± 0.06) to model kitchen pressure.
    /// Kitchen pressure means the attacker has positional advantage — even low-DUPR players at the
    /// net can redirect balls away from a baseline defender. Only the NPC's defensive ability varies.
    /// For cross-level tests, attackerDUPR > defenderDUPR → attacker accuracy adds extra separation.
    static func pressureTrial(defenderDUPR: Double, attackerDUPR: Double, pressureCount: Int) -> TrialOutcome {
        let npc = NPC.practiceOpponent(dupr: defenderDUPR)
        let ai = MatchAI(npc: npc, playerDUPR: attackerDUPR, headless: true)
        ai.reset(npcScore: 0, isServing: false)

        // NPC at baseline with moderate X variation
        let npcStartNX = CGFloat.random(in: 0.35...0.65)
        let npcStartNY: CGFloat = 0.85
        ai.currentNX = npcStartNX
        ai.currentNY = npcStartNY

        // Player at kitchen
        let playerNX = CGFloat.random(in: 0.35...0.65)
        ai.playerPositionNX = playerNX
        ai.playerPositionNY = 0.30

        // Set cumulative pressure count (AFTER reset which clears it)
        ai.pressureShotCount = pressureCount

        // Kitchen shot placement: base separation + accuracy-scaled jitter.
        // Low-accuracy attackers (low DUPR) have HIGH jitter — balls land randomly,
        // sometimes close to NPC (easy return) and sometimes far (unreachable).
        // High-accuracy attackers (high DUPR) have LOW jitter — consistently placed far away.
        // This models real pickleball: beginners can barely aim from the kitchen,
        // while experts consistently target the defender's weak spots.
        let attackerStats = StatProfileLoader.shared.toNPCStats(dupr: attackerDUPR)
        let accuracyFrac = CGFloat(attackerStats.stat(.accuracy)) / 99.0
        let baseSep: CGFloat = 0.30
        let jitterRange = (1.0 - accuracyFrac) * 0.30  // low accuracy → ±0.30
        let separation = max(0.05, baseSep + CGFloat.random(in: -jitterRange...jitterRange))

        let direction: CGFloat = Bool.random() ? 1.0 : -1.0
        let targetX = max(0.08, min(0.92, npcStartNX + direction * separation))
        let targetY = CGFloat.random(in: 0.82...0.93)

        // Hard drives from kitchen — must reach baseline in a single arc.
        // Net clearance boosts vz to ~0.38; needs vy ≥ 0.67 → power ≥ 0.65.
        // Mix of hard drives (70%) and firm passing shots (30%).
        let isHard = Double.random(in: 0...1) < 0.70
        let power: CGFloat
        let arc: CGFloat
        let spin: CGFloat
        let topspin: CGFloat
        if isHard {
            power = CGFloat.random(in: 0.78...0.90)
            arc = CGFloat.random(in: 0.06...0.12)
            spin = CGFloat.random(in: -0.10...0.10)
            topspin = CGFloat.random(in: 0...0.12)
        } else {
            power = CGFloat.random(in: 0.65...0.78)
            arc = CGFloat.random(in: 0.10...0.18)
            spin = CGFloat.random(in: -0.08...0.08)
            topspin = 0
        }

        // Launch ball from kitchen toward NPC baseline area
        let ball = DrillBallSimulation()
        ball.launch(
            from: CGPoint(x: playerNX, y: 0.30),
            toward: CGPoint(x: targetX, y: targetY),
            power: power,
            arc: arc,
            spin: spin,
            topspin: topspin
        )
        ball.lastHitByPlayer = true

        // Step physics: ball flies, NPC runs to intercept
        let dt: CGFloat = 1.0 / 120.0
        let maxFrames = Int(3.0 / dt)
        var firstBounceChecked = false

        for _ in 0..<maxFrames {
            ball.update(dt: dt)
            ai.update(dt: dt, ball: ball)

            // Check first bounce for out-of-bounds (attacker's error)
            if ball.didBounceThisFrame && !firstBounceChecked {
                firstBounceChecked = true
                if ball.isLandingOut {
                    return .outOfBounds
                }
            }

            // NPC tries to swing — pressure-shrunk hitbox determines reach
            if ai.shouldSwing(ball: ball) {
                ai.preselectModes(ball: ball)
                if ai.shouldMakeError(ball: ball) {
                    return .error
                }
                return .returned
            }

            if ball.bounceCount >= 2 { return .doubleBounce }
            if !ball.isActive { return .outOfBounds }
            if ball.isStalled { return .timeout }
        }

        return .timeout
    }

    // MARK: - Weighted Miss Rate

    /// Calculate weighted average miss rate across pressure shot counts 1, 2, 3.
    static func weightedMissRate(defenderDUPR: Double, attackerDUPR: Double, trialsPerCount: Int) -> (missRate: Double, oobRate: Double) {
        var totalMissRate: Double = 0
        var totalOOB = 0
        var totalTrials = 0
        for count in 1...3 {
            var tr = TrialResults()
            for _ in 0..<trialsPerCount {
                tr.record(pressureTrial(defenderDUPR: defenderDUPR, attackerDUPR: attackerDUPR, pressureCount: count))
            }
            totalMissRate += tr.missRate
            totalOOB += tr.outOfBounds + tr.timeout
            totalTrials += trialsPerCount
        }
        return (totalMissRate / 3.0, Double(totalOOB) / Double(totalTrials))
    }

    // MARK: - Test 1: Verify Pressure Miss Rate (validation-only)
    //
    // If this test fails, adjust stat curves in stat_profiles.json (offsets/slopes) or
    // NPCStrategyProfile parameters. Do NOT reintroduce mutable GameConstants.

    @Test func verifyPressureMissRate() {
        let trialsPerCount = Self.verifyTrials / 3

        print("Pressure Miss Rate Verification")
        print("================================")
        print("Targets: \(Self.missRateTargets.map { "DUPR \($0.dupr): \(Int($0.missRate * 100))%" }.joined(separator: ", "))")
        print("Trials per DUPR x count: \(trialsPerCount)")
        print("")

        var allPassed = true
        for (dupr, target) in Self.missRateTargets {
            let (rate, _) = Self.weightedMissRate(
                defenderDUPR: dupr, attackerDUPR: dupr,
                trialsPerCount: trialsPerCount
            )
            let pass = Swift.abs(rate - target) <= Self.tolerance
            if !pass { allPassed = false }
            let status = pass ? "PASS" : "FAIL"
            print("  DUPR \(String(format: "%.1f", dupr)): \(String(format: "%.1f%%", rate * 100)) (target: \(String(format: "%.0f%%", target * 100))) [\(status)]")
        }

        #expect(allPassed, "All DUPR pressure miss rates should be within tolerance. Fix: adjust stat_profiles.json or NPCStrategyProfile.")
    }

    // MARK: - Test 2: Verify DUPR Gap Pressure (cross-level, read-only verify)

    @Test func verifyDUPRGapPressure() {
        print("DUPR Gap Pressure Verification")
        print("==============================")

        // Use mid-range DUPR pairs where baseline isn't saturated (>60% baseline
        // compresses multipliers, making targets unreachable). Low-DUPR defenders
        // (3.0, 3.5) have baselines of 65-75% → max multiplier < 1.4×.
        let pairs: [(defender: Double, attacker: Double)] = [
            (3.5, 4.0), (3.5, 4.5), (4.5, 5.0), (4.0, 5.0)
        ]
        let trialsPerCount = Self.verifyTrials / 3

        var allPassed = true

        for (defender, attacker) in pairs {
            let gap = attacker - defender

            // Same-level baseline at defender's DUPR
            let (baselineRate, _) = Self.weightedMissRate(
                defenderDUPR: defender, attackerDUPR: defender,
                trialsPerCount: trialsPerCount
            )

            // Cross-level: stronger attacker
            let (crossRate, _) = Self.weightedMissRate(
                defenderDUPR: defender, attackerDUPR: attacker,
                trialsPerCount: trialsPerCount
            )

            let multiplier = baselineRate > 0.01 ? crossRate / baselineRate : 0

            // Find expected multiplier for this gap
            let expectedMult: Double = gap >= 1.0 ? 2.00 : 1.50

            let pass = Swift.abs(multiplier - expectedMult) <= Self.gapTolerance
            if !pass { allPassed = false }
            let status = pass ? "PASS" : "FAIL"
            print("  Def \(String(format: "%.1f", defender)) vs Atk \(String(format: "%.1f", attacker)) (gap=\(String(format: "%.1f", gap))):")
            print("    baseline=\(String(format: "%.1f%%", baselineRate * 100)), cross=\(String(format: "%.1f%%", crossRate * 100)), mult=\(String(format: "%.2f", multiplier))× (target: \(String(format: "%.2f", expectedMult))×) [\(status)]")
        }

        #expect(allPassed, "All DUPR gap multipliers should be within tolerance")
    }

    // MARK: - Test 3: Verify Pressure Accumulation (monotonic increase)

    @Test func verifyPressureAccumulation() {
        print("Pressure Accumulation Verification")
        print("===================================")

        let testDUPRs: [Double] = [2.0, 3.5, 5.0, 6.5]
        let trialsPerDUPR = 3000

        var allPassed = true

        for dupr in testDUPRs {
            var prev: Double = -1
            var monotonic = true
            print("  DUPR \(String(format: "%.1f", dupr)):")

            for count in 0...3 {
                var tr = TrialResults()
                for _ in 0..<trialsPerDUPR {
                    tr.record(Self.pressureTrial(defenderDUPR: dupr, attackerDUPR: dupr, pressureCount: count))
                }
                let rate = tr.missRate
                let arrow = prev >= 0 && rate > prev ? "↑" : (prev >= 0 && rate <= prev ? "↓ VIOLATION" : "")
                if prev >= 0 && rate <= prev { monotonic = false }
                prev = rate
                print("    shots=\(count): \(tr.summary(label: "miss")) \(arrow)")
            }

            if !monotonic { allPassed = false }
            print("    Monotonic: \(monotonic ? "PASS" : "FAIL")")
        }

        #expect(allPassed, "Pressure miss rate should increase monotonically with shot count")
    }
}
