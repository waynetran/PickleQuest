import SwiftUI

struct EquipmentSlotsView: View {
    let player: Player
    let selectedFilter: EquipmentSlot?
    let equippedItemFor: (EquipmentSlot) -> Equipment?
    let onSlotTap: (EquipmentSlot) -> Void
    let onShowAll: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "All" button
                VStack(spacing: 4) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedFilter == nil ? Color.green.opacity(0.2) : Color(.systemGray5))
                            .frame(width: 56, height: 56)

                        Image(systemName: "square.grid.2x2")
                            .font(.title3)
                            .foregroundStyle(selectedFilter == nil ? .green : .secondary)

                        if selectedFilter == nil {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.green, lineWidth: 2)
                                .frame(width: 56, height: 56)
                        }
                    }

                    Text("All")
                        .font(.caption2)
                        .foregroundStyle(selectedFilter == nil ? .green : .secondary)
                }
                .onTapGesture { onShowAll() }

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
        let isSelected = selectedFilter == slot
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(item != nil ? item!.rarity.color.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 56, height: 56)

                if let item {
                    Text(slot.icon)
                        .font(.title2)
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected ? .green : item.rarity.color, lineWidth: isSelected ? 3 : 2)
                        .frame(width: 56, height: 56)
                } else {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.green, lineWidth: 3)
                            .frame(width: 56, height: 56)
                    }
                }
            }

            Text(slot.displayName)
                .font(.caption2)
                .foregroundStyle(isSelected ? .green : .secondary)
        }
    }
}
