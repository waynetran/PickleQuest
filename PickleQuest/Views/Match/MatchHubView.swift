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
                        coachService: container.coachService,
                        dailyChallengeService: container.dailyChallengeService,
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
        case .selectingPartner: return "Pick Your Partner"
        default: return "Map"
        }
    }

    private func partnerCandidates(mapVM: MapViewModel, matchVM: MatchViewModel) -> [NPC] {
        let excludeIDs = Set([matchVM.selectedNPC?.id, matchVM.opponentPartner?.id].compactMap { $0 })
        return mapVM.npcsAtSelectedCourt.filter { !excludeIDs.contains($0.id) }
    }

    @ViewBuilder
    private func matchContent(matchVM: MatchViewModel, mapVM: MapViewModel) -> some View {
        switch matchVM.matchState {
        case .idle, .selectingOpponent:
            MapContentView(mapVM: mapVM, matchVM: matchVM)
                .navigationBarTitleDisplayMode(.inline)

        case .selectingPartner:
            PartnerPickerView(
                availableNPCs: partnerCandidates(mapVM: mapVM, matchVM: matchVM),
                playerPersonality: appState.player.personality,
                opponent1: matchVM.selectedNPC,
                opponent2: matchVM.opponentPartner,
                onSelect: { partner in
                    guard let opp1 = matchVM.selectedNPC,
                          let opp2 = matchVM.opponentPartner else { return }
                    let courtName = mapVM.selectedCourt?.name ?? ""
                    Task {
                        await matchVM.startDoublesMatch(
                            player: appState.player,
                            partner: partner,
                            opponent1: opp1,
                            opponent2: opp2,
                            courtName: courtName
                        )
                    }
                },
                onCancel: {
                    matchVM.reset()
                }
            )

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

        // Equipment durability wear
        var brokenItems: [Equipment] = []
        if !result.wasResigned {
            let wear: Double
            if result.didPlayerWin {
                // Win wear: flat 3%
                wear = GameConstants.Durability.baseWinWear
            } else {
                // Loss wear: base + SUPR gap bonus
                let suprGap = npc.duprRating - player.duprRating
                let baseWear = GameConstants.Durability.baseLossWear
                let gapBonus = suprGap > 0
                    ? suprGap * GameConstants.Durability.suprGapWearBonus
                    : 0
                wear = min(GameConstants.Durability.maxWearPerMatch, baseWear + gapBonus)
            }

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

            // Broken equipment stays in inventory but gets unequipped
            if !brokenItems.isEmpty {
                for item in brokenItems {
                    player.equippedItems.removeValue(forKey: item.slot)
                }
                matchVM.brokenEquipment = brokenItems
            }
        }

        // Daily challenge progress
        if var challengeState = mapVM?.dailyChallengeState {
            if result.didPlayerWin && !result.wasResigned {
                challengeState.incrementProgress(for: .winMatches)
                // Beat stronger NPC
                if npc.duprRating > player.duprRating {
                    challengeState.incrementProgress(for: .beatStrongerNPC)
                }
                // Win without consumables
                if matchVM.consumablesUsedCount == 0 {
                    challengeState.incrementProgress(for: .winWithoutConsumables)
                }
            }
            if matchVM.isDoublesMode {
                challengeState.incrementProgress(for: .playDoublesMatch)
            }
            mapVM?.dailyChallengeState = challengeState
            player.dailyChallengeState = challengeState
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

        // Wager loss deduction (MockMatchService handles the wallet, but we need to ensure
        // the wager cost is reflected in the player we're building)
        // Note: MockMatchService.processMatchResult already adds/deducts wager coins

        // Track NPC loss record for wager refusal mechanic
        if result.didPlayerWin && !result.wasResigned {
            player.npcLossRecord[npc.id, default: 0] += 1
        } else {
            player.npcLossRecord[npc.id] = 0
        }

        // Hustler defeat: generate premium loot
        if result.didPlayerWin && !result.wasResigned && npc.isHustler {
            let hustlerLoot = HustlerLootGenerator.generateHustlerLoot()
            matchVM.lootDrops.append(contentsOf: hustlerLoot)
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
            wasResigned: result.wasResigned,
            matchType: matchVM.isDoublesMode ? .doubles : .singles,
            partnerName: matchVM.selectedPartner?.name,
            opponent2Name: matchVM.opponentPartner?.name,
            wagerAmount: matchVM.wagerAmount
        )
        player.matchHistory.append(historyEntry)

        appState.player = player

        // Auto-save after match
        let currentInventory = await container.inventoryService.getInventory()
        let currentConsumables = await container.inventoryService.getConsumables()
        await appState.saveCurrentPlayer(
            using: container.persistenceService,
            inventory: currentInventory,
            consumables: currentConsumables
        )
    }
}
