import SwiftUI

struct CharacterEquipmentView: View {
    @Bindable var vm: InventoryViewModel
    let player: Player

    @State private var animationTimer: Timer?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let inset: CGFloat = 12

            // Slot sizing — 2x original (~100pt), capped by available space
            let slotSize: CGFloat = min(100, (height - inset * 2) / 4)

            // Sprite + court: 35% smaller than previous 2.8x
            let spriteSize = height * 1.82

            // Left column: shirt, bottoms, shoes — vertically centered
            let leftSlotGap: CGFloat = 4
            let leftSlots: [EquipmentSlot] = [.shirt, .bottoms, .shoes]
            let leftTotalH = slotSize * 3 + leftSlotGap * 2
            let leftTopY = (height - leftTotalH) / 2 + slotSize / 2
            let leftX = inset + slotSize / 2

            // Stats
            let effectiveStats = vm.effectiveStats(for: player)
            let baseStats = player.stats

            // Right column layout: stats box on top, paddle + wristband below
            let rightX = width - inset

            ZStack {
                // Court background — 2x scaled
                CourtBackgroundView()
                    .frame(width: spriteSize, height: spriteSize)
                    .position(x: width / 2, y: height / 2)

                // Animated character sprite centered
                AnimatedSpriteView(
                    appearance: player.appearance,
                    size: spriteSize,
                    animationState: vm.animationState
                )
                .position(x: width / 2, y: height / 2)

                // Left column: shirt, bottoms, shoes
                ForEach(Array(leftSlots.enumerated()), id: \.element) { i, slot in
                    slotView(for: slot, size: slotSize)
                        .position(x: leftX, y: leftTopY + CGFloat(i) * (slotSize + leftSlotGap))
                }

                // Headwear slot — centered above the sprite
                slotView(for: .headwear, size: slotSize)
                    .position(x: width / 2, y: inset + slotSize / 2)

                // Right column: stats + paddle/wristband filling height
                VStack(spacing: 4) {
                    // Player stats box
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(StatType.allCases, id: \.self) { stat in
                            let base = baseStats.stat(stat)
                            let effective = effectiveStats.stat(stat)
                            let bonus = effective - base

                            HStack(spacing: 0) {
                                Text(stat.displayName.prefix(3).uppercased())
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color(white: 0.5))
                                    .frame(width: 30, alignment: .leading)

                                Text("\(base)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, alignment: .trailing)

                                if bonus != 0 {
                                    Text(bonus > 0 ? "+\(bonus)" : "\(bonus)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(bonus > 0 ? .green : .red)
                                        .frame(width: 22, alignment: .trailing)
                                }
                            }
                        }
                    }
                    .padding(6)
                    .frame(width: slotSize)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    // Paddle slot
                    slotView(for: .paddle, size: slotSize)

                    // Wristband slot
                    slotView(for: .wristband, size: slotSize)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, inset)
                .position(x: rightX - slotSize / 2, y: height / 2)
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
