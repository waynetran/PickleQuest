import Foundation

@MainActor
@Observable
final class TrainingViewModel {
    private let trainingService: TrainingService

    let coach: Coach
    var trainingResult: TrainingResult?
    var isSimulating = false
    var errorMessage: String?
    var animationComplete = false

    init(trainingService: TrainingService, coach: Coach) {
        self.trainingService = trainingService
        self.coach = coach
    }

    private static let coachLevelGains: [Int: Int] = [
        1: 2, 2: 3, 3: 4, 4: 6, 5: 8
    ]

    /// Expected stat gain based on both player and coach energy.
    func expectedGain(playerEnergy: Double, coachEnergy: Double) -> Int {
        let baseGain = Self.coachLevelGains[coach.level] ?? coach.level
        return max(1, Int(round(Double(baseGain) * (playerEnergy / 100.0) * (coachEnergy / 100.0))))
    }

    func startDrill(player: inout Player) async {
        let stat = coach.dailySpecialtyStat
        let drillType = coach.dailyDrillType
        let drill = TrainingDrill(type: drillType)
        errorMessage = nil
        animationComplete = false

        // Check energy
        guard player.currentEnergy >= drill.energyCost else {
            errorMessage = "Not enough energy (\(Int(drill.energyCost))% needed)"
            return
        }

        // Check coach energy
        let coachEnergy = player.coachingRecord.coachRemainingEnergy(coachID: coach.id)
        guard coachEnergy > 0 else {
            errorMessage = coach.dialogue.onExhausted
            return
        }

        // Check cost
        let fee = player.coachingRecord.fee(for: coach)
        guard player.wallet.coins >= fee else {
            errorMessage = "Not enough coins (\(fee) needed)"
            return
        }

        // Deduct costs
        player.wallet.coins -= fee
        player.energy = max(
            GameConstants.PersistentEnergy.minEnergy,
            player.currentEnergy - drill.energyCost
        )
        player.lastMatchDate = Date()

        isSimulating = true

        // Run simulation with both energies
        let result = await trainingService.performDrill(
            drill,
            stat: stat,
            coachLevel: coach.level,
            playerEnergy: player.currentEnergy,
            coachEnergy: coachEnergy
        )

        // Drain coach energy
        player.coachingRecord.drainCoach(
            coachID: coach.id,
            amount: GameConstants.Coaching.coachDrainPerSession
        )

        // Apply stat gain
        let currentValue = player.stats.stat(stat)
        player.stats.setStat(stat, value: min(currentValue + result.statGainAmount, GameConstants.Stats.maxValue))
        player.coachingRecord.recordSession(coachID: coach.id, stat: stat, amount: result.statGainAmount)

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

    func onAnimationComplete() {
        animationComplete = true
    }

    func clearResult() {
        trainingResult = nil
        errorMessage = nil
        animationComplete = false
    }
}
