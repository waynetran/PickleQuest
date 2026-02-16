import SwiftUI

struct LootDropRow: View {
    let equipment: Equipment
    @Binding var decision: LootDecision?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: icon + name + rarity
            HStack(alignment: .top, spacing: 10) {
                Text(equipment.slot.icon)
                    .font(.title2)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(equipment.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(equipment.rarity.color)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 4) {
                        RarityBadge(rarity: equipment.rarity)

                        Text(bonusSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // Bottom row: action buttons (full width)
            if let decision {
                HStack(spacing: 6) {
                    Spacer()
                    Image(systemName: decision == .equip ? "checkmark.shield.fill" : "bag.fill")
                        .foregroundStyle(decision == .equip ? .green : .blue)
                    Text(decision == .equip ? "Equipped" : "Keeping")
                        .font(.caption.bold())
                        .foregroundStyle(decision == .equip ? .green : .blue)
                    Spacer()
                }
                .onTapGesture { self.decision = nil }
            } else {
                HStack(spacing: 10) {
                    Button {
                        decision = .equip
                    } label: {
                        Label("Equip", systemImage: "shield.fill")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    Button {
                        decision = .keep
                    } label: {
                        Label("Keep", systemImage: "bag.fill")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var bonusSummary: String {
        equipment.statBonuses.map { "+\($0.value) \($0.stat.displayName)" }.joined(separator: ", ")
    }
}
