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

                Text(appState.player.duprProfile.hasRating
                    ? "SUPR \(String(format: "%.2f", appState.player.duprRating))"
                    : "SUPR: Not Rated")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                // Energy bar
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(energyColor)
                        Text("Energy")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(appState.player.currentEnergy))%")
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(energyColor)
                    }
                    ProgressView(value: appState.player.currentEnergy, total: GameConstants.PersistentEnergy.maxEnergy)
                        .tint(energyColor)
                }
                .padding(.horizontal, 40)

                if !appState.player.hasPaddleEquipped {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Paddle Required — Equip a paddle to play")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 40)
                }

                Button {
                    Task { await vm.loadNPCs() }
                } label: {
                    Label("Quick Match", systemImage: "bolt.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(appState.player.hasPaddleEquipped ? .green : .gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!appState.player.hasPaddleEquipped)
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
                    levelUpRewards: vm.levelUpRewards,
                    duprChange: vm.duprChange,
                    repChange: vm.repChange,
                    brokenEquipment: vm.brokenEquipment,
                    energyDrain: vm.energyDrain
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
        guard let result = vm.matchResult, let npc = vm.selectedNPC else { return }

        let suprBefore = appState.player.duprRating

        // Process match rewards (XP, coins, level-ups, DUPR, rep, energy)
        var player = appState.player
        let rewards = vm.processResult(player: &player)

        // Equipment durability on loss
        var brokenItems: [Equipment] = []
        if !result.didPlayerWin {
            let suprGap = npc.duprRating - player.duprRating
            let baseWear = GameConstants.Durability.baseLossWear
            let gapBonus = suprGap > 0
                ? suprGap * GameConstants.Durability.suprGapWearBonus
                : 0
            let wear = min(GameConstants.Durability.maxWearPerMatch, baseWear + gapBonus)

            for (slot, equipID) in player.equippedItems {
                guard slot == .shoes || slot == .paddle else { continue }
                if let equipment = await container.inventoryService.getEquipment(by: equipID) {
                    let newCondition = max(0, equipment.condition - wear)
                    await container.inventoryService.updateEquipmentCondition(equipID, condition: newCondition)
                    if newCondition <= 0 {
                        brokenItems.append(equipment)
                    }
                }
            }

            // Unequip and remove broken items
            if !brokenItems.isEmpty {
                for item in brokenItems {
                    player.equippedItems.removeValue(forKey: item.slot)
                }
                await container.inventoryService.removeEquipmentBatch(brokenItems.map(\.id))
                vm.brokenEquipment = brokenItems
            }
        }

        // Add loot to inventory
        if !vm.lootDrops.isEmpty {
            await container.inventoryService.addEquipmentBatch(vm.lootDrops)
        }

        // Record match history
        let historyEntry = MatchHistoryEntry(
            id: UUID(),
            date: Date(),
            opponentName: npc.name,
            opponentDifficulty: npc.difficulty,
            opponentDUPR: npc.duprRating,
            didWin: result.didPlayerWin,
            scoreString: result.formattedScore,
            isRated: rewards.duprChange != nil,
            duprChange: rewards.duprChange,
            suprBefore: suprBefore,
            suprAfter: player.duprRating,
            repChange: rewards.repChange,
            xpEarned: result.xpEarned,
            coinsEarned: result.coinsEarned,
            equipmentBroken: brokenItems.map(\.name)
        )
        player.matchHistory.append(historyEntry)

        appState.player = player
    }

    private var energyColor: Color {
        let energy = appState.player.currentEnergy
        if energy >= 80 { return .green }
        if energy >= 50 { return .yellow }
        return .red
    }
}
