import Foundation

struct TrainingResult: Sendable {
    let drill: TrainingDrill
    let grade: DrillGrade
    let xpEarned: Int
    let targetStatScores: [StatType: Double]
}
