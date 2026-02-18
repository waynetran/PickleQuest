import SwiftUI
import Charts

struct PerformanceView: View {
    @Environment(AppState.self) private var appState

    private var player: Player { appState.player }

    private var wins: Int {
        player.matchHistory.filter(\.didWin).count
    }

    private var losses: Int {
        player.matchHistory.filter { !$0.didWin }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // SUPR + Rep cards
                    HStack(spacing: 16) {
                        statCard(
                            title: "SUPR Score",
                            value: player.duprProfile.hasRating
                                ? String(format: "%.2f", player.duprRating)
                                : "NR",
                            subtitle: monthlyDeltaText,
                            color: .green
                        )

                        statCard(
                            title: "Reputation",
                            value: "\(player.repProfile.reputation)",
                            subtitle: player.repProfile.title,
                            color: .purple
                        )
                    }

                    // Quick Stats Row
                    HStack(spacing: 12) {
                        quickStat(
                            label: "Win Rate",
                            value: player.matchHistory.isEmpty ? "—" : "\(Int(player.overallWinRate * 100))%",
                            color: .green
                        )
                        quickStat(
                            label: "Streak",
                            value: "\(player.currentWinStreak)",
                            color: player.currentWinStreak > 0 ? .orange : .secondary
                        )
                        quickStat(
                            label: "Best Streak",
                            value: "\(player.bestWinStreak)",
                            color: .yellow
                        )
                        quickStat(
                            label: "Record",
                            value: "\(wins)-\(losses)",
                            color: .blue
                        )
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // DUPR History Chart
                    if player.duprProfile.ratingHistory.count >= 2 {
                        suprChartSection
                    }

                    // Energy
                    energySection

                    // Lifetime Stats
                    if !player.matchHistory.isEmpty {
                        lifetimeStatsSection
                    }

                    // Match History
                    matchHistorySection
                }
                .padding()
            }
            .navigationTitle("Performance")
        }
    }

    // MARK: - SUPR Chart

    private var suprChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUPR History")
                .font(.headline)

            Chart(player.duprProfile.ratingHistory.indices, id: \.self) { index in
                let snapshot = player.duprProfile.ratingHistory[index]
                LineMark(
                    x: .value("Match", index),
                    y: .value("SUPR", snapshot.rating)
                )
                .foregroundStyle(.green)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Match", index),
                    y: .value("SUPR", snapshot.rating)
                )
                .foregroundStyle(.green)
                .symbolSize(20)
            }
            .chartYScale(domain: suprChartRange)
            .chartXAxis(.hidden)
            .frame(height: 150)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var suprChartRange: ClosedRange<Double> {
        let ratings = player.duprProfile.ratingHistory.map(\.rating)
        let minR = (ratings.min() ?? 2.0) - 0.2
        let maxR = (ratings.max() ?? 3.0) + 0.2
        return minR...maxR
    }

    // MARK: - Energy

    private var energySection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(energyColor)
                Text("Energy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(player.currentEnergy))%")
                    .font(.headline.bold().monospacedDigit())
                    .foregroundStyle(energyColor)
            }

            ProgressView(value: player.currentEnergy, total: GameConstants.PersistentEnergy.maxEnergy)
                .tint(energyColor)

            if player.currentEnergy < GameConstants.PersistentEnergy.maxEnergy {
                let minutesLeft = (GameConstants.PersistentEnergy.maxEnergy - player.currentEnergy) / GameConstants.PersistentEnergy.recoveryPerMinute
                Text("Full in \(Int(minutesLeft))m")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Lifetime Stats

    private var lifetimeStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lifetime Stats")
                .font(.headline)

            let totalAces = player.matchHistory.reduce(0) { $0 + $1.aces }
            let totalWinners = player.matchHistory.reduce(0) { $0 + $1.winners }
            let totalErrors = player.matchHistory.reduce(0) { $0 + $1.unforcedErrors }
            let bestRally = player.matchHistory.map(\.longestRally).max() ?? 0

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                lifetimeStat(label: "Aces", value: "\(totalAces)", icon: "flame.fill", color: .orange)
                lifetimeStat(label: "Winners", value: "\(totalWinners)", icon: "star.fill", color: .yellow)
                lifetimeStat(label: "Errors", value: "\(totalErrors)", icon: "xmark.circle", color: .red)
                lifetimeStat(label: "Best Rally", value: "\(bestRally)", icon: "arrow.triangle.2.circlepath", color: .blue)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func lifetimeStat(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Match History

    private var matchHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Match History")
                .font(.headline)

            if player.matchHistory.isEmpty {
                Text("No matches played yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(player.matchHistory.reversed()) { entry in
                        MatchHistoryRow(entry: entry)
                        if entry.id != player.matchHistory.first?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func statCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func quickStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var monthlyDeltaText: String {
        let delta = player.monthlyDUPRDelta
        if delta == 0 { return "No change this month" }
        return String(format: "%@%.2f this month", delta > 0 ? "+" : "", delta)
    }

    private var energyColor: Color {
        let energy = player.currentEnergy
        if energy >= 80 { return .green }
        if energy >= 50 { return .yellow }
        return .red
    }
}
