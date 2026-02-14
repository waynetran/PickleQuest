import SwiftUI

struct EquipmentSlotsView: View {
    let player: Player
    let equippedItemFor: (EquipmentSlot) -> Equipment?
    let onSlotTap: (EquipmentSlot) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(EquipmentSlot.allCases, id: \.self) { slot in
                    slotView(slot)
                        .onTapGesture { onSlotTap(slot) }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func slotView(_ slot: EquipmentSlot) -> some View {
        let item = equippedItemFor(slot)
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(item != nil ? item!.rarity.color.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 56, height: 56)

                if let item {
                    Text(slot.icon)
                        .font(.title2)
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(item.rarity.color, lineWidth: 2)
                        .frame(width: 56, height: 56)
                } else {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            Text(slot.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
