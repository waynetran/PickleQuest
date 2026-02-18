import Foundation

@Observable
@MainActor
final class DevTrainingMatchViewModel {

    // MARK: - Headless Runner State

    var isRunningHeadless = false
    var headlessProgress: Double = 0
    var matchesPerLevel: Int = 50
    var headlessResults: [HeadlessResultRow] = []

    struct HeadlessResultRow: Identifiable {
        let id = UUID()
        let dupr: Double
        let matchCount: Int
        let winRate: Double
        let avgPointDiff: Double
        let avgRallyLength: Double
        let avgPlayerErrors: Double
        let avgOpponentErrors: Double
    }

    // MARK: - Comparison State

    var loggedEntries: [DevMatchLogEntry] = []
    var comparisonRows: [ComparisonRow] = []

    struct ComparisonRow: Identifiable {
        let id = UUID()
        let dupr: Double
        let realCount: Int
        let headlessCount: Int
        let realWinRate: Double?
        let headlessWinRate: Double?
        let realAvgPointDiff: Double?
        let headlessAvgPointDiff: Double?
        let realAvgRallyLength: Double?
        let headlessAvgRallyLength: Double?
        let realAvgErrors: Double?
        let headlessAvgErrors: Double?
    }

    // MARK: - Load

    func loadEntries() async {
        loggedEntries = await DevMatchLogStore.shared.loadAll()
        buildComparison()
    }

    // MARK: - Headless Runner

    private static let testDUPRs: [Double] = [2.0, 3.0, 4.0, 5.0, 6.0, 7.0]

    func runHeadless() async {
        isRunningHeadless = true
        headlessProgress = 0
        headlessResults = []

        let matchCount = matchesPerLevel
        let duprLevels = Self.testDUPRs
        var allLogEntries: [DevMatchLogEntry] = []
        var rows: [HeadlessResultRow] = []

        for (index, dupr) in duprLevels.enumerated() {
            let (row, entries) = await runHeadlessBatch(dupr: dupr, matchCount: matchCount)
            rows.append(row)
            allLogEntries.append(contentsOf: entries)
            headlessProgress = Double(index + 1) / Double(duprLevels.count)
            headlessResults = rows
        }

        await DevMatchLogStore.shared.appendBatch(allLogEntries)
        loggedEntries = await DevMatchLogStore.shared.loadAll()
        buildComparison()
        isRunningHeadless = false
    }

    private nonisolated func runHeadlessBatch(
        dupr: Double,
        matchCount: Int
    ) -> (HeadlessResultRow, [DevMatchLogEntry]) {
        let playerStats = StatProfileLoader.shared.toPlayerStats(dupr: dupr)
        let npc = NPC.headlessOpponent(dupr: dupr)

        var wins = 0
        var totalPointDiff = 0.0
        var totalRally = 0.0
        var totalPlayerErrors = 0.0
        var totalOpponentErrors = 0.0
        var entries: [DevMatchLogEntry] = []

        for _ in 0..<matchCount {
            let sim = HeadlessMatchSimulator(
                npc: npc,
                playerStats: playerStats,
                playerDUPR: dupr
            )
            let result = sim.simulateMatch()

            if result.winnerSide == .player { wins += 1 }
            totalPointDiff += Double(result.playerScore - result.opponentScore)
            totalRally += result.avgRallyLength
            totalPlayerErrors += Double(result.playerErrors)
            totalOpponentErrors += Double(result.npcErrors)

            entries.append(DevMatchLogEntry(
                id: UUID(),
                date: Date(),
                source: .headless,
                playerDUPR: dupr,
                opponentDUPR: dupr,
                playerScore: result.playerScore,
                opponentScore: result.opponentScore,
                didPlayerWin: result.winnerSide == .player,
                totalPoints: result.playerScore + result.opponentScore,
                avgRallyLength: result.avgRallyLength,
                playerAces: result.playerAces,
                playerWinners: result.playerWinners,
                playerErrors: result.playerErrors,
                opponentAces: result.npcAces,
                opponentWinners: result.npcWinners,
                opponentErrors: result.npcErrors,
                matchDurationSeconds: 0
            ))
        }

        let n = Double(matchCount)
        let row = HeadlessResultRow(
            dupr: dupr,
            matchCount: matchCount,
            winRate: Double(wins) / n,
            avgPointDiff: totalPointDiff / n,
            avgRallyLength: totalRally / n,
            avgPlayerErrors: totalPlayerErrors / n,
            avgOpponentErrors: totalOpponentErrors / n
        )
        return (row, entries)
    }

    // MARK: - Comparison

    private func buildComparison() {
        let grouped = Dictionary(grouping: loggedEntries) { entry in
            // Round to nearest 0.5 for grouping
            (entry.opponentDUPR * 2).rounded() / 2
        }

        comparisonRows = grouped.keys.sorted().map { dupr in
            let entries = grouped[dupr]!
            let real = entries.filter { $0.source == .interactive }
            let headless = entries.filter { $0.source == .headless }

            return ComparisonRow(
                dupr: dupr,
                realCount: real.count,
                headlessCount: headless.count,
                realWinRate: real.isEmpty ? nil : Double(real.filter(\.didPlayerWin).count) / Double(real.count),
                headlessWinRate: headless.isEmpty ? nil : Double(headless.filter(\.didPlayerWin).count) / Double(headless.count),
                realAvgPointDiff: real.isEmpty ? nil : real.map { Double($0.playerScore - $0.opponentScore) }.reduce(0, +) / Double(real.count),
                headlessAvgPointDiff: headless.isEmpty ? nil : headless.map { Double($0.playerScore - $0.opponentScore) }.reduce(0, +) / Double(headless.count),
                realAvgRallyLength: real.isEmpty ? nil : real.map(\.avgRallyLength).reduce(0, +) / Double(real.count),
                headlessAvgRallyLength: headless.isEmpty ? nil : headless.map(\.avgRallyLength).reduce(0, +) / Double(headless.count),
                realAvgErrors: real.isEmpty ? nil : real.map { Double($0.playerErrors) }.reduce(0, +) / Double(real.count),
                headlessAvgErrors: headless.isEmpty ? nil : headless.map { Double($0.playerErrors) }.reduce(0, +) / Double(headless.count)
            )
        }
    }

    // MARK: - Maintenance

    func clearLog() async {
        await DevMatchLogStore.shared.clearAll()
        loggedEntries = []
        comparisonRows = []
    }

    func exportLogAsText() -> String {
        var lines: [String] = ["Dev Match Log Export — \(Date().formatted())"]
        lines.append("Total entries: \(loggedEntries.count)")
        lines.append("")

        for row in comparisonRows {
            lines.append("DUPR \(String(format: "%.1f", row.dupr))")
            if let wr = row.realWinRate {
                lines.append("  Real (\(row.realCount)): WR=\(pct(wr)) PtDiff=\(fmt(row.realAvgPointDiff)) Rally=\(fmt(row.realAvgRallyLength)) Err=\(fmt(row.realAvgErrors))")
            }
            if let wr = row.headlessWinRate {
                lines.append("  Headless (\(row.headlessCount)): WR=\(pct(wr)) PtDiff=\(fmt(row.headlessAvgPointDiff)) Rally=\(fmt(row.headlessAvgRallyLength)) Err=\(fmt(row.headlessAvgErrors))")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func pct(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.1f%%", v * 100)
    }

    private func fmt(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%+.1f", v)
    }
}
