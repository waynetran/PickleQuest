import Foundation

/// Captures results of an AI training session.
struct TrainingReport: Sendable {
    let parameters: SimulationParameters
    let fitnessScore: Double
    let generationCount: Int
    let winRateTable: [WinRateEntry]
    let avgRallyLength: Double
    let elapsedSeconds: Double

    struct WinRateEntry: Sendable, Identifiable {
        let id = UUID()
        let higherDUPR: Double
        let lowerDUPR: Double
        let actualWinRate: Double
        let targetWinRate: Double
        let matchesPlayed: Int
        let avgScoreMargin: Double
    }

    func formattedReport() -> String {
        let defaults = SimulationParameters.defaults.toArray()
        let current = parameters.toArray()
        let names = SimulationParameters.parameterNames

        var lines: [String] = []
        lines.append("PickleQuest AI Training Report")
        lines.append("==============================")
        lines.append("Generations: \(generationCount)")
        lines.append(String(format: "Final Fitness: %.4f", fitnessScore))
        lines.append(String(format: "Avg Rally Length: %.1f shots", avgRallyLength))

        let mins = Int(elapsedSeconds) / 60
        let secs = Int(elapsedSeconds) % 60
        lines.append("Duration: \(mins)m \(secs)s")
        lines.append("")

        lines.append("Win Rates (Higher DUPR vs Lower):")
        for entry in winRateTable {
            let actual = String(format: "%.1f%%", entry.actualWinRate * 100)
            let target = String(format: "%.1f%%", entry.targetWinRate * 100)
            let margin = String(format: "%.1f", entry.avgScoreMargin)
            lines.append("  \(String(format: "%.1f", entry.higherDUPR)) vs \(String(format: "%.1f", entry.lowerDUPR)): \(actual) (target: \(target), margin: \(margin))")
        }
        lines.append("")

        lines.append("Optimized Parameters:")
        for i in 0..<names.count {
            let was = String(format: "%.6f", defaults[i])
            let now = String(format: "%.6f", current[i])
            let changed = abs(defaults[i] - current[i]) > 0.0001 ? " *" : ""
            lines.append("  \(names[i]): \(now) (was \(was))\(changed)")
        }

        return lines.joined(separator: "\n")
    }
}
