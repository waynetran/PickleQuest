import Foundation

/// Manages authentic pickleball doubles scoring with side-out rules.
///
/// Doubles scoring:
/// - Only the serving team can score
/// - Both players serve before side-out (Server 1 faults → Server 2; Server 2 faults → side-out)
/// - Game starts "0-0-2" (only Server 2 serves first)
/// - Three-number format: "serving team score - receiving team score - server number"
/// - Win at 11 points, must win by 2
struct DoublesScoreTracker: Sendable {
    private(set) var teamAScore: Int = 0  // team A = player's team
    private(set) var teamBScore: Int = 0  // team B = opponent's team
    private(set) var servingTeam: MatchSide = .player
    private(set) var serverNumber: Int = 2  // starts at 2 per doubles rules

    var scoreDisplay: String {
        let servingScore = servingTeam == .player ? teamAScore : teamBScore
        let receivingScore = servingTeam == .player ? teamBScore : teamAScore
        return "\(servingScore)-\(receivingScore)-\(serverNumber)"
    }

    var playerScore: Int { teamAScore }
    var opponentScore: Int { teamBScore }

    var isGameOver: Bool {
        let maxScore = max(teamAScore, teamBScore)
        let minScore = min(teamAScore, teamBScore)
        return maxScore >= GameConstants.Match.defaultPointsToWin && (maxScore - minScore) >= 2
            || maxScore >= GameConstants.Match.maxPoints
    }

    var winnerSide: MatchSide? {
        guard isGameOver else { return nil }
        return teamAScore > teamBScore ? .player : .opponent
    }

    /// Record a rally result. Returns the outcome of the point.
    mutating func recordPoint(winnerIsServingTeam: Bool) -> DoublesPointOutcome {
        if winnerIsServingTeam {
            // Serving team scores
            if servingTeam == .player {
                teamAScore += 1
            } else {
                teamBScore += 1
            }
            return .scored(servingTeam: servingTeam, serverNumber: serverNumber)
        } else {
            // Receiving team wins rally → server rotation or side-out
            if serverNumber == 1 {
                // Server 1 done → Server 2 serves
                serverNumber = 2
                return .serverRotation(servingTeam: servingTeam, newServerNumber: 2)
            } else {
                // Server 2 done → side-out
                let oldServingTeam = servingTeam
                servingTeam = servingTeam == .player ? .opponent : .player
                serverNumber = 1
                return .sideOut(newServingTeam: servingTeam, previousServingTeam: oldServingTeam)
            }
        }
    }

    /// Reset for a new game within a match.
    mutating func resetForNewGame() {
        teamAScore = 0
        teamBScore = 0
        servingTeam = .player
        serverNumber = GameConstants.Doubles.startServerNumber
    }
}

enum DoublesPointOutcome: Sendable {
    case scored(servingTeam: MatchSide, serverNumber: Int)
    case serverRotation(servingTeam: MatchSide, newServerNumber: Int)
    case sideOut(newServingTeam: MatchSide, previousServingTeam: MatchSide)
}
