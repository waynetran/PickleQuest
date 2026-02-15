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
        let equippedItems = await inventoryService.getEquippedItems(for: player.equippedItems)
        let suprGap = opponent.duprRating - player.duprRating

        return MatchEngine(
            playerStats: player.stats,
            opponentStats: opponent.stats,
            playerEquipment: equippedItems,
            playerName: player.name,
            opponentName: opponent.name,
            config: config,
            lootGenerator: LootGenerator(),
            opponentDifficulty: opponent.difficulty,
            playerLevel: player.progression.level,
            startingEnergy: player.currentEnergy,
            suprGap: suprGap
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

        // Reputation
        let repChange = RepCalculator.calculateRepChange(
            didWin: result.didPlayerWin,
            playerSUPR: player.duprRating,
            opponentSUPR: opponent.duprRating,
            opponentDifficulty: opponent.difficulty
        )
        player.repProfile.applyRepChange(repChange)

        // Equipment durability (only on loss, only wearable slots)
        let suprGap = opponent.duprRating - player.duprRating
        var brokenEquipment: [Equipment] = []

        if !result.didPlayerWin {
            let baseWear = GameConstants.Durability.baseLossWear
            let gapBonus = suprGap > 0
                ? suprGap * GameConstants.Durability.suprGapWearBonus
                : 0
            let wear = min(GameConstants.Durability.maxWearPerMatch, baseWear + gapBonus)

            for (slot, equipID) in player.equippedItems {
                if slot == .shoes || slot == .paddle {
                    // Find current condition from inventory (we'll update in MatchHubView)
                    // For now store the wear amount; MatchHubView applies it
                }
                _ = (slot, equipID, wear) // suppress unused warnings
            }
            // We compute broken equipment at the MatchHubView level with inventory access
        }

        // Persistent energy drain (only on loss)
        var energyDrain = 0.0
        if !result.didPlayerWin {
            let baseDrain = GameConstants.PersistentEnergy.baseLossDrain
            let gapDrain = suprGap > 0
                ? suprGap * GameConstants.PersistentEnergy.suprGapDrainBonus
                : 0
            energyDrain = min(GameConstants.PersistentEnergy.maxDrainPerMatch, baseDrain + gapDrain)
            let newEnergy = max(
                GameConstants.PersistentEnergy.minEnergy,
                player.currentEnergy - energyDrain
            )
            player.energy = newEnergy
        } else {
            // Wins don't drain persistent energy; snapshot current recovered energy
            player.energy = player.currentEnergy
        }
        player.lastMatchDate = Date()

        return MatchRewards(
            levelUpRewards: levelUpRewards,
            duprChange: duprChange,
            repChange: repChange,
            energyDrain: energyDrain,
            brokenEquipment: brokenEquipment
        )
    }
}

struct MatchRewards: Sendable {
    let levelUpRewards: [LevelUpReward]
    let duprChange: Double?
    let repChange: Int
    let energyDrain: Double
    let brokenEquipment: [Equipment]
}
