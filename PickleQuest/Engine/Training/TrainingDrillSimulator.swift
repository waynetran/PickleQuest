import Foundation

struct TrainingDrillSimulator: Sendable {
    /// Coach level stat gains scale exponentially so higher-tier coaches are worth the premium.
    /// Level 1: +1-2, Level 2: +2-3, Level 3: +3-4, Level 4: +5-6, Level 5: +7-8
    private static let coachLevelGains: [Int: Int] = [
        1: 2, 2: 3, 3: 4, 4: 6, 5: 8
    ]

    func simulate(drill: TrainingDrill, stat: StatType, coachLevel: Int, playerEnergy: Double, coachEnergy: Double) -> TrainingResult {
        let baseGain = Self.coachLevelGains[coachLevel] ?? coachLevel
        let energyMultiplier = (playerEnergy / 100.0) * (coachEnergy / 100.0)
        let gain = max(1, Int(round(Double(baseGain) * energyMultiplier)))
        let xpEarned = GameConstants.Training.baseTrainingXP * coachLevel

        return TrainingResult(
            drill: drill,
            statGained: stat,
            statGainAmount: gain,
            xpEarned: xpEarned
        )
    }
}
