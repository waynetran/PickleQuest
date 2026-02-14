import Foundation

struct MatchConfig: Sendable {
    let matchType: MatchType
    let pointsToWin: Int
    let gamesToWin: Int
    let winByTwo: Bool

    static let defaultSingles = MatchConfig(
        matchType: .singles,
        pointsToWin: GameConstants.Match.defaultPointsToWin,
        gamesToWin: GameConstants.Match.defaultGamesToWin,
        winByTwo: GameConstants.Match.winByTwo
    )

    static let quickMatch = MatchConfig(
        matchType: .singles,
        pointsToWin: GameConstants.Match.defaultPointsToWin,
        gamesToWin: 1,
        winByTwo: GameConstants.Match.winByTwo
    )
}

enum MatchType: String, Codable, Sendable {
    case singles
    case doubles
}
