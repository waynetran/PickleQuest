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

            if equipment.isWearable {
                VStack(spacing: 2) {
                    HStack {
                        Text("Condition")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(equipment.conditionPercent)%")
                            .font(.caption2.bold().monospacedDigit())
                            .foregroundStyle(conditionColor)
                    }
                    ProgressView(value: equipment.condition)
                        .tint(conditionColor)
                }
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

    private var conditionColor: Color {
        if equipment.condition >= 0.7 { return .green }
        if equipment.condition >= 0.3 { return .yellow }
        return .red
    }
}
