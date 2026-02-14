import Foundation

protocol MatchService: Sendable {
    func createMatch(
        player: Player,
        opponent: NPC,
        config: MatchConfig
    ) -> MatchEngine

    func processMatchResult(
        _ result: MatchResult,
        for player: inout Player,
        opponent: NPC
    )
}
