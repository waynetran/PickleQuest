import Foundation
import SpriteKit
import SwiftUI

@MainActor
@Observable
final class MatchViewModel {
    // Dependencies
    private let matchService: MatchService
    private let npcService: NPCService

    // Loot decisions
    enum LootDecision { case equip, keep }
    var lootDecisions: [UUID: LootDecision] = [:]

    var hasUnhandledLoot: Bool {
        lootDrops.contains { lootDecisions[$0.id] == nil }
    }

    // SpriteKit visualization
    var courtScene: MatchCourtScene?
    var useSpriteVisualization = true

    // Character appearances
    var playerAppearance: CharacterAppearance = .defaultPlayer
    var opponentAppearance: CharacterAppearance = .defaultOpponent

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
    var matchConfig: MatchConfig = .quickMatch
    var currentServingSide: MatchSide = .player
    var courtName: String = ""

    enum MatchState: Equatable {
        case idle
        case selectingOpponent
        case simulating
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

    func startMatch(player: Player, opponent: NPC, courtName: String = "") async {
        selectedNPC = opponent
        self.courtName = courtName
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

        // Resolve appearances
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
            isRated: effectiveRated
        )

        let engine = await matchService.createMatch(
            player: player,
            opponent: opponent,
            config: matchConfig
        )

        let stream = await engine.simulate()
        for await event in stream {
            let entry = MatchEventEntry(event: event)
            eventLog.append(entry)

            if case .pointPlayed(let point) = event {
                currentScore = point.scoreAfter
                currentServingSide = point.servingSide
            }
            if case .matchEnd(let result) = event {
                matchResult = result
                lootDrops = result.loot
                computeRewardsPreview(player: player, opponent: opponent, result: result)
            }

            // Animate via SpriteKit scene or fall back to fixed delay
            if let courtScene, useSpriteVisualization {
                await courtScene.animate(event: event)
            } else {
                try? await Task.sleep(for: .milliseconds(150))
            }

            // Transition to finished after match end animation completes
            if case .matchEnd = event {
                matchState = .finished
            }
        }
    }

    private func computeRewardsPreview(player: Player, opponent: NPC, result: MatchResult) {
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
        lootDrops = []
        lootDecisions = [:]
        levelUpRewards = []
        isRated = true
        duprChange = nil
        potentialDuprChange = 0
        repChange = nil
        brokenEquipment = []
        energyDrain = 0
        courtName = ""
        currentServingSide = .player
    }
}

struct MatchEventEntry: Identifiable {
    let id = UUID()
    let event: MatchEvent
    let timestamp = Date()

    var narration: String {
        event.narration
    }
}
