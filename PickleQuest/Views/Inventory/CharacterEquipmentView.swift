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

            // Sprite fills the entire section as background
            let spriteSize = min(width, height) * 0.85

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
                    .overlaySlotFrame(.shirt)

                slotView(for: .bottoms, size: slotSize)
                    .position(x: leftX, y: leftTopY + slotSize + slotGap)
                    .overlaySlotFrame(.bottoms)

                slotView(for: .headwear, size: slotSize)
                    .position(x: leftX, y: leftTopY + (slotSize + slotGap) * 2)
                    .overlaySlotFrame(.headwear)

                slotView(for: .shoes, size: slotSize)
                    .position(x: leftX, y: leftTopY + (slotSize + slotGap) * 3)
                    .overlaySlotFrame(.shoes)

                // Right column: Paddle, Wristband
                slotView(for: .paddle, size: slotSize)
                    .position(x: rightX, y: rightTopY)
                    .overlaySlotFrame(.paddle)

                slotView(for: .wristband, size: slotSize)
                    .position(x: rightX, y: rightTopY + slotSize + slotGap)
                    .overlaySlotFrame(.wristband)
            }
        }
        .onAppear { startAnimationTimer() }
        .onDisappear { stopAnimationTimer() }
    }

    @ViewBuilder
    private func slotView(for slot: EquipmentSlot, size: CGFloat) -> some View {
        let equipped = vm.equippedItem(for: slot, player: player)
        let isDragging = vm.dragState != nil
        let isCompatible = vm.dragState?.item.slot == slot

        EquipSlotView(
            slot: slot,
            equippedItem: equipped,
            isHighlighted: isDragging && isCompatible,
            isDimmed: isDragging && !isCompatible,
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

// MARK: - Slot Frame Preference Key

struct SlotFramePreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [EquipmentSlot: CGRect] = [:]
    static func reduce(value: inout [EquipmentSlot: CGRect], nextValue: () -> [EquipmentSlot: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    func overlaySlotFrame(_ slot: EquipmentSlot) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: SlotFramePreferenceKey.self,
                    value: [slot: geo.frame(in: .named("inventory"))]
                )
            }
        )
    }
}
