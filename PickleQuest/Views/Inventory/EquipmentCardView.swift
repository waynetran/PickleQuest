import SwiftUI

struct EquipmentCardView: View {
    let equipment: Equipment
    let isEquipped: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(equipment.slot.icon)
                    .font(.title3)
                Spacer()
                if isEquipped {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            Text(equipment.name)
                .font(.caption.bold())
                .lineLimit(2)
                .foregroundStyle(equipment.rarity.color)

            RarityBadge(rarity: equipment.rarity)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(equipment.statBonuses, id: \.stat) { bonus in
                    Text("+\(bonus.value) \(bonus.stat.displayName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let ability = equipment.ability {
                Text(ability.name)
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isEquipped ? Color.green.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }
}
