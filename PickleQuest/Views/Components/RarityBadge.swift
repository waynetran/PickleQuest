import SwiftUI

struct RarityBadge: View {
    let rarity: EquipmentRarity

    var body: some View {
        Text(rarity.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(rarity.color.opacity(0.2))
            .foregroundStyle(rarity.color)
            .clipShape(Capsule())
    }
}
