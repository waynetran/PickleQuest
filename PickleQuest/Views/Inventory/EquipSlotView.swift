import SwiftUI

struct EquipSlotView: View {
    let slot: EquipmentSlot
    let equippedItem: Equipment?
    var slotSize: CGFloat = 50
    let onTap: () -> Void

    private let amberColor = Color(red: 0.9, green: 0.7, blue: 0.3)

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let item = equippedItem {
                    // Background — rarity color
                    Rectangle()
                        .fill(item.rarity.color.opacity(0.9))

                    Text(slot.icon)
                        .font(.system(size: slotSize * 0.7))

                    // Level badge
                    if item.level > 1 {
                        Text("L\(item.level)")
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 2)
                            .background(Color.black.opacity(0.7))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(2)
                    }
                } else {
                    // Empty: dark background, light grey icon
                    Rectangle()
                        .fill(Color(white: 0.12).opacity(0.9))

                    Text(slot.icon)
                        .font(.system(size: slotSize * 0.6))
                        .foregroundStyle(Color(white: 0.6))
                }

                // Amber outline for all slots
                Rectangle()
                    .strokeBorder(amberColor, lineWidth: 2)
            }
            .frame(width: slotSize, height: slotSize)
        }
        .buttonStyle(.plain)
    }
}
