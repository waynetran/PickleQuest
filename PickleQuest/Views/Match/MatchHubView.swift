import SwiftUI

struct MatchHubView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: MatchViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    matchContent(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Match")
            .task {
                if viewModel == nil {
                    viewModel = MatchViewModel(
                        matchService: container.matchService,
                        npcService: container.npcService
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func matchContent(vm: MatchViewModel) -> some View {
        switch vm.matchState {
        case .idle:
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "figure.pickleball")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)

                Text("PickleQuest")
                    .font(.largeTitle.bold())

                Text("DUPR \(String(format: "%.1f", appState.player.duprRating))")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await vm.loadNPCs() }
                } label: {
                    Label("Quick Match", systemImage: "bolt.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 40)

                Spacer()
            }

        case .selectingOpponent:
            NPCPickerView(viewModel: vm)

        case .simulating:
            MatchSimulationView(viewModel: vm)

        case .finished:
            if let result = vm.matchResult {
                MatchResultView(
                    result: result,
                    opponent: vm.selectedNPC,
                    levelUpRewards: vm.levelUpRewards
                ) {
                    Task {
                        await processResult(vm: vm)
                        vm.reset()
                    }
                }
            }
        }
    }

    private func processResult(vm: MatchViewModel) async {
        // Process match rewards (XP, coins, level-ups)
        var player = appState.player
        let rewards = vm.processResult(player: &player)
        _ = rewards

        // Add loot to inventory
        if !vm.lootDrops.isEmpty {
            await container.inventoryService.addEquipmentBatch(vm.lootDrops)
        }

        appState.player = player
    }
}
