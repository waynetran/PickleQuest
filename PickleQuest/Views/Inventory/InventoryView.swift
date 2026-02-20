import SwiftUI

struct InventoryView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: InventoryViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.08).ignoresSafeArea()

                if let vm = viewModel {
                    inventoryContent(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationBarHidden(true)
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
        GeometryReader { geo in
            let availableHeight = geo.size.height
            let equipHeight = availableHeight * 0.40

            VStack(spacing: 0) {
                // Block 1: Character + Equipment Slots (~40%)
                CharacterEquipmentView(vm: vm, player: appState.player)
                    .frame(height: equipHeight)

                // Pixel divider
                Rectangle()
                    .fill(Color(white: 0.2))
                    .frame(height: 2)

                // Block 2: Tabbed Inventory Grid (remaining ~60%)
                InventoryGridView(vm: vm, player: appState.player)
            }
        }
        .sheet(isPresented: Binding(
            get: { vm.showingDetail },
            set: { vm.showingDetail = $0 }
        )) {
            if let item = vm.selectedItem {
                NavigationStack {
                    ItemDetailView(
                        equipment: item,
                        isEquipped: appState.player.equippedItems.values.contains(item.id),
                        currentStats: vm.effectiveStats(for: appState.player),
                        previewStats: vm.previewStats,
                        playerCoins: appState.player.wallet.coins,
                        playerLevel: appState.player.progression.level,
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
                        },
                        onRepair: item.isBroken ? {
                            Task {
                                var player = appState.player
                                guard player.wallet.coins >= item.repairCost else { return }
                                player.wallet.coins -= item.repairCost
                                let success = await vm.repairItem(item)
                                if success {
                                    appState.player = player
                                    vm.showingDetail = false
                                }
                            }
                        } : nil,
                        onUpgrade: {
                            Task {
                                var player = appState.player
                                _ = await vm.upgradeItem(item, player: &player)
                                appState.player = player
                            }
                        }
                    )
                }
                .presentationDetents([.large])
            }
        }
    }
}
