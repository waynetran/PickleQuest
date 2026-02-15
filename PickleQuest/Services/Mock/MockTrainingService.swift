import Foundation

actor MockTrainingService: TrainingService {
    private let simulator = TrainingDrillSimulator()

    func performDrill(_ drill: TrainingDrill, effectiveStats: PlayerStats) async -> TrainingResult {
        simulator.simulate(drill: drill, effectiveStats: effectiveStats)
    }
}
