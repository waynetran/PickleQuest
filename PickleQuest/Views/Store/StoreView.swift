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
            }
            .padding(.vertical)
        }
        .alert("Store", isPresented: $showPurchaseAlert) {
            Button("OK") { showPurchaseAlert = false }
        } message: {
            Text(vm.purchaseMessage ?? "")
        }
    }
}
