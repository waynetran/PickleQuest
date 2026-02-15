import Foundation

struct TrainingDrillSimulator: Sendable {
    func simulate(drill: TrainingDrill, stat: StatType, coachLevel: Int, playerEnergy: Double) -> TrainingResult {
        let energyPercent = playerEnergy
        let gain = max(1, Int((energyPercent / 100.0) * Double(coachLevel)))
        let xpEarned = GameConstants.Training.baseTrainingXP * coachLevel

        return TrainingResult(
            drill: drill,
            statGained: stat,
            statGainAmount: gain,
            xpEarned: xpEarned
        )
    }
}
