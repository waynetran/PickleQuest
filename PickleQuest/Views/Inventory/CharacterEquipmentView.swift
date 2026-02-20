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
            let statsWidth: CGFloat = 100
            let statsLeft = width - inset - statsWidth

            // Player center: between left edge and stats box
            let playerCenterX = statsLeft / 2
            let playerCenterY = height / 2

            // Court and sprite sizing (independent)
            let courtSize = height * 2.8
            let spriteSize = height * 1.4

            // Slot sizing
            let slotSize: CGFloat = min(70, (height - inset * 2) / 4.5)

            // Semi-circle radius — constrained to fit
            let maxRadiusX = (statsLeft - playerCenterX - slotSize / 2 - 4)
            let maxRadiusY = (height / 2 - slotSize / 2 - inset)
            let radius = min(maxRadiusX, maxRadiusY)

            // Stats
            let effectiveStats = vm.effectiveStats(for: player)
            let baseStats = player.stats

            // Slot positions: body gear clustered far-left, hand gear clustered far-right
            let slotData: [(slot: EquipmentSlot, angle: CGFloat)] = [
                (.headwear, 135),    // upper-left
                (.shirt, 165),       // left, above center
                (.bottoms, 195),     // left, below center
                (.shoes, 225),       // lower-left
                (.paddle, 15),       // right, above center
                (.wristband, 345),   // right, below center
            ]

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

                // Semi-circle equipment slots
                ForEach(slotData, id: \.slot) { data in
                    let angleRad = data.angle * .pi / 180
                    let x = playerCenterX + radius * cos(angleRad)
                    let y = playerCenterY - radius * sin(angleRad)
                    slotView(for: data.slot, size: slotSize)
                        .position(x: x, y: y)
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

                            if bonus != 0 {
                                Text(bonus > 0 ? "+\(bonus)" : "\(bonus)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(bonus > 0 ? .green : .red)
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
