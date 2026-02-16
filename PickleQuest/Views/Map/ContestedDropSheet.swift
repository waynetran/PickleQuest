import SwiftUI

struct ContestedDropSheet: View {
    let drop: GearDrop
    let onChallenge: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Beacon icon
                ZStack {
                    Circle()
                        .fill(.orange.opacity(0.2))
                        .frame(width: 80, height: 80)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                }

                Text("Contested Drop!")
                    .font(.title2.bold())

                Text("A guardian NPC protects this gear cache. Defeat them to claim the loot!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Details
                VStack(spacing: 12) {
                    detailRow(label: "Rarity", value: drop.rarity.displayName, color: drop.rarity.color)

                    if let difficulty = drop.guardianDifficulty {
                        detailRow(
                            label: "Guardian",
                            value: difficulty.displayName,
                            color: difficultyColor(difficulty)
                        )
                    }

                    detailRow(label: "Reward", value: "3 items (guaranteed \(drop.rarity.displayName)+)", color: .secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()

                // Actions
                VStack(spacing: 10) {
                    Button(action: onChallenge) {
                        Label("Challenge Guardian", systemImage: "figure.pickleball")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button("Walk Away", action: onCancel)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.top, 24)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private func detailRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
    }

    private func difficultyColor(_ difficulty: NPCDifficulty) -> Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .purple
        case .expert: return .orange
        case .master: return .red
        }
    }
}
