import SwiftUI

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
                    // SUPR + Monthly Delta
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

                    // Energy + W-L Record
                    HStack(spacing: 16) {
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

                        VStack(spacing: 8) {
                            Text("Record")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 4) {
                                Text("\(wins)")
                                    .font(.title2.bold().monospacedDigit())
                                    .foregroundStyle(.green)
                                Text("-")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text("\(losses)")
                                    .font(.title2.bold().monospacedDigit())
                                    .foregroundStyle(.red)
                            }

                            Text("W - L")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Match History
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
                .padding()
            }
            .navigationTitle("Performance")
        }
    }

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
