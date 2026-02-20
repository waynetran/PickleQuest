import SwiftUI

struct CharacterEquipmentView: View {
    @Bindable var vm: InventoryViewModel
    let player: Player

    @State private var animationTimer: Timer?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let padding: CGFloat = 12
            let slotGap: CGFloat = 6

            // Slot size: fit 3 rows vertically (top slot, 2 side slots stacked, bottom slot)
            // and 4 columns horizontally (slot, gap, sprite, gap, slot)
            let maxSlotFromHeight = (height - slotGap * 4 - padding * 2) / 4.5
            let maxSlotFromWidth = (width - padding * 2 - slotGap * 2) / 5.5
            let slotSize = min(maxSlotFromHeight, maxSlotFromWidth, 56)

            // Sprite fills remaining center space
            let spriteW = width - padding * 2 - slotSize * 2 - slotGap * 2
            let spriteH = height - padding * 2 - slotSize * 2 - slotGap * 2
            let spriteSize = max(48, min(spriteW, spriteH))

            let centerX = width / 2
            let centerY = height / 2

            ZStack {
                // Animated character sprite (center)
                AnimatedSpriteView(
                    appearance: player.appearance,
                    size: spriteSize,
                    animationState: vm.animationState
                )
                .position(x: centerX, y: centerY)

                // Headwear — top center
                slotView(for: .headwear, size: slotSize)
                    .position(x: centerX, y: centerY - spriteSize / 2 - slotGap - slotSize / 2)
                    .overlaySlotFrame(.headwear)

                // Shirt — left of sprite, upper
                slotView(for: .shirt, size: slotSize)
                    .position(x: centerX - spriteSize / 2 - slotGap - slotSize / 2, y: centerY - slotSize / 2 - slotGap / 2)
                    .overlaySlotFrame(.shirt)

                // Bottoms — left of sprite, lower
                slotView(for: .bottoms, size: slotSize)
                    .position(x: centerX - spriteSize / 2 - slotGap - slotSize / 2, y: centerY + slotSize / 2 + slotGap / 2)
                    .overlaySlotFrame(.bottoms)

                // Paddle — right of sprite, upper
                slotView(for: .paddle, size: slotSize)
                    .position(x: centerX + spriteSize / 2 + slotGap + slotSize / 2, y: centerY - slotSize / 2 - slotGap / 2)
                    .overlaySlotFrame(.paddle)

                // Wristband — right of sprite, lower
                slotView(for: .wristband, size: slotSize)
                    .position(x: centerX + spriteSize / 2 + slotGap + slotSize / 2, y: centerY + slotSize / 2 + slotGap / 2)
                    .overlaySlotFrame(.wristband)

                // Shoes — bottom center
                slotView(for: .shoes, size: slotSize)
                    .position(x: centerX, y: centerY + spriteSize / 2 + slotGap + slotSize / 2)
                    .overlaySlotFrame(.shoes)
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
