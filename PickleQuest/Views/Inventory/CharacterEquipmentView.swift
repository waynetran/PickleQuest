import SwiftUI

struct CharacterEquipmentView: View {
    @Bindable var vm: InventoryViewModel
    let player: Player

    @State private var animationTimer: Timer?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let padding: CGFloat = 8
            let slotGap: CGFloat = 4

            // Left column has 4 slots stacked, right has 2 — size from the tighter constraint
            let maxSlotFromHeight = (height - padding * 2 - slotGap * 3) / 4
            let maxSlotFromWidth = (width - padding * 2) / 4
            let slotSize = min(maxSlotFromHeight, maxSlotFromWidth, 52)

            // Sprite fills the full height of the section
            let spriteSize = height

            let leftX = padding + slotSize / 2
            let rightX = width - padding - slotSize / 2

            // Vertically center the 4-slot left column
            let totalLeftHeight = slotSize * 4 + slotGap * 3
            let leftTopY = (height - totalLeftHeight) / 2 + slotSize / 2

            // Vertically center the 2-slot right column
            let totalRightHeight = slotSize * 2 + slotGap
            let rightTopY = (height - totalRightHeight) / 2 + slotSize / 2

            ZStack {
                // Background layer: animated character sprite fills the section
                AnimatedSpriteView(
                    appearance: player.appearance,
                    size: spriteSize,
                    animationState: vm.animationState
                )
                .position(x: width / 2, y: height / 2)

                // Left column: Shirt, Bottoms, Headwear, Shoes
                slotView(for: .shirt, size: slotSize)
                    .position(x: leftX, y: leftTopY)

                slotView(for: .bottoms, size: slotSize)
                    .position(x: leftX, y: leftTopY + slotSize + slotGap)

                slotView(for: .headwear, size: slotSize)
                    .position(x: leftX, y: leftTopY + (slotSize + slotGap) * 2)

                slotView(for: .shoes, size: slotSize)
                    .position(x: leftX, y: leftTopY + (slotSize + slotGap) * 3)

                // Right column: Paddle, Wristband
                slotView(for: .paddle, size: slotSize)
                    .position(x: rightX, y: rightTopY)

                slotView(for: .wristband, size: slotSize)
                    .position(x: rightX, y: rightTopY + slotSize + slotGap)
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
            isHighlighted: false,
            isDimmed: false,
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
