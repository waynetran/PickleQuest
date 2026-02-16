import Foundation

actor MockTrainingService: TrainingService {
    private let simulator = TrainingDrillSimulator()

    func performDrill(_ drill: TrainingDrill, stat: StatType, coachLevel: Int, playerEnergy: Double, coachEnergy: Double) async -> TrainingResult {
        simulator.simulate(drill: drill, stat: stat, coachLevel: coachLevel, playerEnergy: playerEnergy, coachEnergy: coachEnergy)
    }
}
