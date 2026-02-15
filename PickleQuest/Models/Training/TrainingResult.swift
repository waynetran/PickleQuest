import Foundation

struct TrainingResult: Sendable {
    let drill: TrainingDrill
    let statGained: StatType
    let statGainAmount: Int
    let xpEarned: Int
}
