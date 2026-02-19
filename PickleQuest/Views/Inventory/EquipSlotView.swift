import SwiftUI

struct EquipSlotView: View {
    let slot: EquipmentSlot
    let equippedItem: Equipment?
    let isHighlighted: Bool
    let isDimmed: Bool
    let onTap: () -> Void

    private let slotSize: CGFloat = 50

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                Rectangle()
                    .fill(Color(white: 0.12))
                    .frame(width: slotSize, height: slotSize)

                if let item = equippedItem {
                    // Filled slot
                    Text(slot.icon)
                        .font(.title2)

                    // Rarity border
                    Rectangle()
                        .strokeBorder(item.rarity.color, lineWidth: 2)
                        .frame(width: slotSize, height: slotSize)

                    // Level badge
                    if item.level > 1 {
                        Text("L\(item.level)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 2)
                            .background(Color.black.opacity(0.7))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(2)
                    }
                } else {
                    // Empty slot
                    Text(slot.icon)
                        .font(.title3)
                        .opacity(0.3)

                    Rectangle()
                        .strokeBorder(Color(white: 0.25), lineWidth: 2)
                        .frame(width: slotSize, height: slotSize)
                }

                // Highlight glow for compatible drag target
                if isHighlighted {
                    Rectangle()
                        .strokeBorder(Color.green, lineWidth: 3)
                        .frame(width: slotSize, height: slotSize)
                        .shadow(color: .green.opacity(0.6), radius: 6)
                }
            }
            .frame(width: slotSize, height: slotSize)
            .opacity(isDimmed ? 0.3 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
