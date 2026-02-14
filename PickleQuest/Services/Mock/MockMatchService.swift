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
        opponent: NPC
    ) -> [LevelUpReward] {
        // Award XP
        let rewards = player.progression.addXP(result.xpEarned)

        // Award coins with difficulty bonus
        let bonus = Int(Double(result.coinsEarned) * opponent.rewardMultiplier)
        player.wallet.add(result.coinsEarned + bonus)

        return rewards
    }
}
