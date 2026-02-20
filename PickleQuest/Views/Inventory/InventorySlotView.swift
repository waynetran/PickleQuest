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
            // Background — rarity tinted or empty dark
            if let item, item.rarity != .common {
                Rectangle()
                    .fill(item.rarity.color.opacity(0.18))
            } else {
                Rectangle()
                    .fill(Color(white: 0.12))
            }

            if let item {
                VStack(spacing: 0) {
                    // Icon row
                    Text(item.slot.icon)
                        .font(.system(size: cellSize * 0.32))

                    // Item name (truncated)
                    Text(item.displayTitle)
                        .font(.system(size: max(6, cellSize * 0.1), weight: .semibold, design: .rounded))
                        .foregroundStyle(item.rarity == .common ? .white.opacity(0.7) : item.rarity.color)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)

                    // Stat summary
                    statSummary(for: item)
                }
                .padding(3)

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
                        .font(.system(size: max(6, cellSize * 0.09), design: .monospaced))
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

    @ViewBuilder
    private func statSummary(for item: Equipment) -> some View {
        let allBonuses = (item.baseStat.map { [$0] } ?? []) + item.statBonuses
        let fontSize = max(5, cellSize * 0.08)

        if !allBonuses.isEmpty {
            HStack(spacing: 2) {
                ForEach(Array(allBonuses.prefix(3).enumerated()), id: \.offset) { _, bonus in
                    Text("+\(bonus.value) \(bonus.stat.displayName.prefix(3))")
                        .font(.system(size: fontSize, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
    }
}
