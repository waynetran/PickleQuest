import SwiftUI

struct StatAllocationView: View {
    @Environment(AppState.self) private var appState
    let viewModel: PlayerProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Points remaining
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.orange)
                        Text("\(appState.player.progression.availableStatPoints) points available")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Stats
                    ForEach(StatCategory.allCases, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category.displayName)
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)

                            ForEach(category.stats, id: \.self) { stat in
                                statRow(stat)
                            }
                        }
                    }

                    // Effective stats note
                    if let effective = viewModel.effectiveStats {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Effective Stats (with equipment)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)

                            ForEach(StatType.allCases, id: \.self) { stat in
                                let base = appState.player.stats.stat(stat)
                                let eff = effective.stat(stat)
                                if eff != base {
                                    HStack {
                                        Text(stat.displayName)
                                            .font(.caption)
                                            .frame(width: 80, alignment: .leading)
                                        Text("\(base)")
                                            .font(.caption.monospacedDigit())
                                        Image(systemName: "arrow.right")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("\(eff)")
                                            .font(.caption.monospacedDigit().bold())
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Allocate Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func statRow(_ stat: StatType) -> some View {
        HStack(spacing: 8) {
            Text(stat.displayName)
                .font(.subheadline)
                .frame(width: 90, alignment: .leading)

            StatBar(
                name: "",
                value: appState.player.stats.stat(stat),
                maxValue: GameConstants.Stats.maxValue,
                color: statColor(for: stat.category)
            )

            Button {
                Task {
                    var player = appState.player
                    let success = await viewModel.allocateStatPoint(to: stat, player: &player)
                    if success {
                        appState.player = player
                    }
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        appState.player.progression.availableStatPoints > 0
                        && appState.player.stats.stat(stat) < GameConstants.Stats.maxValue
                        ? .green : .gray
                    )
            }
            .disabled(
                appState.player.progression.availableStatPoints == 0
                || appState.player.stats.stat(stat) >= GameConstants.Stats.maxValue
            )
        }
    }

    private func statColor(for category: StatCategory) -> Color {
        switch category {
        case .offensive: return .red
        case .defensive: return .blue
        case .mental: return .purple
        }
    }
}
