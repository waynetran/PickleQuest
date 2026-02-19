import Testing
import Foundation
import CoreGraphics
@testable import PickleQuest

@Suite("Pressure Drop Shot Balance")
struct PressureDropShotBalanceTests {

    // MARK: - Targets
    // All tests use real MatchAI in interactive mode with pressure positioning.
    // Tolerance is ±0.10 to account for stat variance and interaction with other AI systems.

    /// Drop shot selection rate under pressure (NPC deep, opponent at net)
    static let dropSelectTargets: [(dupr: Double, rate: Double)] = [
        (2.0, 0.12), (3.0, 0.28), (3.5, 0.36),
        (4.5, 0.54), (5.5, 0.66), (6.5, 0.75)
    ]

    /// Drop error rate: NPC chose touch under pressure and shouldMakeError returns true
    static let dropErrorTargets: [(dupr: Double, rate: Double)] = [
        (2.0, 0.50), (3.0, 0.32), (3.5, 0.22),
        (4.5, 0.13), (5.5, 0.06), (6.5, 0.03)
    ]

    /// Kitchen approach after successful drop: NPC moves toward kitchen line (NY < 0.80)
    static let kitchenApproachTargets: [(dupr: Double, rate: Double)] = [
        (2.0, 0.12), (3.0, 0.33), (3.5, 0.45),
        (4.5, 0.65), (5.5, 0.85), (6.5, 0.95)
    ]

    static let tolerance: Double = 0.10
    static let trialsPerDUPR = 5000

    // MARK: - Helpers

    /// Create a MatchAI positioned for pressure: NPC deep (NY=0.88), player at net (NY=0.25).
    private static func createPressureAI(dupr: Double) -> MatchAI {
        let npc = NPC.practiceOpponent(dupr: dupr)
        let ai = MatchAI(npc: npc, playerDUPR: dupr, headless: false)
        ai.currentNX = 0.5
        ai.currentNY = 0.88
        ai.playerPositionNX = 0.5
        ai.playerPositionNY = 0.25
        return ai
    }

    /// Create an incoming ball at the NPC's deep position (typical rally ball).
    /// Height is kept below 0.20 to avoid smash override in preselectModes.
    private static func createPressureBall() -> DrillBallSimulation {
        let ball = DrillBallSimulation()
        ball.isActive = true
        ball.lastHitByPlayer = true
        ball.courtX = CGFloat.random(in: 0.20...0.80)
        ball.courtY = CGFloat.random(in: 0.82...0.90)
        ball.height = CGFloat.random(in: 0.03...0.08)
        ball.vx = CGFloat.random(in: (-0.3)...0.3)
        ball.vy = CGFloat.random(in: (-0.5)...(-0.1))
        ball.bounceCount = 1
        return ball
    }

    // MARK: - Test 1: Drop Selection Rate (real MatchAI)

    /// Verify that MatchAI.preselectModes() produces DUPR-appropriate drop/drive/lob
    /// selection rates when the NPC is deep and the opponent is at the net.
    @Test func verifyPressureDropSelection() {
        print("Pressure Drop Selection (Real MatchAI)")
        print("=======================================")

        var allPassed = true

        for (dupr, target) in Self.dropSelectTargets {
            var dropCount = 0
            var lobCount = 0
            var driveCount = 0

            for _ in 0..<Self.trialsPerDUPR {
                let ai = Self.createPressureAI(dupr: dupr)
                let ball = Self.createPressureBall()
                ai.preselectModes(ball: ball)

                if ai.lastShotModes.contains(.touch) {
                    dropCount += 1
                } else if ai.lastShotModes.contains(.lob) {
                    lobCount += 1
                } else {
                    driveCount += 1
                }
            }

            let dropRate = Double(dropCount) / Double(Self.trialsPerDUPR)
            let lobRate = Double(lobCount) / Double(Self.trialsPerDUPR)
            let driveRate = Double(driveCount) / Double(Self.trialsPerDUPR)
            let pass = Swift.abs(dropRate - target) <= Self.tolerance
            if !pass { allPassed = false }
            let status = pass ? "PASS" : "FAIL"
            print("  DUPR \(String(format: "%.1f", dupr)): drop=\(String(format: "%.1f%%", dropRate * 100)) (target: \(String(format: "%.0f%%", target * 100))) lob=\(String(format: "%.1f%%", lobRate * 100)) drive=\(String(format: "%.1f%%", driveRate * 100)) [\(status)]")
        }

        #expect(allPassed, "All DUPR drop selection rates should be within tolerance")
    }

    // MARK: - Test 2: Drop Error Rate (real MatchAI)

    /// Verify that shouldMakeError() produces DUPR-appropriate error rates
    /// when the NPC chose touch mode under pressure (drop shot quality).
    @Test func verifyPressureDropErrorRate() {
        print("Pressure Drop Error Rate (Real MatchAI)")
        print("========================================")

        var allPassed = true

        for (dupr, target) in Self.dropErrorTargets {
            var errorCount = 0
            var touchTrials = 0

            // Run enough trials to get at least trialsPerDUPR touch selections
            var attempts = 0
            while touchTrials < Self.trialsPerDUPR && attempts < Self.trialsPerDUPR * 10 {
                attempts += 1
                let ai = Self.createPressureAI(dupr: dupr)
                let ball = Self.createPressureBall()

                // Preselect modes — only measure error rate when touch was chosen
                ai.preselectModes(ball: ball)
                guard ai.lastShotModes.contains(.touch) else { continue }

                touchTrials += 1
                if ai.shouldMakeError(ball: ball) {
                    errorCount += 1
                }
            }

            guard touchTrials > 0 else {
                print("  DUPR \(String(format: "%.1f", dupr)): no touch selections in \(attempts) attempts [SKIP]")
                continue
            }

            let errorRate = Double(errorCount) / Double(touchTrials)
            let pass = Swift.abs(errorRate - target) <= Self.tolerance
            if !pass { allPassed = false }
            let status = pass ? "PASS" : "FAIL"
            print("  DUPR \(String(format: "%.1f", dupr)): error=\(String(format: "%.1f%%", errorRate * 100)) (target: \(String(format: "%.0f%%", target * 100))) from \(touchTrials) touch trials [\(status)]")
        }

        #expect(allPassed, "All DUPR drop error rates should be within tolerance")
    }

    // MARK: - Test 3: Kitchen Approach After Drop (real MatchAI)

    /// Verify that after a successful drop shot, the NPC approaches the kitchen
    /// at DUPR-appropriate rates. Measures by calling generateShot() with touch mode,
    /// then running update() frames and checking if NPC moved forward.
    @Test func verifyPressureKitchenApproach() {
        print("Pressure Kitchen Approach (Real MatchAI)")
        print("=========================================")

        var allPassed = true

        for (dupr, target) in Self.kitchenApproachTargets {
            var approachCount = 0
            var successfulDrops = 0

            var attempts = 0
            while successfulDrops < Self.trialsPerDUPR && attempts < Self.trialsPerDUPR * 10 {
                attempts += 1
                let ai = Self.createPressureAI(dupr: dupr)
                let ball = Self.createPressureBall()

                // Preselect — only test when touch mode was chosen
                ai.preselectModes(ball: ball)
                guard ai.lastShotModes.contains(.touch) else { continue }

                // Check if NPC would error (we only want successful drops)
                guard !ai.shouldMakeError(ball: ball) else { continue }

                successfulDrops += 1

                // Generate the shot — this sets lastShotWasTouch = true
                let _ = ai.generateShot(ball: ball)

                // Simulate recovery: ball is now heading toward player (NPC just hit it)
                ball.lastHitByPlayer = false
                ball.courtY = 0.50
                ball.vy = -0.6

                // Run several update frames to let NPC move toward recovery position
                let startNY = ai.currentNY
                for _ in 0..<20 {
                    ai.update(dt: 0.1, ball: ball)
                }

                // Kitchen approach: NPC moved significantly forward from deep position
                // startNY is ~0.88; kitchen line is 0.69; threshold for "approached" = moved >40% of the way
                let moved = startNY - ai.currentNY
                if moved > 0.05 {
                    approachCount += 1
                }
            }

            guard successfulDrops > 0 else {
                print("  DUPR \(String(format: "%.1f", dupr)): no successful drops in \(attempts) attempts [SKIP]")
                continue
            }

            let approachRate = Double(approachCount) / Double(successfulDrops)
            let pass = Swift.abs(approachRate - target) <= Self.tolerance
            if !pass { allPassed = false }
            let status = pass ? "PASS" : "FAIL"
            print("  DUPR \(String(format: "%.1f", dupr)): approach=\(String(format: "%.1f%%", approachRate * 100)) (target: \(String(format: "%.0f%%", target * 100))) from \(successfulDrops) drops [\(status)]")
        }

        #expect(allPassed, "All DUPR kitchen approach rates should be within tolerance")
    }

    // MARK: - Write Constants (for manual tuning when tests fail)

    /// Write tuned pressure constants to GameConstants.swift.
    /// Call this from a separate tuning test if the integration tests fail.
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
