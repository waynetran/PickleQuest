import SwiftUI

struct PartnerPickerView: View {
    let availableNPCs: [NPC]
    let playerPersonality: PlayerType
    let opponent1: NPC?
    let opponent2: NPC?
    let onSelect: (NPC) -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Opponent info
                if let opp1 = opponent1, let opp2 = opponent2 {
                    VStack(spacing: 8) {
                        Text("Opponents")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(.red)
                            Text("\(opp1.name) & \(opp2.name)")
                                .font(.subheadline.bold())
                        }
                        let avgDUPR = (opp1.duprRating + opp2.duprRating) / 2.0
                        Text("Avg SUPR \(String(format: "%.2f", avgDUPR))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text("Choose a partner for doubles")
                    .font(.headline)

                if availableNPCs.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.slash")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("No partners available at this court.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    // Sort by synergy (best first)
                    let sorted = availableNPCs.sorted { npc1, npc2 in
                        let syn1 = TeamSynergy.calculate(p1: playerPersonality, p2: npc1.playerType)
                        let syn2 = TeamSynergy.calculate(p1: playerPersonality, p2: npc2.playerType)
                        return syn1.multiplier > syn2.multiplier
                    }

                    ForEach(sorted) { npc in
                        partnerCard(npc: npc)
                    }
                }

                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }

    private func partnerCard(npc: NPC) -> some View {
        let synergy = TeamSynergy.calculate(p1: playerPersonality, p2: npc.playerType)

        return Button {
            onSelect(npc)
        } label: {
            HStack(spacing: 12) {
                // Portrait
                ZStack {
                    Circle()
                        .fill(difficultyColor(npc.difficulty).opacity(0.2))
                        .frame(width: 48, height: 48)
                    Text(String(npc.name.prefix(1)))
                        .font(.callout.bold())
                        .foregroundStyle(difficultyColor(npc.difficulty))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(npc.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(npc.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text("SUPR \(String(format: "%.2f", npc.duprRating))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(npc.playerType.rawValue.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Synergy badge
                VStack(spacing: 2) {
                    Text(synergy.description)
                        .font(.caption2.bold())
                        .foregroundStyle(synergyColor(synergy))
                    Text(String(format: "%.0f%%", (synergy.multiplier - 1.0) * 100))
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(synergyColor(synergy))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(synergyColor(synergy).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func synergyColor(_ synergy: TeamSynergy) -> Color {
        if synergy.multiplier >= 1.06 { return .green }
        if synergy.multiplier >= 1.03 { return .mint }
        if synergy.multiplier >= 0.97 { return .secondary }
        return .orange
    }

    private func difficultyColor(_ difficulty: NPCDifficulty) -> Color {
        AppTheme.difficultyColor(difficulty)
    }
}
