import SwiftUI

struct InventoryGridView: View {
    @Bindable var vm: InventoryViewModel
    let player: Player

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 6) {
                ForEach(0..<vm.tabCount, id: \.self) { tab in
                    Button {
                        vm.currentTab = tab
                    } label: {
                        Text("\(tab + 1)")
                            .font(.system(size: 12, design: .monospaced).bold())
                            .foregroundStyle(vm.currentTab == tab ? .white : Color(white: 0.5))
                            .frame(width: 32, height: 24)
                            .background(vm.currentTab == tab ? Color(white: 0.25) : Color.clear)
                            .overlay(
                                Rectangle()
                                    .strokeBorder(
                                        vm.currentTab == tab ? Color(white: 0.5) : Color(white: 0.2),
                                        lineWidth: 2
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Item count
                Text("\(vm.filteredInventory.count) items")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(white: 0.4))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            // Filter chips
            if vm.selectedFilter != nil {
                HStack(spacing: 6) {
                    if let filter = vm.selectedFilter {
                        Text("\(filter.icon) \(filter.displayName)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    Button {
                        vm.setFilter(nil)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }

            // 4x5 grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<20, id: \.self) { index in
                    let item = vm.itemForSlot(tab: vm.currentTab, index: index, player: player)
                    let isEquipped = item.map { eq in
                        player.equippedItems.values.contains(eq.id)
                    } ?? false

                    InventorySlotView(
                        item: item,
                        isEquipped: isEquipped,
                        onTap: {
                            if let item {
                                vm.selectItem(item, player: player)
                            }
                        },
                        onDragStart: { equipment, location in
                            vm.startDrag(item: equipment, at: location, player: player)
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }
}
