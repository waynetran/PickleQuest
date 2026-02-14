import Testing
@testable import PickleQuest

@Suite("Match Engine Tests")
struct MatchEngineTests {

    // MARK: - Higher rated player wins more

    @Test("Higher rated player wins majority over many simulations")
    func higherRatedPlayerWinsMajority() async {
        let strongStats = PlayerStats(
            power: 40, accuracy: 40, spin: 35, speed: 38,
            defense: 38, reflexes: 35, positioning: 38,
            clutch: 35, stamina: 35, consistency: 40
        )
        let weakStats = PlayerStats(
            power: 15, accuracy: 15, spin: 10, speed: 15,
            defense: 15, reflexes: 12, positioning: 15,
            clutch: 10, stamina: 15, consistency: 15
        )

        var playerWins = 0
        let totalMatches = 200

        for _ in 0..<totalMatches {
            let engine = MatchEngine(
                playerStats: strongStats,
                opponentStats: weakStats,
                config: .quickMatch
            )
            let result = await engine.simulateToResult()
            if result.didPlayerWin { playerWins += 1 }
        }

        let winRate = Double(playerWins) / Double(totalMatches)
        #expect(winRate > 0.60, "Strong player should win >60% but won \(Int(winRate * 100))%")
    }

    // MARK: - Equal players produce close results

    @Test("Equal players produce roughly 50/50 results")
    func equalPlayersProduceCloseResults() async {
        let stats = PlayerStats(
            power: 25, accuracy: 25, spin: 25, speed: 25,
            defense: 25, reflexes: 25, positioning: 25,
            clutch: 25, stamina: 25, consistency: 25
        )

        var playerWins = 0
        let totalMatches = 200

        for _ in 0..<totalMatches {
            let engine = MatchEngine(
                playerStats: stats,
                opponentStats: stats,
                config: .quickMatch
            )
            let result = await engine.simulateToResult()
            if result.didPlayerWin { playerWins += 1 }
        }

        let winRate = Double(playerWins) / Double(totalMatches)
        #expect(winRate > 0.30 && winRate < 0.70, "Equal players should win ~50% but rate was \(Int(winRate * 100))%")
    }

    // MARK: - Match completes with valid result

    @Test("Match produces valid result with all required fields")
    func matchProducesValidResult() async {
        let engine = MatchEngine(
            playerStats: .starter,
            opponentStats: .starter,
            config: .quickMatch
        )
        let result = await engine.simulateToResult()

        #expect(result.totalPoints > 0)
        #expect(result.gameScores.count >= 1)
        #expect(result.xpEarned > 0)
        #expect(result.coinsEarned > 0)
        #expect(result.playerStats.finalEnergy >= 0)
        #expect(result.opponentStats.finalEnergy >= 0)
    }

    // MARK: - Quick match is single game

    @Test("Quick match config produces exactly one game")
    func quickMatchSingleGame() async {
        let engine = MatchEngine(
            playerStats: .starter,
            opponentStats: .starter,
            config: .quickMatch
        )
        let result = await engine.simulateToResult()

        #expect(result.gameScores.count == 1)
        #expect(result.finalScore.playerGames + result.finalScore.opponentGames == 1)
    }
}
