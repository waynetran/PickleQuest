import SwiftUI

struct MatchHubView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer

    @State private var matchVM: MatchViewModel?
    @State private var mapVM: MapViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let matchVM, let mapVM {
                    matchContent(matchVM: matchVM, mapVM: mapVM)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(navigationTitle)
            .task {
                if matchVM == nil {
                    matchVM = MatchViewModel(
                        matchService: container.matchService,
                        npcService: container.npcService
                    )
                }
                if mapVM == nil {
                    mapVM = MapViewModel(
                        courtService: container.courtService,
                        courtProgressionService: container.courtProgressionService,
                        npcService: container.npcService,
                        locationManager: container.locationManager
                    )
                }
            }
        }
    }

    private var navigationTitle: String {
        switch matchVM?.matchState {
        case .simulating: return ""
        case .finished: return "Results"
        default: return "Map"
        }
    }

    @ViewBuilder
    private func matchContent(matchVM: MatchViewModel, mapVM: MapViewModel) -> some View {
        switch matchVM.matchState {
        case .idle, .selectingOpponent:
            MapContentView(mapVM: mapVM, matchVM: matchVM)
                .navigationBarTitleDisplayMode(.inline)

        case .simulating:
            if matchVM.useSpriteVisualization {
                MatchSpriteView(viewModel: matchVM)
                    .toolbar(.hidden, for: .navigationBar)
                    .toolbar(.hidden, for: .tabBar)
            } else {
                MatchSimulationView(viewModel: matchVM)
            }

        case .finished:
            if let result = matchVM.matchResult {
                MatchResultView(
                    result: result,
                    opponent: matchVM.selectedNPC,
                    matchVM: matchVM,
                    levelUpRewards: matchVM.levelUpRewards,
                    duprChange: matchVM.duprChange,
                    potentialDuprChange: matchVM.potentialDuprChange,
                    repChange: matchVM.repChange,
                    brokenEquipment: matchVM.brokenEquipment,
                    energyDrain: matchVM.energyDrain
                ) {
                    Task {
                        await processResult(matchVM: matchVM)
                        matchVM.reset()
                    }
                }
            }
        }
    }

    private func processResult(matchVM: MatchViewModel) async {
        guard let result = matchVM.matchResult, let npc = matchVM.selectedNPC else { return }

        let suprBefore = appState.player.duprRating

        // Process match rewards (XP, coins, level-ups, DUPR, rep, energy)
        var player = appState.player
        let rewards = matchVM.processResult(player: &player)

        // Equipment durability on loss (skip for resigned matches)
        var brokenItems: [Equipment] = []
        if !result.didPlayerWin && !result.wasResigned {
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
                matchVM.brokenEquipment = brokenItems
            }
        }

        // Add loot to inventory (only items the player chose to keep or equip)
        let keptLoot = matchVM.lootDrops.filter { matchVM.lootDecisions[$0.id] != nil }
        if !keptLoot.isEmpty {
            await container.inventoryService.addEquipmentBatch(keptLoot)
        }

        // Equip items marked for equip
        for item in matchVM.lootDrops {
            if matchVM.lootDecisions[item.id] == .equip {
                player.equippedItems[item.slot] = item.id
            }
        }

        // Remove used consumables from player inventory
        if matchVM.consumablesUsedCount > 0 {
            // consumables were consumed in the engine; remove from player's inventory
            let usedIDs = Set(player.consumables.prefix(matchVM.consumablesUsedCount).map(\.id))
            for id in usedIDs {
                await container.inventoryService.removeConsumable(id)
            }
            player.consumables.removeAll { usedIDs.contains($0.id) }
        }

        // Advance court ladder on win
        if let mapVM, let court = mapVM.selectedCourt, result.didPlayerWin, !result.wasResigned {
            await mapVM.recordMatchResult(courtID: court.id, npcID: npc.id, didWin: true)

            // Handle alpha loot drops
            if case .alphaDefeated(let alphaLoot) = mapVM.ladderAdvanceResult {
                matchVM.lootDrops.append(contentsOf: alphaLoot)
            }
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
            equipmentBroken: brokenItems.map(\.name),
            wasResigned: result.wasResigned
        )
        player.matchHistory.append(historyEntry)

        appState.player = player
    }
}
