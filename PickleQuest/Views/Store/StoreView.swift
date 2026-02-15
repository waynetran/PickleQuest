import SwiftUI

struct StoreView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: StoreViewModel?
    @State private var showPurchaseAlert = false

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
                        inventoryService: container.inventoryService
                    )
                    viewModel = vm
                    await vm.loadStore()
                }
            }
            .onAppear {
                guard let vm = viewModel else { return }
                Task { await vm.loadStore() }
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

                // Store Grid
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
                                Task {
                                    var player = appState.player
                                    let success = await vm.buyItem(item, player: &player)
                                    if success {
                                        appState.player = player
                                    }
                                    showPurchaseAlert = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Consumables Section
                if !vm.consumableItems.isEmpty {
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
        .alert("Store", isPresented: $showPurchaseAlert) {
            Button("OK") { showPurchaseAlert = false }
        } message: {
            Text(vm.purchaseMessage ?? "")
        }
    }

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
