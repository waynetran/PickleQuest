import SwiftUI

struct CharacterEquipmentView: View {
    @Bindable var vm: InventoryViewModel
    let player: Player

    @State private var animationTimer: Timer?

    private let spriteSize: CGFloat = 96

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let centerX = width / 2
            let centerY: CGFloat = 90

            ZStack {
                // Animated character sprite (center)
                AnimatedSpriteView(
                    appearance: player.appearance,
                    size: spriteSize,
                    animationState: vm.animationState
                )
                .position(x: centerX, y: centerY)

                // Headwear — top center, above sprite
                slotView(for: .headwear)
                    .position(x: centerX, y: centerY - spriteSize / 2 - 32)
                    .overlaySlotFrame(.headwear)

                // Shirt — left of sprite, upper body
                slotView(for: .shirt)
                    .position(x: centerX - spriteSize / 2 - 40, y: centerY - 14)
                    .overlaySlotFrame(.shirt)

                // Bottoms — left of sprite, lower body
                slotView(for: .bottoms)
                    .position(x: centerX - spriteSize / 2 - 40, y: centerY + 40)
                    .overlaySlotFrame(.bottoms)

                // Paddle — right of sprite, upper body
                slotView(for: .paddle)
                    .position(x: centerX + spriteSize / 2 + 40, y: centerY - 14)
                    .overlaySlotFrame(.paddle)

                // Wristband — right of sprite, lower body
                slotView(for: .wristband)
                    .position(x: centerX + spriteSize / 2 + 40, y: centerY + 40)
                    .overlaySlotFrame(.wristband)

                // Shoes — bottom center, below sprite
                slotView(for: .shoes)
                    .position(x: centerX, y: centerY + spriteSize / 2 + 32)
                    .overlaySlotFrame(.shoes)
            }
        }
        .frame(height: 210)
        .onAppear { startAnimationTimer() }
        .onDisappear { stopAnimationTimer() }
    }

    @ViewBuilder
    private func slotView(for slot: EquipmentSlot) -> some View {
        let equipped = vm.equippedItem(for: slot, player: player)
        let isDragging = vm.dragState != nil
        let isCompatible = vm.dragState?.item.slot == slot

        EquipSlotView(
            slot: slot,
            equippedItem: equipped,
            isHighlighted: isDragging && isCompatible,
            isDimmed: isDragging && !isCompatible,
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
