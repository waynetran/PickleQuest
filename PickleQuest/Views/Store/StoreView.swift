import SwiftUI

struct StoreView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: StoreViewModel?
    @State private var showPurchaseAlert = false
    @State private var selectedTab = 0

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    storeContent(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Store")
            .task {
                if viewModel == nil {
                    let vm = StoreViewModel(
                        storeService: container.storeService,
                        inventoryService: container.inventoryService,
                        playerService: container.playerService
                    )
                    viewModel = vm
                    await vm.loadStore()
                    await vm.loadPlayerInventory()
                }
            }
            .onAppear {
                guard let vm = viewModel else { return }
                Task {
                    await vm.loadStore()
                    await vm.loadPlayerInventory()
                }
            }
        }
    }

    @ViewBuilder
    private func storeContent(vm: StoreViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Wallet + Refresh
                HStack {
                    Label("\(appState.player.wallet.coins) coins", systemImage: "dollarsign.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.yellow)

                    Spacer()

                    Button {
                        Task {
                            var player = appState.player
                            let refreshed = await vm.refreshStore(player: &player)
                            if refreshed {
                                appState.player = player
                            }
                            showPurchaseAlert = true
                        }
                    } label: {
                        Label("Refresh (\(GameConstants.Store.refreshCost))", systemImage: "arrow.clockwise")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)

                // Buy / Sell tab picker
                Picker("", selection: $selectedTab) {
                    Text("Buy").tag(0)
                    Text("Sell").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if selectedTab == 0 {
                    buyTabContent(vm: vm)
                } else {
                    sellTabContent(vm: vm)
                }

                // Consumables Section (Buy tab only)
                if selectedTab == 0, !vm.consumableItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Consumables")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(vm.consumableItems) { item in
                            consumableRow(item: item, vm: vm)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: Binding(
            get: { vm.showingDetail },
            set: { vm.showingDetail = $0 }
        )) {
            if let equipment = vm.selectedEquipment {
                if vm.isStoreItem {
                    storeItemDetail(vm: vm, equipment: equipment)
                } else {
                    ownedItemDetail(vm: vm, equipment: equipment)
                }
            }
        }
        .alert("Store", isPresented: $showPurchaseAlert) {
            Button("OK") { showPurchaseAlert = false }
        } message: {
            Text(vm.purchaseMessage ?? "")
        }
    }

    // MARK: - Buy Tab

    @ViewBuilder
    private func buyTabContent(vm: StoreViewModel) -> some View {
        if vm.storeItems.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "cart")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Store is empty")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(vm.storeItems) { item in
                    StoreItemCard(
                        item: item,
                        canAfford: appState.player.wallet.coins >= item.price
                    )
                    .onTapGesture {
                        guard !item.isSoldOut else { return }
                        vm.selectStoreItem(item, player: appState.player)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Sell Tab

    @ViewBuilder
    private func sellTabContent(vm: StoreViewModel) -> some View {
        let sellable = vm.sellableInventory(player: appState.player)
        if sellable.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("No items to sell")
                    .foregroundStyle(.secondary)
                Text("Equipped items cannot be sold here")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 40)
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(sellable) { item in
                    sellItemCard(item: item)
                        .onTapGesture {
                            vm.selectOwnedItem(item, player: appState.player)
                        }
                }
            }
            .padding(.horizontal)
        }
    }

    private func sellItemCard(item: Equipment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            EquipmentCardView(equipment: item, isEquipped: false)

            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.yellow)
                Text("Sell: \(item.effectiveSellPrice)")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Detail Sheets

    private func storeItemDetail(vm: StoreViewModel, equipment: Equipment) -> some View {
        let storeItem = vm.storeItems.first { $0.equipment.id == equipment.id }
        let price = storeItem?.price ?? 0

        return EquipmentDetailView(
            equipment: equipment,
            isEquipped: false,
            currentStats: vm.effectiveStats(for: appState.player),
            previewStats: vm.previewStats,
            playerCoins: appState.player.wallet.coins,
            playerLevel: appState.player.progression.level,
            onEquip: {},
            onUnequip: {},
            onBuy: {
                guard let storeItem else { return }
                Task {
                    var player = appState.player
                    let success = await vm.buyItem(storeItem, player: &player)
                    if success {
                        appState.player = player
                    }
                    vm.showingDetail = false
                    showPurchaseAlert = true
                }
            },
            buyPrice: price
        )
        .presentationDetents([.large])
    }

    private func ownedItemDetail(vm: StoreViewModel, equipment: Equipment) -> some View {
        let isEquipped = appState.player.equippedItems.values.contains(equipment.id)

        return EquipmentDetailView(
            equipment: equipment,
            isEquipped: isEquipped,
            currentStats: vm.effectiveStats(for: appState.player),
            previewStats: vm.previewStats,
            playerCoins: appState.player.wallet.coins,
            playerLevel: appState.player.progression.level,
            onEquip: {
                Task {
                    var player = appState.player
                    await vm.equipItem(equipment, player: &player)
                    appState.player = player
                    vm.showingDetail = false
                }
            },
            onUnequip: {
                Task {
                    var player = appState.player
                    await vm.unequipSlot(equipment.slot, player: &player)
                    appState.player = player
                    vm.showingDetail = false
                }
            },
            onSell: {
                Task {
                    var player = appState.player
                    await vm.sellItem(equipment, player: &player)
                    appState.player = player
                }
            }
        )
        .presentationDetents([.large])
    }

    // MARK: - Consumables

    private func consumableRow(item: StoreConsumableItem, vm: StoreViewModel) -> some View {
        let canAfford = appState.player.wallet.coins >= item.consumable.price
        return HStack(spacing: 12) {
            Image(systemName: item.consumable.iconName)
                .font(.title3)
                .foregroundStyle(item.isSoldOut ? Color.secondary : Color.blue)
                .frame(width: 36, height: 36)
                .background(Color(.systemGray6))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.consumable.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(item.isSoldOut ? .secondary : .primary)
                Text(item.consumable.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if item.isSoldOut {
                Text("Sold")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    Task {
                        var player = appState.player
                        let success = await vm.buyConsumable(item, player: &player)
                        if success {
                            appState.player = player
                        }
                        showPurchaseAlert = true
                    }
                } label: {
                    Text("\(item.consumable.price)")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(canAfford ? .yellow : .gray)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
                .disabled(!canAfford)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}
