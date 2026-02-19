import Foundation

final class MockMatchService: MatchService {
    private let inventoryService: InventoryService

    init(inventoryService: InventoryService) {
        self.inventoryService = inventoryService
    }

    func createMatch(
        player: Player,
        opponent: NPC,
        config: MatchConfig,
        playerConsumables: [Consumable] = [],
        playerReputation: Int = 0
    ) async -> MatchEngine {
        let equippedItems = await inventoryService.getEquippedItems(for: player.equippedItems)
        let suprGap = opponent.duprRating - player.duprRating

        // Apply NPC virtual equipment bonus (simulates gear the NPC "has")
        let opponentStats = boostedNPCStats(base: opponent.stats, dupr: opponent.duprRating)

        return MatchEngine(
            playerStats: player.stats,
            opponentStats: opponentStats,
            playerEquipment: equippedItems,
            playerName: player.name,
            opponentName: opponent.name,
            config: config,
            lootGenerator: LootGenerator(),
            opponentDifficulty: opponent.difficulty,
            playerLevel: player.progression.level,
            startingEnergy: player.currentEnergy,
            suprGap: suprGap,
            playerConsumables: playerConsumables,
            playerReputation: playerReputation
        )
    }

    func createDoublesMatch(
        player: Player,
        partner: NPC,
        opponent1: NPC,
        opponent2: NPC,
        config: MatchConfig,
        playerConsumables: [Consumable] = [],
        playerReputation: Int = 0
    ) async -> MatchEngine {
        let equippedItems = await inventoryService.getEquippedItems(for: player.equippedItems)
        let avgOpponentDUPR = (opponent1.duprRating + opponent2.duprRating) / 2.0
        let suprGap = avgOpponentDUPR - player.duprRating

        let teamSynergy = TeamSynergy.calculate(p1: player.playerType, p2: partner.playerType)
        let opponentSynergy = TeamSynergy.calculate(p1: opponent1.playerType, p2: opponent2.playerType)

        // Apply NPC virtual equipment bonus to all NPC participants
        let opp1Stats = boostedNPCStats(base: opponent1.stats, dupr: opponent1.duprRating)
        let opp2Stats = boostedNPCStats(base: opponent2.stats, dupr: opponent2.duprRating)
        let partnerBoostedStats = boostedNPCStats(base: partner.stats, dupr: partner.duprRating)

        return MatchEngine(
            playerStats: player.stats,
            opponentStats: opp1Stats,
            playerEquipment: equippedItems,
            playerName: player.name,
            opponentName: opponent1.name,
            config: config,
            lootGenerator: LootGenerator(),
            opponentDifficulty: opponent1.difficulty,
            playerLevel: player.progression.level,
            startingEnergy: player.currentEnergy,
            suprGap: suprGap,
            playerConsumables: playerConsumables,
            playerReputation: playerReputation,
            partnerStats: partnerBoostedStats,
            partnerEquipment: [],
            partnerName: partner.name,
            opponent2Stats: opp2Stats,
            opponent2Equipment: [],
            opponent2Name: opponent2.name,
            teamSynergy: teamSynergy,
            opponentSynergy: opponentSynergy
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

        // Award coins: wager wins get flat wager amount (no multiplier), regular matches use difficulty bonus
        if config.wagerAmount > 0 {
            if result.didPlayerWin {
                player.wallet.add(config.wagerAmount)
            } else {
                _ = player.wallet.spend(config.wagerAmount)
            }
        } else {
            let bonus = Int(Double(result.coinsEarned) * opponent.rewardMultiplier)
            player.wallet.add(result.coinsEarned + bonus)
        }

        // Calculate DUPR change (all games count, not just the last)
        let potentialChange = DUPRCalculator.calculateRatingChange(
            playerRating: player.duprRating,
            opponentRating: opponent.duprRating,
            gameScores: result.gameScores,
            pointsToWin: config.pointsToWin,
            kFactor: player.duprProfile.kFactor
        )

        var duprChange: Double? = nil
        let isRated = config.isRated && !DUPRCalculator.shouldAutoUnrate(
            playerRating: player.duprRating,
            opponentRating: opponent.duprRating
        )

        if isRated {
            player.duprProfile.recordRatedMatch(opponentID: opponent.id, ratingChange: potentialChange)
            duprChange = potentialChange
        }

        // Reputation
        var repChange = RepCalculator.calculateRepChange(
            didWin: result.didPlayerWin,
            playerSUPR: player.duprRating,
            opponentSUPR: opponent.duprRating
        )
        // Bonus rep for beating a hustler
        if result.didPlayerWin && opponent.isHustler {
            repChange += GameConstants.Wager.hustlerBeatRepBonus
        }
        player.repProfile.applyRepChange(repChange)

        // Equipment durability (only on loss, only wearable slots)
        let suprGap = opponent.duprRating - player.duprRating
        let brokenEquipment: [Equipment] = []

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
            potentialDuprChange: potentialChange,
            repChange: repChange,
            energyDrain: energyDrain,
            brokenEquipment: brokenEquipment
        )
    }

    /// Apply NPC virtual equipment bonus — flat per-stat boost based on DUPR.
    private func boostedNPCStats(base: PlayerStats, dupr: Double) -> PlayerStats {
        let bonus = StatProfileLoader.shared.npcEquipmentBonus(dupr: dupr)
        guard bonus > 0 else { return base }
        var stats = base
        for statType in StatType.allCases {
            stats.setStat(statType, value: stats.stat(statType) + bonus)
        }
        return stats
    }
}

struct MatchRewards: Sendable {
    let levelUpRewards: [LevelUpReward]
    let duprChange: Double?
    let potentialDuprChange: Double
    let repChange: Int
    let energyDrain: Double
    let brokenEquipment: [Equipment]
}
