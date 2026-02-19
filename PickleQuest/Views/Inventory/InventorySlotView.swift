import SwiftUI

struct InventorySlotView: View {
    let item: Equipment?
    let isEquipped: Bool
    let onTap: () -> Void
    let onDragStart: (Equipment, CGPoint) -> Void

    @State private var isDragging = false

    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color(white: 0.12))

            if let item {
                // Item icon
                Text(item.slot.icon)
                    .font(.title2)

                // Rarity indicator — left border stripe
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(item.rarity.color)
                        .frame(width: 3)
                    Spacer()
                }

                // Equipped checkmark
                if isEquipped {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(3)
                }

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
            }

            // Border
            Rectangle()
                .strokeBorder(
                    item != nil ? Color(white: 0.3) : Color(white: 0.18),
                    lineWidth: 2
                )
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(isDragging ? 0.3 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.2)
                .sequenced(before: DragGesture(coordinateSpace: .named("inventory")))
                .onChanged { value in
                    switch value {
                    case .second(true, let drag):
                        if let drag, let item {
                            if !isDragging {
                                isDragging = true
                                onDragStart(item, drag.location)
                            }
                        }
                    default:
                        break
                    }
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
}
