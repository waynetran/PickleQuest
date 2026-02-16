import Foundation

protocol TrainingService: Sendable {
    func performDrill(_ drill: TrainingDrill, stat: StatType, coachLevel: Int, playerEnergy: Double, coachEnergy: Double) async -> TrainingResult
}
