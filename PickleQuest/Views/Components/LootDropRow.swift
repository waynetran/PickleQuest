import SwiftUI

struct LootDropRow: View {
    let equipment: Equipment
    @Binding var decision: MatchViewModel.LootDecision?

    var body: some View {
        HStack(spacing: 12) {
            Text(equipment.slot.icon)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(equipment.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(equipment.rarity.color)

                HStack(spacing: 4) {
                    RarityBadge(rarity: equipment.rarity)

                    Text(bonusSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let decision {
                // Show chosen action with change option
                HStack(spacing: 6) {
                    Image(systemName: decision == .equip ? "checkmark.shield.fill" : "bag.fill")
                        .foregroundStyle(decision == .equip ? .green : .blue)
                    Text(decision == .equip ? "Equip" : "Keep")
                        .font(.caption.bold())
                        .foregroundStyle(decision == .equip ? .green : .blue)
                }
                .onTapGesture { self.decision = nil }
            } else {
                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        decision = .equip
                    } label: {
                        Label("Equip", systemImage: "shield.fill")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    Button {
                        decision = .keep
                    } label: {
                        Label("Keep", systemImage: "bag.fill")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var bonusSummary: String {
        equipment.statBonuses.map { "+\($0.value) \($0.stat.displayName)" }.joined(separator: ", ")
    }
}
