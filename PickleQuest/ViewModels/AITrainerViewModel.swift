import Foundation

@Observable
@MainActor
final class AITrainerViewModel {
    let session = TrainingSession()

    var report: TrainingReport?
    var isTraining: Bool { session.isRunning }

    var shareText: String {
        report?.formattedReport() ?? ""
    }

    func startTraining() {
        report = nil
        Task {
            let result = await session.start()
            report = result
        }
    }

    func stopTraining() {
        session.stop()
    }
}
