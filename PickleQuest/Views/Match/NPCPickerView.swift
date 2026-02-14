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

                ForEach(viewModel.availableNPCs) { npc in
                    NPCCard(npc: npc) {
                        viewModel.startMatch(player: appState.player, opponent: npc)
                    }
                }
            }
            .padding()
        }
    }
}

struct NPCCard: View {
    let npc: NPC
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
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
                        Text("DUPR \(String(format: "%.1f", npc.duprRating))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var difficultyColor: Color {
        switch npc.difficulty {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .purple
        case .expert: return .orange
        case .master: return .red
        }
    }
}
