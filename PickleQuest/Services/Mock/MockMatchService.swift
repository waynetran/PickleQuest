import Foundation

final class MockMatchService: MatchService {
    private let inventoryService: InventoryService

    init(inventoryService: InventoryService) {
        self.inventoryService = inventoryService
    }

    func createMatch(
        player: Player,
        opponent: NPC,
        config: MatchConfig
    ) async -> MatchEngine {
        // Resolve equipped items from inventory
        let equippedItems = await inventoryService.getEquippedItems(for: player.equippedItems)

        return MatchEngine(
            playerStats: player.stats,
            opponentStats: opponent.stats,
            playerEquipment: equippedItems,
            playerName: player.name,
            opponentName: opponent.name,
            config: config,
            lootGenerator: LootGenerator(),
            opponentDifficulty: opponent.difficulty,
            playerLevel: player.progression.level
        )
    }

    func processMatchResult(
        _ result: MatchResult,
        for player: inout Player,
        opponent: NPC,
        config: MatchConfig
    ) -> MatchRewards {
        // Award XP
        let levelUpRewards = player.progression.addXP(result.xpEarned)

        // Award coins with difficulty bonus
        let bonus = Int(Double(result.coinsEarned) * opponent.rewardMultiplier)
        player.wallet.add(result.coinsEarned + bonus)

        // Calculate DUPR change for rated matches
        var duprChange: Double? = nil
        let isRated = config.isRated && !DUPRCalculator.shouldAutoUnrate(
            playerRating: player.duprRating,
            opponentRating: opponent.duprRating
        )

        if isRated {
            // Use the last game score for margin-of-victory calculation
            let lastGame = result.gameScores.last ?? result.finalScore
            let change = DUPRCalculator.calculateRatingChange(
                playerRating: player.duprRating,
                opponentRating: opponent.duprRating,
                playerPoints: lastGame.playerPoints,
                opponentPoints: lastGame.opponentPoints,
                pointsToWin: config.pointsToWin,
                kFactor: player.duprProfile.kFactor
            )
            player.duprProfile.recordRatedMatch(opponentID: opponent.id, ratingChange: change)
            duprChange = change
        }

        return MatchRewards(
            levelUpRewards: levelUpRewards,
            duprChange: duprChange
        )
    }
}

struct MatchRewards: Sendable {
    let levelUpRewards: [LevelUpReward]
    let duprChange: Double?
}
