import Foundation

struct MatchConfig: Sendable {
    let matchType: MatchType
    let pointsToWin: Int
    let gamesToWin: Int
    let winByTwo: Bool
    let isRated: Bool

    init(
        matchType: MatchType,
        pointsToWin: Int,
        gamesToWin: Int,
        winByTwo: Bool,
        isRated: Bool = true
    ) {
        self.matchType = matchType
        self.pointsToWin = pointsToWin
        self.gamesToWin = gamesToWin
        self.winByTwo = winByTwo
        self.isRated = isRated
    }

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
