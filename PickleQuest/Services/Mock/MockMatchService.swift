import Foundation

final class MockMatchService: MatchService {
    func createMatch(
        player: Player,
        opponent: NPC,
        config: MatchConfig
    ) -> MatchEngine {
        MatchEngine(
            playerStats: player.stats,
            opponentStats: opponent.stats,
            playerName: player.name,
            opponentName: opponent.name,
            config: config
        )
    }

    func processMatchResult(
        _ result: MatchResult,
        for player: inout Player,
        opponent: NPC
    ) {
        // Award XP
        let rewards = player.progression.addXP(result.xpEarned)
        _ = rewards // Level-up UI handled by ViewModel

        // Award coins
        let bonus = Int(Double(result.coinsEarned) * opponent.rewardMultiplier)
        player.wallet.add(result.coinsEarned + bonus)
    }
}
