import SwiftUI

struct InventorySlotView: View {
    let item: Equipment?
    let isEquipped: Bool
    var cellSize: CGFloat = 80
    let statDeltas: [StatDelta]
    let onTap: () -> Void

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
                // Icon fills the box
                Text(item.slot.icon)
                    .font(.system(size: cellSize * 0.55))

                // Equipment stats — top-right, left-aligned text
                let allBonuses = (item.baseStat.map { [$0] } ?? []) + item.statBonuses
                if !allBonuses.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(allBonuses.prefix(3).enumerated()), id: \.offset) { _, bonus in
                            let delta = statDeltas.first { $0.stat == bonus.stat }
                            let color: Color = {
                                guard let d = delta else { return .white.opacity(0.7) }
                                return d.value > 0 ? .green : (d.value < 0 ? .red : .white.opacity(0.7))
                            }()
                            Text("+\(bonus.value)\(bonus.stat.displayName.prefix(3))")
                                .font(.system(size: max(6, cellSize * 0.09), weight: .medium, design: .monospaced))
                                .foregroundStyle(color)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(3)
                }

                // Rarity pill — bottom left, smaller
                if item.rarity != .common {
                    Text(item.rarity.displayName.uppercased())
                        .font(.system(size: max(4, cellSize * 0.06), weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(item.rarity.color.opacity(0.85))
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.horizontal, 3)
                        .padding(.bottom, 6)
                }

                // Equipped checkmark — top right
                if isEquipped {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: min(cellSize * 0.14, 12)))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(3)
                }

                // Level badge — bottom right
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
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
