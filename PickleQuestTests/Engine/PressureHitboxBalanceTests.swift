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

    static let tolerance: Double = 0.06
    static let gapTolerance: Double = 0.25
    static let tuningTrials = 5000
    static let verifyTrials = 5000
    static let maxIterations = 15

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

    // MARK: - Move Speed Scale Helper

    /// Compute NPC move speed scale from DUPR — delegates to GameConstants (single source of truth).
    static func moveSpeedScale(dupr: Double) -> CGFloat {
        GameConstants.DrillPhysics.npcMoveSpeedScale(dupr: dupr)
    }

    // MARK: - Physics-Based Pressure Trial

    /// Run a single pressure trial with full physics: ball launched from kitchen AWAY from the NPC,
    /// NPC must react, predict, and run to intercept. Miss rate comes from:
    /// 1. Movement: NPC speed determines if they can reach the ball in time (dominant at low DUPR)
    /// 2. Hitbox: pressure-shrunk hitbox (adds misses under sustained kitchen pressure)
    /// 3. Error: unforced errors from ball speed/stretch (adds misses at low DUPR)
    ///
    /// Ball is placed AWAY from NPC with controlled separation. This models real kitchen pressure
    /// where the net player hits hard at the baseline opponent (drives/volleys, not dinks).
    /// Power must be ≥ 0.65 for the ball to reach the baseline in a single arc (net clearance
    /// boosts vz to ~0.38, giving ~0.75s flight time). Higher attacker accuracy → wider separation.
    static func pressureTrial(defenderDUPR: Double, attackerDUPR: Double, pressureCount: Int) -> TrialOutcome {
        let npc = NPC.practiceOpponent(dupr: defenderDUPR)
        let scale = moveSpeedScale(dupr: defenderDUPR)
        let ai = MatchAI(npc: npc, playerDUPR: attackerDUPR, headless: true, moveSpeedScale: scale)
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

        // Kitchen shot placed AWAY from NPC: controlled separation.
        // Higher attacker accuracy → smarter placement (wider separation, harder to reach).
        let attackerStats = StatProfileLoader.shared.toNPCStats(dupr: attackerDUPR)
        let accuracyFrac = CGFloat(attackerStats.stat(.accuracy)) / 99.0
        let baseSep: CGFloat = 0.18
        let accuracyBonus: CGFloat = accuracyFrac * 0.18
        let separation = max(0.15, min(0.45, baseSep + accuracyBonus + CGFloat.random(in: -0.06...0.06)))

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

    // MARK: - Test 1: Tune Pressure Miss Rate (same-level, iterative tuning)

    @Test func tunePressureMissRate() {
        let maxIter = Self.maxIterations
        typealias P = GameConstants.DrillPhysics

        // Save originals for all 7 tunable constants
        let origShrink = P.pressureShrinkPerShot
        let origMin = P.pressureHitboxMinMultiplier
        let origResist = P.pressureTouchResistMax
        let origBaseMoveSpeed = P.baseMoveSpeed
        let origMaxMoveBonus = P.maxMoveSpeedBonus
        let origScaleLow = P.npcMoveSpeedScaleLow
        let origScaleHigh = P.npcMoveSpeedScaleHigh

        var shrinkPerShot = origShrink
        var hitboxMin = origMin
        var touchResist = origResist
        var baseMoveSpeed = origBaseMoveSpeed
        var maxMoveBonus = origMaxMoveBonus
        var scaleLow = origScaleLow
        var scaleHigh = origScaleHigh

        var bestShrink = shrinkPerShot
        var bestMin = hitboxMin
        var bestResist = touchResist
        var bestBaseMoveSpeed = baseMoveSpeed
        var bestMaxMoveBonus = maxMoveBonus
        var bestScaleLow = scaleLow
        var bestScaleHigh = scaleHigh
        var bestTotalError: Double = .infinity

        print("Pressure Hitbox + Movement + Speed Scale Tuning")
        print("=================================================")
        print("Targets: \(Self.missRateTargets.map { "DUPR \($0.dupr): \(Int($0.missRate * 100))%" }.joined(separator: ", "))")
        print("Trials per DUPR × shot count: \(Self.tuningTrials / 3)")
        print("Physics: ball placed AWAY from NPC, NPC runs to intercept")
        print("")

        for iteration in 1...maxIter {
            P.pressureShrinkPerShot = shrinkPerShot
            P.pressureHitboxMinMultiplier = hitboxMin
            P.pressureTouchResistMax = touchResist
            P.baseMoveSpeed = baseMoveSpeed
            P.maxMoveSpeedBonus = maxMoveBonus
            P.npcMoveSpeedScaleLow = scaleLow
            P.npcMoveSpeedScaleHigh = scaleHigh

            var results: [(dupr: Double, measured: Double, target: Double)] = []
            var totalError: Double = 0

            let trialsPerCount = Self.tuningTrials / 3

            for (dupr, target) in Self.missRateTargets {
                let (rate, oobRate) = Self.weightedMissRate(
                    defenderDUPR: dupr, attackerDUPR: dupr,
                    trialsPerCount: trialsPerCount
                )
                let diff = rate - target
                totalError += diff * diff
                results.append((dupr, rate, target))

                if iteration == 1 {
                    let effScale = Self.moveSpeedScale(dupr: dupr)
                    let npcStats = StatProfileLoader.shared.toNPCStats(dupr: dupr)
                    let speedStat = CGFloat(npcStats.stat(.speed))
                    let effectiveMoveSpeed = (baseMoveSpeed + (speedStat / 99.0) * maxMoveBonus) * effScale
                    print("  DUPR \(String(format: "%.1f", dupr)): oob=\(String(format: "%.0f%%", oobRate * 100)), moveScale=\(String(format: "%.3f", effScale)), moveSpd=\(String(format: "%.3f", effectiveMoveSpeed))")
                    for count in 0...3 {
                        var tr = TrialResults()
                        for _ in 0..<500 {
                            tr.record(Self.pressureTrial(defenderDUPR: dupr, attackerDUPR: dupr, pressureCount: count))
                        }
                        print("    \(tr.summary(label: "shot#\(count)"))")
                    }
                }
            }

            let rmse = sqrt(totalError / Double(Self.missRateTargets.count))

            print("Iteration \(iteration): shrink=\(String(format: "%.3f", shrinkPerShot)) minMult=\(String(format: "%.3f", hitboxMin)) resist=\(String(format: "%.3f", touchResist)) baseMvSpd=\(String(format: "%.3f", baseMoveSpeed)) maxMvBon=\(String(format: "%.3f", maxMoveBonus)) scaleLo=\(String(format: "%.3f", scaleLow)) scaleHi=\(String(format: "%.3f", scaleHigh))")
            for r in results {
                let status = Swift.abs(r.measured - r.target) <= Self.tolerance ? "OK" : "MISS"
                print("  DUPR \(String(format: "%.1f", r.dupr)): \(String(format: "%.1f%%", r.measured * 100)) (target: \(String(format: "%.0f%%", r.target * 100))) [\(status)]")
            }
            print("  RMSE: \(String(format: "%.4f", rmse))")

            if totalError < bestTotalError {
                bestTotalError = totalError
                bestShrink = shrinkPerShot
                bestMin = hitboxMin
                bestResist = touchResist
                bestBaseMoveSpeed = baseMoveSpeed
                bestMaxMoveBonus = maxMoveBonus
                bestScaleLow = scaleLow
                bestScaleHigh = scaleHigh
            }

            let allGood = results.allSatisfy { Swift.abs($0.measured - $0.target) <= Self.tolerance }
            if allGood {
                print("\nAll DUPR levels within tolerance after \(iteration) iterations!")
                break
            }

            // --- Gradient adjustments (7 parameters, targeted roles) ---
            let lr: CGFloat = 0.5

            let lowResult = results.first { $0.dupr == 2.0 }!
            let midResult = results.first { $0.dupr == 3.5 }!
            let highResult = results.first { $0.dupr == 6.5 }!
            let proResult = results.first { $0.dupr == 5.0 }!
            let lowError = lowResult.measured - lowResult.target
            let midError = midResult.measured - midResult.target
            let highError = highResult.measured - highResult.target
            let proError = proResult.measured - proResult.target

            let measuredSlope = (lowResult.measured - highResult.measured) / 4.5
            let targetSlope = (lowResult.target - highResult.target) / 4.5
            let slopeError = measuredSlope - targetSlope

            // 1. pressureShrinkPerShot — drives overall pressure level (mid-DUPR)
            //    Positive midError = miss rate too high → decrease shrink (less pressure)
            if Swift.abs(midError) > Self.tolerance {
                shrinkPerShot -= CGFloat(midError) * lr * 0.15
                shrinkPerShot = max(0.05, min(0.50, shrinkPerShot))
            }

            // 2. pressureTouchResistMax — DUPR differentiation via accuracy stat
            //    Positive slopeError = slope too steep → decrease touchResist (high DUPR resists less → more miss → flatter)
            //    Negative slopeError = slope too flat → increase touchResist (high DUPR resists more → less miss → steeper)
            if Swift.abs(slopeError) > 0.02 {
                touchResist -= CGFloat(slopeError) * lr * 0.3
                touchResist = max(0.10, min(0.90, touchResist))
            }

            // 3. pressureHitboxMinMultiplier — low-DUPR floor
            //    Positive lowError = beginner miss too high → increase floor (less extreme pressure)
            if Swift.abs(lowError) > Self.tolerance {
                hitboxMin += CGFloat(lowError) * lr * 0.10
                hitboxMin = max(0.20, min(0.80, hitboxMin))
            }

            // 4. npcMoveSpeedScaleHigh — high-DUPR movement (elite reachability)
            //    Positive highError = elite miss too high → increase scaleHigh (faster elites → less miss)
            if Swift.abs(highError) > Self.tolerance {
                scaleHigh += CGFloat(highError) * lr * 0.4
                scaleHigh = max(0.50, min(3.0, scaleHigh))
            }

            // 5. npcMoveSpeedScaleLow — low-DUPR movement (beginner slowness)
            //    Positive lowError = beginner miss too high → increase scaleLow (faster → less miss)
            //    Negative lowError = beginner miss too low → decrease scaleLow (slower → more miss)
            if Swift.abs(lowError) > Self.tolerance {
                scaleLow += CGFloat(lowError) * lr * 0.06
                scaleLow = max(0.05, min(0.60, scaleLow))
            }

            // 6. baseMoveSpeed — overall movement floor (affects all DUPRs equally)
            //    Positive avgError = overall miss too high → increase base speed
            let avgError = results.reduce(0.0) { $0 + ($1.measured - $1.target) } / Double(results.count)
            if Swift.abs(avgError) > Self.tolerance {
                baseMoveSpeed += CGFloat(avgError) * lr * 0.03
                baseMoveSpeed = max(0.04, min(0.80, baseMoveSpeed))
            }

            // 7. maxMoveSpeedBonus — stat-based speed scaling (DUPR differentiation via movement)
            //    Positive slopeError = slope too steep → decrease maxMoveBonus (less speed differentiation)
            if Swift.abs(slopeError) > 0.03 {
                maxMoveBonus -= CGFloat(slopeError) * lr * 0.06
                maxMoveBonus = max(0.08, min(1.5, maxMoveBonus))
            }

            print("")
        }

        P.pressureShrinkPerShot = bestShrink
        P.pressureHitboxMinMultiplier = bestMin
        P.pressureTouchResistMax = bestResist
        P.baseMoveSpeed = bestBaseMoveSpeed
        P.maxMoveSpeedBonus = bestMaxMoveBonus
        P.npcMoveSpeedScaleLow = bestScaleLow
        P.npcMoveSpeedScaleHigh = bestScaleHigh

        print("\n--- Final Verification (\(Self.verifyTrials / 3) trials per DUPR × count) ---")
        var allPassed = true
        for (dupr, target) in Self.missRateTargets {
            let (rate, _) = Self.weightedMissRate(
                defenderDUPR: dupr, attackerDUPR: dupr,
                trialsPerCount: Self.verifyTrials / 3
            )
            let status = Swift.abs(rate - target) <= Self.tolerance ? "PASS" : "FAIL"
            if Swift.abs(rate - target) > Self.tolerance { allPassed = false }
            print("  DUPR \(String(format: "%.1f", dupr)): \(String(format: "%.1f%%", rate * 100)) (target: \(String(format: "%.0f%%", target * 100))) [\(status)]")
        }

        print("\nOptimal constants:")
        print("  pressureShrinkPerShot = \(String(format: "%.4f", bestShrink))")
        print("  pressureHitboxMinMultiplier = \(String(format: "%.4f", bestMin))")
        print("  pressureTouchResistMax = \(String(format: "%.4f", bestResist))")
        print("  baseMoveSpeed = \(String(format: "%.4f", bestBaseMoveSpeed))")
        print("  maxMoveSpeedBonus = \(String(format: "%.4f", bestMaxMoveBonus))")
        print("  npcMoveSpeedScaleLow = \(String(format: "%.4f", bestScaleLow))")
        print("  npcMoveSpeedScaleHigh = \(String(format: "%.4f", bestScaleHigh))")

        if allPassed {
            writePressureConstants(
                shrinkPerShot: bestShrink,
                hitboxMinMultiplier: bestMin,
                touchResistMax: bestResist,
                baseMoveSpeed: bestBaseMoveSpeed,
                maxMoveSpeedBonus: bestMaxMoveBonus,
                moveSpeedScaleLow: bestScaleLow,
                moveSpeedScaleHigh: bestScaleHigh
            )
            print("\nConstants written to GameConstants.swift")
        } else {
            P.pressureShrinkPerShot = origShrink
            P.pressureHitboxMinMultiplier = origMin
            P.pressureTouchResistMax = origResist
            P.baseMoveSpeed = origBaseMoveSpeed
            P.maxMoveSpeedBonus = origMaxMoveBonus
            P.npcMoveSpeedScaleLow = origScaleLow
            P.npcMoveSpeedScaleHigh = origScaleHigh
            print("\nWARNING: Not all targets met — constants NOT written. Review and re-run.")
        }

        #expect(allPassed, "All DUPR pressure miss rates should be within tolerance of targets")
    }

    // MARK: - Test 2: Verify DUPR Gap Pressure (cross-level, read-only verify)

    @Test func verifyDUPRGapPressure() {
        print("DUPR Gap Pressure Verification")
        print("==============================")

        let pairs: [(defender: Double, attacker: Double)] = [
            (3.0, 3.5), (3.0, 4.0), (4.5, 5.0), (4.0, 5.0)
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

    // MARK: - Write Constants

    private func writePressureConstants(
        shrinkPerShot: CGFloat,
        hitboxMinMultiplier: CGFloat,
        touchResistMax: CGFloat,
        baseMoveSpeed: CGFloat,
        maxMoveSpeedBonus: CGFloat,
        moveSpeedScaleLow: CGFloat,
        moveSpeedScaleHigh: CGFloat
    ) {
        guard var source = readGameConstants() else { return }

        replace(in: &source,
                #"nonisolated\(unsafe\) static var pressureShrinkPerShot: CGFloat = [\d.]+"#,
                with: "nonisolated(unsafe) static var pressureShrinkPerShot: CGFloat = \(String(format: "%.4f", shrinkPerShot))")
        replace(in: &source,
                #"nonisolated\(unsafe\) static var pressureHitboxMinMultiplier: CGFloat = [\d.]+"#,
                with: "nonisolated(unsafe) static var pressureHitboxMinMultiplier: CGFloat = \(String(format: "%.4f", hitboxMinMultiplier))")
        replace(in: &source,
                #"nonisolated\(unsafe\) static var pressureTouchResistMax: CGFloat = [\d.]+"#,
                with: "nonisolated(unsafe) static var pressureTouchResistMax: CGFloat = \(String(format: "%.4f", touchResistMax))")
        replace(in: &source,
                #"nonisolated\(unsafe\) static var baseMoveSpeed: CGFloat = [\d.]+"#,
                with: "nonisolated(unsafe) static var baseMoveSpeed: CGFloat = \(String(format: "%.4f", baseMoveSpeed))")
        replace(in: &source,
                #"nonisolated\(unsafe\) static var maxMoveSpeedBonus: CGFloat = [\d.]+"#,
                with: "nonisolated(unsafe) static var maxMoveSpeedBonus: CGFloat = \(String(format: "%.4f", maxMoveSpeedBonus))")
        replace(in: &source,
                #"nonisolated\(unsafe\) static var npcMoveSpeedScaleLow: CGFloat = [\d.]+"#,
                with: "nonisolated(unsafe) static var npcMoveSpeedScaleLow: CGFloat = \(String(format: "%.4f", moveSpeedScaleLow))")
        replace(in: &source,
                #"nonisolated\(unsafe\) static var npcMoveSpeedScaleHigh: CGFloat = [\d.]+"#,
                with: "nonisolated(unsafe) static var npcMoveSpeedScaleHigh: CGFloat = \(String(format: "%.4f", moveSpeedScaleHigh))")

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
