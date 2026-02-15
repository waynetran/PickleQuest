import Foundation

protocol TrainingService: Sendable {
    func performDrill(_ drill: TrainingDrill, effectiveStats: PlayerStats) async -> TrainingResult
}
