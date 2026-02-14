import SwiftUI

struct PlayerProfileView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: PlayerProfileViewModel?
    @State private var showStatAllocation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(.green.opacity(0.2))
                                .frame(width: 80, height: 80)
                            Image(systemName: "person.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.green)
                        }

                        Text(appState.player.name)
                            .font(.title.bold())

                        HStack(spacing: 16) {
                            Label("Lv. \(appState.player.progression.level)", systemImage: "star.fill")
                                .font(.subheadline)
                            Label("DUPR \(String(format: "%.1f", appState.player.duprRating))", systemImage: "chart.bar.fill")
                                .font(.subheadline)
                            Label("\(appState.player.wallet.coins)", systemImage: "dollarsign.circle.fill")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }

                    // XP Progress
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Experience")
                                .font(.headline)
                            Spacer()
                            if appState.player.progression.availableStatPoints > 0 {
                                Button {
                                    showStatAllocation = true
                                } label: {
                                    Text("\(appState.player.progression.availableStatPoints) stat points")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.orange.opacity(0.2))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        ProgressView(value: appState.player.progression.xpProgress)
                            .tint(.blue)
                        Text("\(appState.player.progression.currentXP) / \(appState.player.progression.xpToNextLevel) XP")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Equipment Summary
                    if let vm = viewModel {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Equipment")
                                .font(.headline)

                            let equipped = vm.equippedItems
                            if equipped.isEmpty {
                                Text("No equipment equipped")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(equipped, id: \.id) { item in
                                    HStack(spacing: 8) {
                                        Text(item.slot.icon)
                                        Text(item.name)
                                            .font(.subheadline)
                                            .foregroundStyle(item.rarity.color)
                                        Spacer()
                                        RarityBadge(rarity: item.rarity)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Stats
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Base Stats")
                                .font(.headline)
                            if viewModel?.effectiveStats != nil {
                                Spacer()
                                Text("(effective with gear)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(StatCategory.allCases, id: \.self) { category in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(category.displayName)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)

                                ForEach(category.stats, id: \.self) { stat in
                                    let baseValue = appState.player.stats.stat(stat)
                                    let effectiveValue = viewModel?.effectiveStats?.stat(stat)

                                    HStack(spacing: 4) {
                                        StatBar(
                                            name: stat.displayName,
                                            value: effectiveValue ?? baseValue,
                                            maxValue: GameConstants.Stats.maxValue,
                                            color: statColor(for: category)
                                        )

                                        if let eff = effectiveValue, eff != baseValue {
                                            Text("(\(baseValue))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("Profile")
            .task {
                if viewModel == nil {
                    let vm = PlayerProfileViewModel(
                        playerService: container.playerService,
                        inventoryService: container.inventoryService
                    )
                    viewModel = vm
                    await vm.loadPlayer()
                }
            }
            .onAppear {
                guard let vm = viewModel else { return }
                Task { await vm.loadPlayer() }
            }
            .sheet(isPresented: $showStatAllocation) {
                if let vm = viewModel {
                    StatAllocationView(viewModel: vm)
                }
            }
        }
    }

    private func statColor(for category: StatCategory) -> Color {
        switch category {
        case .offensive: return .red
        case .defensive: return .blue
        case .mental: return .purple
        }
    }
}
