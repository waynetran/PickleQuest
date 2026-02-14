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

    func startMatch(player: Player, opponent: NPC) async {
        selectedNPC = opponent
        matchState = .simulating
        eventLog = []
        matchResult = nil
        currentScore = nil
        lootDrops = []
        levelUpRewards = []

        let engine = await matchService.createMatch(
            player: player,
            opponent: opponent,
            config: .quickMatch
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

    func processResult(player: inout Player) -> [LevelUpReward] {
        guard let result = matchResult, let npc = selectedNPC else { return [] }
        let rewards = matchService.processMatchResult(result, for: &player, opponent: npc)
        levelUpRewards = rewards
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
