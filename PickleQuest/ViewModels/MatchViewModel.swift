import Foundation
import SwiftUI

@MainActor
@Observable
final class MatchViewModel {
    // Dependencies
    private let matchService: MatchService
    private let npcService: NPCService

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
    var repChange: Int?
    var brokenEquipment: [Equipment] = []
    var energyDrain: Double = 0
    var matchConfig: MatchConfig = .quickMatch

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

    func startMatch(player: Player, opponent: NPC) async {
        selectedNPC = opponent
        matchState = .simulating
        eventLog = []
        matchResult = nil
        currentScore = nil
        lootDrops = []
        levelUpRewards = []
        duprChange = nil
        repChange = nil
        brokenEquipment = []
        energyDrain = 0

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
            }
            if case .matchEnd(let result) = event {
                matchResult = result
                lootDrops = result.loot
                matchState = .finished
            }
            // Small delay between events for visual pacing
            try? await Task.sleep(for: .milliseconds(150))
        }
    }

    func processResult(player: inout Player) -> MatchRewards {
        guard let result = matchResult, let npc = selectedNPC else {
            return MatchRewards(levelUpRewards: [], duprChange: nil, repChange: 0, energyDrain: 0, brokenEquipment: [])
        }
        let rewards = matchService.processMatchResult(result, for: &player, opponent: npc, config: matchConfig)
        levelUpRewards = rewards.levelUpRewards
        duprChange = rewards.duprChange
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
        lootDrops = []
        levelUpRewards = []
        isRated = true
        duprChange = nil
        repChange = nil
        brokenEquipment = []
        energyDrain = 0
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
