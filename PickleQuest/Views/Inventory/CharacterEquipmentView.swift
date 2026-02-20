import SwiftUI

struct CharacterEquipmentView: View {
    @Bindable var vm: InventoryViewModel
    let player: Player

    @State private var animationTimer: Timer?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let inset: CGFloat = 16
            let slotGap: CGFloat = 4

            // Slot sizing — a bit bigger, max 56pt
            let maxSlotFromHeight = (height - inset * 2 - slotGap * 5) / 6
            let slotSize = min(maxSlotFromHeight, 56)

            // Sprite is 2x the section height
            let spriteSize = height * 2.0

            // Left column X — moved in from edge
            let leftX = inset + slotSize / 2

            // All 6 slots stacked on left, vertically centered
            let totalSlotHeight = slotSize * 6 + slotGap * 5
            let slotTopY = (height - totalSlotHeight) / 2 + slotSize / 2

            // Stats column on right side
            let statsX = width - inset
            let effectiveStats = vm.effectiveStats(for: player)
            let baseStats = player.stats

            ZStack {
                // Background layer: animated character sprite
                AnimatedSpriteView(
                    appearance: player.appearance,
                    size: spriteSize,
                    animationState: vm.animationState
                )
                .position(x: width * 0.45, y: height * 0.5)

                // Left column: all 6 equipment slots
                let slots: [EquipmentSlot] = [.paddle, .shirt, .bottoms, .headwear, .shoes, .wristband]
                ForEach(Array(slots.enumerated()), id: \.element) { i, slot in
                    slotView(for: slot, size: slotSize)
                        .position(x: leftX, y: slotTopY + CGFloat(i) * (slotSize + slotGap))
                }

                // Right column: player stats with equipment bonuses
                VStack(alignment: .trailing, spacing: 1) {
                    ForEach(StatType.allCases, id: \.self) { stat in
                        let base = baseStats.stat(stat)
                        let effective = effectiveStats.stat(stat)
                        let bonus = effective - base

                        HStack(spacing: 2) {
                            Text(stat.displayName.prefix(3).uppercased())
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color(white: 0.5))
                                .frame(width: 28, alignment: .leading)

                            Text("\(base)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)

                            if bonus != 0 {
                                Text(bonus > 0 ? "+\(bonus)" : "\(bonus)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(bonus > 0 ? .green : .red)
                            }
                        }
                    }
                }
                .padding(6)
                .background(Color.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .position(x: statsX - 50, y: height / 2)
            }
            .clipped()
        }
        .onAppear { startAnimationTimer() }
        .onDisappear { stopAnimationTimer() }
    }

    @ViewBuilder
    private func slotView(for slot: EquipmentSlot, size: CGFloat) -> some View {
        let equipped = vm.equippedItem(for: slot, player: player)

        EquipSlotView(
            slot: slot,
            equippedItem: equipped,
            slotSize: size,
            onTap: {
                if let item = equipped {
                    vm.selectItem(item, player: player)
                }
            }
        )
    }

    private func startAnimationTimer() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                vm.cycleAnimation()
            }
        }
    }

    private func stopAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}
