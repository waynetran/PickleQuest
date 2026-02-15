import Foundation

@MainActor
@Observable
final class TrainingViewModel {
    private let trainingService: TrainingService
    private let inventoryService: InventoryService
    private let statCalculator = StatCalculator()

    var selectedDrillType: DrillType = .servePractice
    var selectedDifficulty: DrillDifficulty = .medium
    var trainingResult: TrainingResult?
    var isSimulating = false
    var errorMessage: String?

    init(trainingService: TrainingService, inventoryService: InventoryService) {
        self.trainingService = trainingService
        self.inventoryService = inventoryService
    }

    var currentDrill: TrainingDrill {
        TrainingDrill(type: selectedDrillType, difficulty: selectedDifficulty)
    }

    func startDrill(player: inout Player) async {
        let drill = currentDrill
        errorMessage = nil

        // Check energy
        guard player.currentEnergy >= drill.energyCost else {
            errorMessage = "Not enough energy (\(Int(drill.energyCost))% needed)"
            return
        }

        // Check coins
        guard player.wallet.coins >= drill.coinCost else {
            errorMessage = "Not enough coins (\(drill.coinCost) needed)"
            return
        }

        // Deduct costs
        player.wallet.coins -= drill.coinCost
        player.energy = max(
            GameConstants.PersistentEnergy.minEnergy,
            player.currentEnergy - drill.energyCost
        )
        player.lastMatchDate = Date()

        // Calculate effective stats
        let equipped = await inventoryService.getEquippedItems(for: player.equippedItems)
        let effectiveStats = statCalculator.effectiveStats(base: player.stats, equipment: equipped)

        isSimulating = true

        // Run simulation
        let result = await trainingService.performDrill(drill, effectiveStats: effectiveStats)

        // Award XP
        player.progression.currentXP += result.xpEarned
        while player.progression.currentXP >= GameConstants.XP.xpRequired(forLevel: player.progression.level + 1),
              player.progression.level < GameConstants.Stats.maxLevel {
            player.progression.currentXP -= GameConstants.XP.xpRequired(forLevel: player.progression.level + 1)
            player.progression.level += 1
            player.progression.availableStatPoints += GameConstants.Stats.statPointsPerLevel
        }

        trainingResult = result
        isSimulating = false
    }

    func coachSession(coach: Coach, stat: StatType, player: inout Player) -> Bool {
        // Check daily limit
        guard !player.coachingRecord.hasSessionToday(coachID: coach.id) else {
            errorMessage = coach.dialogue.onDailyLimit
            return false
        }

        // Check stat cap
        guard player.coachingRecord.canTrain(stat: stat) else {
            errorMessage = "Max coaching reached for \(stat.displayName) (+\(GameConstants.Coaching.maxCoachingBoostPerStat))"
            return false
        }

        // Check cost
        let fee = player.coachingRecord.fee(for: coach, stat: stat)
        guard player.wallet.coins >= fee else {
            errorMessage = "Not enough coins (\(fee) needed)"
            return false
        }

        // Apply
        player.wallet.coins -= fee
        player.stats.setStat(stat, value: player.stats.stat(stat) + GameConstants.Coaching.baseStatBoost)
        player.coachingRecord.recordSession(coachID: coach.id, stat: stat)

        // Bonus XP
        player.progression.currentXP += GameConstants.Coaching.baseBonusXP
        while player.progression.currentXP >= GameConstants.XP.xpRequired(forLevel: player.progression.level + 1),
              player.progression.level < GameConstants.Stats.maxLevel {
            player.progression.currentXP -= GameConstants.XP.xpRequired(forLevel: player.progression.level + 1)
            player.progression.level += 1
            player.progression.availableStatPoints += GameConstants.Stats.statPointsPerLevel
        }

        errorMessage = nil
        return true
    }

    func clearResult() {
        trainingResult = nil
        errorMessage = nil
    }
}
