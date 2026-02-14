import SwiftUI

struct InventoryView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: InventoryViewModel?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    inventoryContent(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Inventory")
            .task {
                if viewModel == nil {
                    let vm = InventoryViewModel(
                        inventoryService: container.inventoryService,
                        playerService: container.playerService
                    )
                    viewModel = vm
                    await vm.loadInventory()
                }
            }
            .onAppear {
                guard let vm = viewModel else { return }
                Task { await vm.loadInventory() }
            }
        }
    }

    @ViewBuilder
    private func inventoryContent(vm: InventoryViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Equipment Slots
                EquipmentSlotsView(
                    player: appState.player,
                    selectedFilter: vm.selectedFilter,
                    equippedItemFor: { slot in
                        vm.equippedItem(for: slot, player: appState.player)
                    },
                    onSlotTap: { slot in
                        vm.setFilter(vm.selectedFilter == slot ? nil : slot)
                    },
                    onShowAll: {
                        vm.setFilter(nil)
                    }
                )

                // Item count + active filter chip
                HStack {
                    Text("\(vm.filteredInventory.count) items")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if vm.selectedFilter != nil {
                        Button {
                            vm.setFilter(nil)
                        } label: {
                            HStack(spacing: 4) {
                                Text("Show All")
                                Image(systemName: "xmark.circle.fill")
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal)

                // Item Grid
                if vm.filteredInventory.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bag")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No items")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(vm.filteredInventory) { item in
                            EquipmentCardView(
                                equipment: item,
                                isEquipped: appState.player.equippedItems.values.contains(item.id)
                            )
                            .onTapGesture {
                                vm.selectItem(item, player: appState.player)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: Binding(
            get: { vm.showingDetail },
            set: { vm.showingDetail = $0 }
        )) {
            if let item = vm.selectedItem {
                EquipmentDetailView(
                    equipment: item,
                    isEquipped: appState.player.equippedItems.values.contains(item.id),
                    currentStats: vm.effectiveStats(for: appState.player),
                    previewStats: vm.previewStats,
                    onEquip: {
                        Task {
                            var player = appState.player
                            await vm.equipItem(item, player: &player)
                            appState.player = player
                            vm.showingDetail = false
                        }
                    },
                    onUnequip: {
                        Task {
                            var player = appState.player
                            await vm.unequipSlot(item.slot, player: &player)
                            appState.player = player
                            vm.showingDetail = false
                        }
                    },
                    onSell: {
                        Task {
                            var player = appState.player
                            await vm.sellItem(item, player: &player)
                            appState.player = player
                        }
                    }
                )
                .presentationDetents([.large])
            }
        }
    }
}
