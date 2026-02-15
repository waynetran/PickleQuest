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
    let wasResigned: Bool
    let duprChange: Double? // nil for unrated matches

    // Doubles fields
    let partnerName: String?
    let opponent2Name: String?
    let teamSynergy: TeamSynergy?
    let isDoubles: Bool

    init(
        didPlayerWin: Bool,
        finalScore: MatchScore,
        gameScores: [MatchScore],
        totalPoints: Int,
        playerStats: MatchPlayerStats,
        opponentStats: MatchPlayerStats,
        xpEarned: Int,
        coinsEarned: Int,
        loot: [Equipment],
        duration: TimeInterval,
        wasResigned: Bool,
        duprChange: Double?,
        partnerName: String? = nil,
        opponent2Name: String? = nil,
        teamSynergy: TeamSynergy? = nil,
        isDoubles: Bool = false
    ) {
        self.didPlayerWin = didPlayerWin
        self.finalScore = finalScore
        self.gameScores = gameScores
        self.totalPoints = totalPoints
        self.playerStats = playerStats
        self.opponentStats = opponentStats
        self.xpEarned = xpEarned
        self.coinsEarned = coinsEarned
        self.loot = loot
        self.duration = duration
        self.wasResigned = wasResigned
        self.duprChange = duprChange
        self.partnerName = partnerName
        self.opponent2Name = opponent2Name
        self.teamSynergy = teamSynergy
        self.isDoubles = isDoubles
    }

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
