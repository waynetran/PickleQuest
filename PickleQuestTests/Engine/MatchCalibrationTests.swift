import Testing
@testable import PickleQuest

@Suite("Match Calibration Tests — DUPR Gap vs Point Margin")
struct MatchCalibrationTests {

    // MARK: - Helpers

    /// Create flat-stat PlayerStats where all 11 stats are the same value.
    private func flatStats(_ value: Int) -> PlayerStats {
        PlayerStats(
            power: value, accuracy: value, spin: value, speed: value,
            defense: value, reflexes: value, positioning: value,
            clutch: value, focus: value, stamina: value, consistency: value
        )
    }

    /// Simulate many single-game matches and return (avgMargin, winRate).
    /// Margin is always from the perspective of the stronger player (player side).
    private func simulateMargin(
        playerStat: Int,
        opponentStat: Int,
        matchCount: Int = 500
    ) async -> (avgMargin: Double, winRate: Double) {
        var totalMargin = 0.0
        var wins = 0

        for _ in 0..<matchCount {
            let engine = MatchEngine(
                playerStats: flatStats(playerStat),
                opponentStats: flatStats(opponentStat),
                config: .quickMatch
            )
            let result = await engine.simulateToResult()
            let margin = Double(result.finalScore.playerPoints - result.finalScore.opponentPoints)
            totalMargin += margin
            if result.didPlayerWin { wins += 1 }
        }

        return (totalMargin / Double(matchCount), Double(wins) / Double(matchCount))
    }

    // MARK: - Equal Stats

    @Test("Equal stats produce near-zero margin")
    func equalStatsNearZeroMargin() async {
        let (margin, winRate) = await simulateMargin(playerStat: 50, opponentStat: 50, matchCount: 500)

        #expect(abs(margin) < 1.5, "Equal stats should have near-zero margin, got \(String(format: "%.2f", margin))")
        #expect(winRate > 0.35 && winRate < 0.65, "Equal stats should be ~50/50, got \(Int(winRate * 100))%")
    }

    // MARK: - 0.1 DUPR Gap (~1.63 stat points → stat 51 vs 49)

    @Test("0.1 DUPR gap produces ~1.2 point margin")
    func smallGapCalibration() async {
        // 0.1 DUPR = ~1.63 stat points (stat range 1-99 maps to DUPR 2.0-8.0)
        // Using stat 51 vs 49 (2-point gap ≈ 0.12 DUPR)
        let (margin, _) = await simulateMargin(playerStat: 51, opponentStat: 49, matchCount: 1000)

        // Target: ~1.2 points. Accept 0.3-2.5 given Monte Carlo variance.
        #expect(margin > 0.3, "0.1 DUPR gap margin should be > 0.3, got \(String(format: "%.2f", margin))")
        #expect(margin < 2.5, "0.1 DUPR gap margin should be < 2.5, got \(String(format: "%.2f", margin))")
    }

    // MARK: - 1.0 DUPR Gap (stat 58 vs 42)

    @Test("1.0 DUPR gap produces decisive win")
    func largeGapDecisiveWin() async {
        // 1.0 DUPR = ~16.3 stat points → stat 58 vs 42
        let (margin, winRate) = await simulateMargin(playerStat: 58, opponentStat: 42, matchCount: 500)

        #expect(margin > 4.0, "1.0 DUPR gap should produce > 4.0 margin, got \(String(format: "%.2f", margin))")
        #expect(winRate > 0.85, "1.0 DUPR gap should have > 85% win rate, got \(Int(winRate * 100))%")
    }

    // MARK: - Monotonic Margin Increase

    @Test("Margins increase monotonically with DUPR gap")
    func monotonicMarginIncrease() async {
        // 0.1 gap (51 vs 49), 0.3 gap (52 vs 47), 0.5 gap (54 vs 46), 1.0 gap (58 vs 42)
        let gaps: [(player: Int, opponent: Int, label: String)] = [
            (51, 49, "0.1 gap"),
            (52, 47, "0.3 gap"),
            (54, 46, "0.5 gap"),
            (58, 42, "1.0 gap"),
        ]

        var margins: [Double] = []
        for gap in gaps {
            let (margin, _) = await simulateMargin(
                playerStat: gap.player,
                opponentStat: gap.opponent,
                matchCount: 500
            )
            margins.append(margin)
        }

        for i in 1..<margins.count {
            #expect(
                margins[i] > margins[i - 1],
                "\(gaps[i].label) margin (\(String(format: "%.2f", margins[i]))) should exceed \(gaps[i - 1].label) margin (\(String(format: "%.2f", margins[i - 1])))"
            )
        }
    }

    // MARK: - High-Level Gap

    @Test("High-level gap (stat 90 vs 88) produces similar margin to midrange")
    func highLevelGapCalibration() async {
        // Verify calibration holds at the extremes — stat 90 vs 88 (2-point gap ≈ 0.12 DUPR)
        let (margin, _) = await simulateMargin(playerStat: 90, opponentStat: 88, matchCount: 1000)

        #expect(margin > 0.1, "High-level 0.1 DUPR gap should produce positive margin, got \(String(format: "%.2f", margin))")
        #expect(margin < 3.0, "High-level 0.1 DUPR gap should stay reasonable, got \(String(format: "%.2f", margin))")
    }
}
