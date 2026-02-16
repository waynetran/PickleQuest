import SwiftUI

struct StoreItemCard: View {
    let item: StoreItem
    let canAfford: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.equipment.slot.icon)
                    .font(.title3)
                Spacer()
                if item.isSoldOut {
                    Text("Sold")
                        .font(.caption2.bold())
                        .foregroundStyle(.red)
                }
            }

            Text(item.equipment.name)
                .font(.caption.bold())
                .lineLimit(2)
                .foregroundStyle(item.isSoldOut ? .secondary : item.equipment.rarity.color)

            if let brandName = item.equipment.brandName {
                Text(brandName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            RarityBadge(rarity: item.equipment.rarity)

            if let setName = item.equipment.setName {
                Text(setName)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.purple.opacity(0.2))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 2) {
                ForEach(item.equipment.statBonuses, id: \.stat) { bonus in
                    Text("+\(bonus.value) \(bonus.stat.displayName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let ability = item.equipment.ability {
                Text(ability.name)
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }

            Spacer()

            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.yellow)
                Text("\(item.price)")
                    .font(.caption.bold())
                    .foregroundStyle(canAfford && !item.isSoldOut ? Color.primary : Color.red)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(item.isSoldOut ? 0.5 : 1.0)
    }
}
