import Foundation

struct MatchPoint: Identifiable, Sendable {
    let id: UUID
    let gameNumber: Int
    let pointNumber: Int
    let winnerSide: MatchSide
    let pointType: PointType
    let rallyLength: Int
    let servingSide: MatchSide
    let scoreAfter: MatchScore

    init(
        gameNumber: Int,
        pointNumber: Int,
        winnerSide: MatchSide,
        pointType: PointType,
        rallyLength: Int,
        servingSide: MatchSide,
        scoreAfter: MatchScore
    ) {
        self.id = UUID()
        self.gameNumber = gameNumber
        self.pointNumber = pointNumber
        self.winnerSide = winnerSide
        self.pointType = pointType
        self.rallyLength = rallyLength
        self.servingSide = servingSide
        self.scoreAfter = scoreAfter
    }
}

enum PointType: String, Sendable {
    case ace
    case winner
    case unforcedError
    case forcedError
    case rally

    var displayName: String {
        switch self {
        case .ace: return "Ace"
        case .winner: return "Winner"
        case .unforcedError: return "Unforced Error"
        case .forcedError: return "Forced Error"
        case .rally: return "Rally"
        }
    }
}

enum MatchSide: String, Sendable {
    case player
    case opponent
}

struct MatchScore: Sendable {
    let playerPoints: Int
    let opponentPoints: Int
    let playerGames: Int
    let opponentGames: Int
}
