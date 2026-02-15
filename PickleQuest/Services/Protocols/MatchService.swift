import Foundation

protocol MatchService: Sendable {
    func createMatch(
        player: Player,
        opponent: NPC,
        config: MatchConfig,
        playerConsumables: [Consumable],
        playerReputation: Int
    ) async -> MatchEngine

    func processMatchResult(
        _ result: MatchResult,
        for player: inout Player,
        opponent: NPC,
        config: MatchConfig
    ) -> MatchRewards
}
