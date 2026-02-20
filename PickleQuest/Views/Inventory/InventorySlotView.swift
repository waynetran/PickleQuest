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
                VStack(spacing: 1) {
                    // Title at the top
                    Text(item.displayTitle)
                        .font(.system(size: max(6, cellSize * 0.09), weight: .semibold, design: .rounded))
                        .foregroundStyle(item.rarity == .common ? .white.opacity(0.7) : item.rarity.color)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)

                    // Icon left, stats right
                    HStack(spacing: 2) {
                        // Icon
                        Text(item.slot.icon)
                            .font(.system(size: cellSize * 0.3))

                        // Stats column — green/red based on equip delta
                        VStack(alignment: .leading, spacing: 0) {
                            let allBonuses = (item.baseStat.map { [$0] } ?? []) + item.statBonuses
                            ForEach(Array(allBonuses.prefix(3).enumerated()), id: \.offset) { _, bonus in
                                let delta = statDeltas.first { $0.stat == bonus.stat }
                                let color: Color = {
                                    guard let d = delta else { return .white.opacity(0.5) }
                                    return d.value > 0 ? .green : (d.value < 0 ? .red : .white.opacity(0.5))
                                }()
                                Text("+\(bonus.value) \(bonus.stat.displayName.prefix(3))")
                                    .font(.system(size: max(5, cellSize * 0.08), design: .monospaced))
                                    .foregroundStyle(color)
                            }
                        }

                        Spacer(minLength: 0)
                    }
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
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
