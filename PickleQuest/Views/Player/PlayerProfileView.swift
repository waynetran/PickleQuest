import SwiftUI

struct PlayerProfileView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(.green.opacity(0.2))
                                .frame(width: 80, height: 80)
                            Image(systemName: "person.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.green)
                        }

                        Text(appState.player.name)
                            .font(.title.bold())

                        HStack(spacing: 16) {
                            Label("Lv. \(appState.player.progression.level)", systemImage: "star.fill")
                                .font(.subheadline)
                            Label("DUPR \(String(format: "%.1f", appState.player.duprRating))", systemImage: "chart.bar.fill")
                                .font(.subheadline)
                            Label("\(appState.player.wallet.coins)", systemImage: "dollarsign.circle.fill")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }

                    // XP Progress
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Experience")
                                .font(.headline)
                            Spacer()
                            if appState.player.progression.availableStatPoints > 0 {
                                Text("\(appState.player.progression.availableStatPoints) stat points")
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                            }
                        }
                        ProgressView(value: appState.player.progression.xpProgress)
                            .tint(.blue)
                        Text("\(appState.player.progression.currentXP) / \(appState.player.progression.xpToNextLevel) XP")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Stats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Stats")
                            .font(.headline)

                        ForEach(StatCategory.allCases, id: \.self) { category in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(category.displayName)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)

                                ForEach(category.stats, id: \.self) { stat in
                                    StatBar(
                                        name: stat.displayName,
                                        value: appState.player.stats.stat(stat),
                                        maxValue: GameConstants.Stats.maxValue,
                                        color: statColor(for: category)
                                    )
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
            .navigationTitle("Profile")
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
