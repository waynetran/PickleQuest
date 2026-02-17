import Foundation
import SpriteKit
import SwiftUI

@MainActor
@Observable
final class MatchViewModel {
    // Dependencies
    private let matchService: MatchService
    private let npcService: NPCService

    // Loot decisions (LootDecision enum is in Models/Common/LootDecision.swift)
    var lootDecisions: [UUID: LootDecision] = [:]

    var hasUnhandledLoot: Bool {
        lootDrops.contains { lootDecisions[$0.id] == nil }
    }

    // SpriteKit visualization
    var courtScene: MatchCourtScene?
    var useSpriteVisualization = true

    // Engine reference for actions
    private var engine: MatchEngine?

    // Action state
    var isSkipping = false
    var timeoutsAvailable: Int = 1
    var consumablesUsedCount: Int = 0
    var hookCallsAvailable: Int = 1
    var playerConsumables: [Consumable] = []
    var opponentStreak: Int = 0

    // Character appearances
    var playerAppearance: CharacterAppearance = .defaultPlayer
    var opponentAppearance: CharacterAppearance = .defaultOpponent
    var partnerAppearance: CharacterAppearance?
    var opponent2Appearance: CharacterAppearance?

    // Wager state
    var wagerAmount: Int = 0
    var isHustlerMatch: Bool = false
    var pendingWagerNPC: NPC?
    var showWagerSheet: Bool = false

    // Contested drop loot override
    var contestedDropRarity: EquipmentRarity?
    var contestedDropItemCount: Int = 0

    // Doubles state
    var selectedPartner: NPC?
    var opponentPartner: NPC?
    var teamSynergy: TeamSynergy?
    var doublesScoreDisplay: String?
    var isDoublesMode = false

    // State
    var availableNPCs: [NPC] = []
    var selectedNPC: NPC?
    var matchState: MatchState = .idle
    var eventLog: [MatchEventEntry] = []
    var matchResult: MatchResult?
    var currentScore: MatchScore?
    var lootDrops: [Equipment] = []
    var levelUpRewards: [LevelUpReward] = []
    var isRated: Bool = true
    var duprChange: Double?
    var potentialDuprChange: Double = 0
    var repChange: Int?
    var brokenEquipment: [Equipment] = []
    var energyDrain: Double = 0
    var bonusLootReady = false
    var matchConfig: MatchConfig = .quickMatch
    var currentServingSide: MatchSide = .player
    var courtName: String = ""
    var playerName: String = "You"

    var canUseTimeout: Bool {
        matchState == .simulating && !isSkipping && timeoutsAvailable > 0
    }

    var canUseConsumable: Bool {
        matchState == .simulating && !isSkipping && consumablesUsedCount < GameConstants.MatchActions.maxConsumablesPerMatch && !playerConsumables.isEmpty
    }

    var canHookCall: Bool {
        matchState == .simulating && !isSkipping && hookCallsAvailable > 0
    }

    enum MatchState: Equatable {
        case idle
        case selectingOpponent
        case selectingPartner
        case simulating
        case interactiveMatch
        case finished
    }

    init(matchService: MatchService, npcService: NPCService) {
        self.matchService = matchService
        self.npcService = npcService
    }

    func loadNPCs() async {
        availableNPCs = await npcService.getAllNPCs()
        matchState = .selectingOpponent
    }

    /// Whether the match will be auto-unrated due to rating gap.
    func isAutoUnrated(playerRating: Double, opponentRating: Double) -> Bool {
        DUPRCalculator.shouldAutoUnrate(playerRating: playerRating, opponentRating: opponentRating)
    }

    /// The effective rated status (considering auto-unrate).
    func effectiveIsRated(playerRating: Double, opponentRating: Double) -> Bool {
        isRated && !isAutoUnrated(playerRating: playerRating, opponentRating: opponentRating)
    }

    func startMatch(player: Player, opponent: NPC, courtName: String = "", wagerAmount: Int = 0) async {
        selectedNPC = opponent
        self.courtName = courtName
        self.playerName = player.name
        self.wagerAmount = wagerAmount
        self.isHustlerMatch = opponent.isHustler
        isDoublesMode = false
        resetMatchState()

        playerAppearance = player.appearance
        opponentAppearance = AppearanceGenerator.appearance(for: opponent)

        let effectiveRated = effectiveIsRated(
            playerRating: player.duprRating,
            opponentRating: opponent.duprRating
        )
        matchConfig = MatchConfig(
            matchType: .singles,
            pointsToWin: GameConstants.Match.defaultPointsToWin,
            gamesToWin: 1,
            winByTwo: GameConstants.Match.winByTwo,
            isRated: effectiveRated,
            wagerAmount: wagerAmount
        )

        let newEngine = await matchService.createMatch(
            player: player,
            opponent: opponent,
            config: matchConfig,
            playerConsumables: player.consumables,
            playerReputation: player.repProfile.reputation
        )
        self.engine = newEngine
        await runEngineStream(engine: newEngine, player: player, opponent: opponent)
    }

    /// Switch from a simulated match (already in .simulating state) to interactive mode.
    /// Discards the running engine and transitions to .interactiveMatch.
    func switchToInteractive(player: Player) {
        guard let opponent = selectedNPC else { return }

        // Discard the running simulation engine
        engine = nil
        courtScene = nil

        // Reconfigure for interactive match scoring
        let effectiveRated = effectiveIsRated(
            playerRating: player.duprRating,
            opponentRating: opponent.duprRating
        )
        matchConfig = MatchConfig(
            matchType: .singles,
            pointsToWin: GameConstants.InteractiveMatch.pointsToWin,
            gamesToWin: 1,
            winByTwo: true,
            isRated: effectiveRated,
            wagerAmount: wagerAmount
        )

        matchState = .interactiveMatch
    }

    func startDoublesMatch(
        player: Player,
        partner: NPC,
        opponent1: NPC,
        opponent2: NPC,
        courtName: String = ""
    ) async {
        selectedNPC = opponent1
        selectedPartner = partner
        opponentPartner = opponent2
        self.courtName = courtName
        self.playerName = player.name
        isDoublesMode = true
        resetMatchState()

        playerAppearance = player.appearance
        opponentAppearance = AppearanceGenerator.appearance(for: opponent1)
        partnerAppearance = AppearanceGenerator.appearance(for: partner)
        opponent2Appearance = AppearanceGenerator.appearance(for: opponent2)

        teamSynergy = TeamSynergy.calculate(p1: player.personality, p2: partner.personality)

        let effectiveRated = effectiveIsRated(
            playerRating: player.duprRating,
            opponentRating: (opponent1.duprRating + opponent2.duprRating) / 2.0
        )
        matchConfig = MatchConfig(
            matchType: .doubles,
            pointsToWin: GameConstants.Match.defaultPointsToWin,
            gamesToWin: 1,
            winByTwo: GameConstants.Match.winByTwo,
            isRated: effectiveRated
        )

        let newEngine = await matchService.createDoublesMatch(
            player: player,
            partner: partner,
            opponent1: opponent1,
            opponent2: opponent2,
            config: matchConfig,
            playerConsumables: player.consumables,
            playerReputation: player.repProfile.reputation
        )
        self.engine = newEngine
        await runEngineStream(engine: newEngine, player: player, opponent: opponent1)
    }

    private func resetMatchState() {
        matchState = .simulating
        eventLog = []
        matchResult = nil
        currentScore = nil
        currentServingSide = .player
        lootDrops = []
        lootDecisions = [:]
        levelUpRewards = []
        duprChange = nil
        potentialDuprChange = 0
        repChange = nil
        brokenEquipment = []
        energyDrain = 0
        bonusLootReady = false
        isSkipping = false
        timeoutsAvailable = matchConfig.maxTimeouts
        consumablesUsedCount = 0
        hookCallsAvailable = 1
        opponentStreak = 0
        doublesScoreDisplay = nil
    }

    private func runEngineStream(engine: MatchEngine, player: Player, opponent: NPC) async {
        let stream = await engine.simulate()
        for await event in stream {
            let entry = MatchEventEntry(event: event, playerName: playerName)
            eventLog.append(entry)

            if case .pointPlayed(let point) = event {
                currentScore = point.scoreAfter
                currentServingSide = point.servingSide
                doublesScoreDisplay = point.scoreAfter.doublesScoreDisplay
                await refreshActionState()
            }
            if case .gameStart = event {
                timeoutsAvailable = matchConfig.maxTimeouts
                hookCallsAvailable = 1
            }
            if case .matchEnd(let result) = event {
                matchResult = result
                // Override loot for contested drop matches
                if result.didPlayerWin, let dropRarity = contestedDropRarity, contestedDropItemCount > 0 {
                    let lootGen = LootGenerator()
                    lootDrops = (0..<contestedDropItemCount).map { _ in
                        lootGen.generateEquipment(rarity: dropRarity)
                    }
                } else {
                    lootDrops = result.loot
                }
                computeRewardsPreview(player: player, opponent: opponent, result: result)
            }

            if !isSkipping {
                if let courtScene, useSpriteVisualization {
                    await courtScene.animate(event: event)
                } else {
                    try? await Task.sleep(for: .milliseconds(150))
                }
            }

            if case .matchEnd = event {
                matchState = .finished
                self.engine = nil
            }
        }
    }

    private func refreshActionState() async {
        guard let engine else { return }
        opponentStreak = await engine.opponentCurrentStreak
        timeoutsAvailable = await engine.canTimeout ? 1 : 0
        hookCallsAvailable = await engine.canHookCall ? 1 : 0
        let remaining = await engine.remainingConsumables
        playerConsumables = remaining
        let usedCount = await engine.canUseConsumable ? consumablesUsedCount : GameConstants.MatchActions.maxConsumablesPerMatch
        _ = usedCount // consumablesUsedCount already tracked locally
    }

    // MARK: - Actions

    func skipMatch() async {
        guard let engine else { return }
        isSkipping = true
        await engine.requestSkip()
    }

    func resignMatch() async {
        guard let engine else { return }
        await engine.requestResign()
    }

    func callTimeout() async {
        guard let engine else { return }
        let result = await engine.requestTimeout()
        if case .timeoutUsed = result {
            timeoutsAvailable = 0
        }
    }

    func useConsumable(_ consumable: Consumable) async {
        guard let engine else { return }
        let result = await engine.useConsumable(consumable)
        if case .consumableUsed = result {
            consumablesUsedCount += 1
            playerConsumables.removeAll { $0.id == consumable.id }
        }
    }

    func hookLineCall() async {
        guard let engine else { return }
        let result = await engine.requestHookCall()
        if case .hookCallResult = result {
            hookCallsAvailable = 0
        }
    }

    private func computeRewardsPreview(player: Player, opponent: NPC, result: MatchResult) {
        // Resigned matches: no DUPR change, check frequent resign penalty
        if result.wasResigned {
            potentialDuprChange = 0
            duprChange = nil

            // Check frequent resign for rep penalty
            let recentHistory = player.matchHistory.suffix(GameConstants.MatchActions.resignCheckWindow)
            let recentResigns = recentHistory.filter(\.wasResigned).count
            if recentResigns >= GameConstants.MatchActions.resignFrequentThreshold {
                repChange = -GameConstants.MatchActions.resignFrequentRepPenalty
            } else {
                repChange = 0
            }
            return
        }

        let lastGame = result.gameScores.last ?? result.finalScore
        let change = DUPRCalculator.calculateRatingChange(
            playerRating: player.duprRating,
            opponentRating: opponent.duprRating,
            playerPoints: lastGame.playerPoints,
            opponentPoints: lastGame.opponentPoints,
            pointsToWin: matchConfig.pointsToWin,
            kFactor: player.duprProfile.kFactor
        )
        potentialDuprChange = change

        if matchConfig.isRated && !DUPRCalculator.shouldAutoUnrate(
            playerRating: player.duprRating,
            opponentRating: opponent.duprRating
        ) {
            duprChange = change
        }

        repChange = RepCalculator.calculateRepChange(
            didWin: result.didPlayerWin,
            playerSUPR: player.duprRating,
            opponentSUPR: opponent.duprRating
        )

        if !result.didPlayerWin {
            let suprGap = opponent.duprRating - player.duprRating
            let baseDrain = GameConstants.PersistentEnergy.baseLossDrain
            let gapDrain = suprGap > 0 ? suprGap * GameConstants.PersistentEnergy.suprGapDrainBonus : 0
            energyDrain = min(GameConstants.PersistentEnergy.maxDrainPerMatch, baseDrain + gapDrain)
        }
    }

    func computeRewardsPreviewForInteractive(player: Player, opponent: NPC, result: MatchResult) {
        computeRewardsPreview(player: player, opponent: opponent, result: result)
    }

    func processResult(player: inout Player) -> MatchRewards {
        guard let result = matchResult, let npc = selectedNPC else {
            return MatchRewards(levelUpRewards: [], duprChange: nil, potentialDuprChange: 0, repChange: 0, energyDrain: 0, brokenEquipment: [])
        }
        let rewards = matchService.processMatchResult(result, for: &player, opponent: npc, config: matchConfig)
        levelUpRewards = rewards.levelUpRewards
        duprChange = rewards.duprChange
        potentialDuprChange = rewards.potentialDuprChange
        repChange = rewards.repChange
        brokenEquipment = rewards.brokenEquipment
        energyDrain = rewards.energyDrain
        return rewards
    }

    func reset() {
        matchState = .idle
        eventLog = []
        matchResult = nil
        selectedNPC = nil
        currentScore = nil
        courtScene = nil
        engine = nil
        lootDrops = []
        lootDecisions = [:]
        levelUpRewards = []
        isRated = true
        duprChange = nil
        potentialDuprChange = 0
        repChange = nil
        brokenEquipment = []
        energyDrain = 0
        bonusLootReady = false
        courtName = ""
        currentServingSide = .player
        isSkipping = false
        timeoutsAvailable = 1
        consumablesUsedCount = 0
        hookCallsAvailable = 1
        playerConsumables = []
        opponentStreak = 0
        wagerAmount = 0
        isHustlerMatch = false
        pendingWagerNPC = nil
        showWagerSheet = false
        contestedDropRarity = nil
        contestedDropItemCount = 0
        selectedPartner = nil
        opponentPartner = nil
        teamSynergy = nil
        doublesScoreDisplay = nil
        isDoublesMode = false
        partnerAppearance = nil
        opponent2Appearance = nil
    }
}

struct MatchEventEntry: Identifiable {
    let id = UUID()
    let event: MatchEvent
    let playerName: String
    let timestamp = Date()

    var narration: String {
        event.narration(playerName: playerName)
    }
}
