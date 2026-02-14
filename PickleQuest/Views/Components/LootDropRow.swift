import SwiftUI

struct LootDropRow: View {
    let equipment: Equipment

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

            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.green)
        }
        .padding(.vertical, 4)
    }

    private var bonusSummary: String {
        equipment.statBonuses.map { "+\($0.value) \($0.stat.displayName)" }.joined(separator: ", ")
    }
}
