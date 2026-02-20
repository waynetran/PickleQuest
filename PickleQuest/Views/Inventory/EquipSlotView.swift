import SwiftUI

struct EquipSlotView: View {
    let slot: EquipmentSlot
    let equippedItem: Equipment?
    var slotSize: CGFloat = 50
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                Rectangle()
                    .fill(Color(white: 0.12))

                if let item = equippedItem {
                    // Filled slot — icon fills with 3px padding
                    Text(slot.icon)
                        .font(.system(size: slotSize * 0.52))
                        .padding(3)

                    // Rarity border
                    Rectangle()
                        .strokeBorder(item.rarity.color, lineWidth: 2)

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
                    // Empty slot
                    Text(slot.icon)
                        .font(.system(size: slotSize * 0.42))
                        .opacity(0.3)

                    Rectangle()
                        .strokeBorder(Color(white: 0.25), lineWidth: 2)
                }
            }
            .frame(width: slotSize, height: slotSize)
        }
        .buttonStyle(.plain)
    }
}
