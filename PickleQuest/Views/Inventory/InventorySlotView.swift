import SwiftUI

struct InventorySlotView: View {
    let item: Equipment?
    let isEquipped: Bool
    var cellSize: CGFloat = 80
    let onTap: () -> Void
    let onDragStart: (Equipment, CGPoint) -> Void

    @State private var isDragging = false

    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color(white: 0.12))

            if let item {
                // Item icon — fills box with 3px padding
                Text(item.slot.icon)
                    .font(.system(size: cellSize * 0.52))
                    .padding(3)

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
                        .font(.system(size: min(cellSize * 0.14, 12)))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(3)
                }

                // Level badge
                if item.level > 1 {
                    Text("L\(item.level)")
                        .font(.system(size: max(7, cellSize * 0.08), design: .monospaced))
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
        .frame(width: cellSize, height: cellSize)
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
