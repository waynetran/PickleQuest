import Foundation

struct MatchResult: Sendable {
    let didPlayerWin: Bool
    let finalScore: MatchScore
    let gameScores: [MatchScore] // score at end of each game
    let totalPoints: Int
    let playerStats: MatchPlayerStats
    let opponentStats: MatchPlayerStats
    let xpEarned: Int
    let coinsEarned: Int
    let loot: [Equipment]
    let duration: TimeInterval // simulated match duration

    var formattedScore: String {
        gameScores.map { "\($0.playerPoints)-\($0.opponentPoints)" }.joined(separator: ", ")
    }
}

struct MatchPlayerStats: Sendable {
    let aces: Int
    let winners: Int
    let unforcedErrors: Int
    let forcedErrors: Int
    let longestRally: Int
    let averageRallyLength: Double
    let longestStreak: Int
    let finalEnergy: Double
}
