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

                Text(guardianFlavorText)
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

    private var guardianFlavorText: String {
        switch drop.guardianDifficulty {
        case .advanced:
            return "A self-proclaimed 'kitchen commander' guards this cache. They won't give it up without a fight!"
        case .expert:
            return "This guardian has been banging drives all day. Think you can handle the heat?"
        case .master:
            return "The legendary Erne Master awaits. This one's got spin that'll make your paddle cry."
        default:
            return "A guardian NPC protects this gear cache. Defeat them to claim the loot!"
        }
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
        AppTheme.difficultyColor(difficulty)
    }
}
