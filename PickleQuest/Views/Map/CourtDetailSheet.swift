import SwiftUI

struct CourtDetailSheet: View {
    let court: Court
    let npcs: [NPC]
    let playerRating: Double
    @Binding var isRated: Bool
    let onChallenge: (NPC) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Court header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(difficultyColor.opacity(0.2))
                                .frame(width: 64, height: 64)
                            Image(systemName: "sportscourt.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(difficultyColor)
                        }

                        Text(court.name)
                            .font(.title2.bold())

                        Text(court.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 8) {
                            ForEach(court.difficultyTiers.sorted(), id: \.self) { tier in
                                DifficultyBadge(difficulty: tier)
                            }
                            Label("\(court.courtCount) courts", systemImage: "rectangle.split.2x1")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top)

                    Divider()

                    // Rated toggle
                    Toggle(isOn: $isRated) {
                        HStack(spacing: 6) {
                            Image(systemName: isRated ? "chart.line.uptrend.xyaxis" : "minus.circle")
                                .foregroundStyle(isRated ? .green : .secondary)
                            Text(isRated ? "Rated Match" : "Unrated Match")
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)

                    // NPC list
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Opponents")
                            .font(.headline)
                            .padding(.horizontal)

                        if npcs.isEmpty {
                            Text("No opponents at this court right now.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                        } else {
                            ForEach(npcs) { npc in
                                courtNPCCard(npc)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Court Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func courtNPCCard(_ npc: NPC) -> some View {
        let autoUnrated = DUPRCalculator.shouldAutoUnrate(
            playerRating: playerRating,
            opponentRating: npc.duprRating
        )

        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Portrait
                ZStack {
                    Circle()
                        .fill(npcDifficultyColor(npc).opacity(0.2))
                        .frame(width: 48, height: 48)
                    Text(String(npc.name.prefix(1)))
                        .font(.title3.bold())
                        .foregroundStyle(npcDifficultyColor(npc))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(npc.name)
                        .font(.subheadline.bold())
                    Text(npc.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        DifficultyBadge(difficulty: npc.difficulty)
                        Text("SUPR \(String(format: "%.2f", npc.duprRating))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    dismiss()
                    onChallenge(npc)
                } label: {
                    Text("Challenge")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(12)

            if isRated && autoUnrated {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("Rating gap > \(String(format: "%.1f", GameConstants.DUPRRating.maxRatedGap)) — auto-unrated")
                        .font(.caption2)
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var difficultyColor: Color {
        npcDifficultyColor(for: court.primaryDifficulty)
    }

    private func npcDifficultyColor(_ npc: NPC) -> Color {
        npcDifficultyColor(for: npc.difficulty)
    }

    private func npcDifficultyColor(for difficulty: NPCDifficulty) -> Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .purple
        case .expert: return .orange
        case .master: return .red
        }
    }
}
