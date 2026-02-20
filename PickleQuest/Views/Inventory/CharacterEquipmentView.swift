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

            // Stats box on the right
            let statsWidth: CGFloat = 130
            let statsLeft = width - inset - statsWidth

            // Player center: between left edge and stats box
            let playerCenterX = statsLeft / 2
            let playerCenterY = height * 0.45

            // Court and sprite sizing (independent)
            let courtSize = height * 2.8
            let spriteSize = height * 1.4

            // Slot sizing
            let slotSize: CGFloat = min(60, (height - inset * 2) / 5.3)
            let slotGap: CGFloat = 6

            // Left column X, right column X — equal padding from edges
            let leftX = inset + slotSize / 2
            let rightX = statsLeft - inset - slotSize / 2

            // Stats
            let effectiveStats = vm.effectiveStats(for: player)
            let baseStats = player.stats

            // Vertical stacks
            let leftSlots: [EquipmentSlot] = [.headwear, .shirt, .bottoms, .shoes]
            let rightSlots: [EquipmentSlot] = [.paddle, .wristband]

            ZStack {
                // Court background
                CourtBackgroundView()
                    .frame(width: courtSize, height: courtSize)
                    .position(x: playerCenterX, y: playerCenterY)

                // Player sprite
                AnimatedSpriteView(
                    appearance: player.appearance,
                    size: spriteSize,
                    animationState: vm.animationState
                )
                .position(x: playerCenterX, y: playerCenterY)

                // Left column: hat, shirt, bottoms, shoes — vertically centered
                let leftTotalH = slotSize * CGFloat(leftSlots.count) + slotGap * CGFloat(leftSlots.count - 1)
                let leftTopY = (height - leftTotalH) / 2 + slotSize / 2
                ForEach(Array(leftSlots.enumerated()), id: \.element) { i, slot in
                    slotView(for: slot, size: slotSize)
                        .position(x: leftX, y: leftTopY + CGFloat(i) * (slotSize + slotGap))
                }

                // Right column: paddle, wristband — vertically centered
                let rightTotalH = slotSize * CGFloat(rightSlots.count) + slotGap * CGFloat(rightSlots.count - 1)
                let rightTopY = (height - rightTotalH) / 2 + slotSize / 2
                ForEach(Array(rightSlots.enumerated()), id: \.element) { i, slot in
                    slotView(for: slot, size: slotSize)
                        .position(x: rightX, y: rightTopY + CGFloat(i) * (slotSize + slotGap))
                }

                // Stats box — full height, right side
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(StatType.allCases, id: \.self) { stat in
                        let base = baseStats.stat(stat)
                        let effective = effectiveStats.stat(stat)
                        let bonus = effective - base

                        HStack(spacing: 4) {
                            Text(stat.displayName.prefix(3).uppercased())
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.9, green: 0.7, blue: 0.3))
                                .frame(width: 36, alignment: .leading)

                            Text("\(base)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .fixedSize()

                            if bonus != 0 {
                                Text(bonus > 0 ? "+\(bonus)" : "\(bonus)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(bonus > 0 ? .green : .red)
                                    .fixedSize()
                            }

                            Spacer()
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
                .padding(10)
                .frame(width: statsWidth, height: height - inset * 2)
                .background(Color.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .position(x: width - inset - statsWidth / 2, y: height / 2)
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
