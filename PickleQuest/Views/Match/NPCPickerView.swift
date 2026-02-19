import SwiftUI

struct NPCPickerView: View {
    let viewModel: MatchViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Choose Your Opponent")
                    .font(.title2.bold())
                    .padding(.top)

                // Rated/Unrated toggle
                Toggle(isOn: Bindable(viewModel).isRated) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isRated ? "chart.line.uptrend.xyaxis" : "minus.circle")
                            .foregroundStyle(viewModel.isRated ? .green : .secondary)
                        Text(viewModel.isRated ? "Rated Match" : "Unrated Match")
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)

                ForEach(viewModel.availableNPCs) { npc in
                    let autoUnrated = viewModel.isAutoUnrated(
                        playerRating: appState.player.duprRating,
                        opponentRating: npc.duprRating
                    )
                    NPCCard(
                        npc: npc,
                        playerRating: appState.player.duprRating,
                        isRated: viewModel.isRated,
                        isAutoUnrated: autoUnrated
                    ) {
                        Task {
                            await viewModel.startMatch(player: appState.player, opponent: npc)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct NPCCard: View {
    let npc: NPC
    let playerRating: Double
    let isRated: Bool
    let isAutoUnrated: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Portrait placeholder
                    ZStack {
                        Circle()
                            .fill(difficultyColor.opacity(0.2))
                            .frame(width: 56, height: 56)
                        Text(String(npc.name.prefix(1)))
                            .font(.title2.bold())
                            .foregroundStyle(difficultyColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(npc.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(npc.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            DifficultyBadge(difficulty: npc.difficulty)
                            Text("SUPR \(String(format: "%.2f", npc.duprRating))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !npc.skills.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(npc.skills.prefix(4), id: \.self) { skillID in
                                    if let def = SkillDefinition.definition(for: skillID) {
                                        Image(systemName: def.icon)
                                            .font(.caption2)
                                            .foregroundStyle(.purple.opacity(0.8))
                                    }
                                }
                                if npc.skills.count > 4 {
                                    Text("+\(npc.skills.count - 4)")
                                        .font(.caption2)
                                        .foregroundStyle(.purple.opacity(0.6))
                                }
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()

                // Auto-unrate warning
                if isRated && isAutoUnrated {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Rating gap > \(String(format: "%.1f", GameConstants.DUPRRating.maxRatedGap)) — auto-unrated")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var difficultyColor: Color {
        AppTheme.difficultyColor(npc.difficulty)
    }
}
