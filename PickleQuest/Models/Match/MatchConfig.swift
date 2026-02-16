import Foundation

struct MatchConfig: Sendable {
    let matchType: MatchType
    let pointsToWin: Int
    let gamesToWin: Int
    let winByTwo: Bool
    let isRated: Bool
    let isTournament: Bool
    let wagerAmount: Int

    init(
        matchType: MatchType,
        pointsToWin: Int,
        gamesToWin: Int,
        winByTwo: Bool,
        isRated: Bool = true,
        isTournament: Bool = false,
        wagerAmount: Int = 0
    ) {
        self.matchType = matchType
        self.pointsToWin = pointsToWin
        self.gamesToWin = gamesToWin
        self.winByTwo = winByTwo
        self.isRated = isRated
        self.isTournament = isTournament
        self.wagerAmount = wagerAmount
    }

    var maxTimeouts: Int {
        isTournament ? 2 : 1
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

    static let defaultDoubles = MatchConfig(
        matchType: .doubles,
        pointsToWin: GameConstants.Match.defaultPointsToWin,
        gamesToWin: GameConstants.Match.defaultGamesToWin,
        winByTwo: GameConstants.Match.winByTwo
    )

    var isSideOutScoring: Bool {
        matchType == .doubles
    }
}

enum MatchType: String, Codable, Sendable {
    case singles
    case doubles
}
