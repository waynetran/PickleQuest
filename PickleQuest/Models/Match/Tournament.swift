import Foundation

struct Tournament: Identifiable, Sendable {
    let id: UUID
    let name: String
    let courtID: UUID
    let matchType: MatchType
    let bracketSize: Int
    var status: TournamentStatus
    let rewards: TournamentRewards
    var bracket: TournamentBracket

    init(
        id: UUID = UUID(),
        name: String,
        courtID: UUID,
        matchType: MatchType,
        bracketSize: Int = GameConstants.Tournament.bracketSize,
        status: TournamentStatus = .notStarted,
        rewards: TournamentRewards = .standard,
        bracket: TournamentBracket
    ) {
        self.id = id
        self.name = name
        self.courtID = courtID
        self.matchType = matchType
        self.bracketSize = bracketSize
        self.status = status
        self.rewards = rewards
        self.bracket = bracket
    }
}

enum TournamentStatus: String, Sendable {
    case notStarted
    case inProgress
    case completed
}

struct TournamentBracket: Sendable {
    var rounds: [[TournamentMatch]]  // rounds[0] = semis, rounds[1] = final

    var currentRound: Int {
        for (index, round) in rounds.enumerated() {
            if round.contains(where: { $0.winner == nil }) {
                return index
            }
        }
        return rounds.count - 1
    }

    var isComplete: Bool {
        rounds.last?.allSatisfy { $0.winner != nil } ?? false
    }

    var champion: TournamentSeed? {
        rounds.last?.first?.winner
    }
}

struct TournamentMatch: Identifiable, Sendable {
    let id: UUID
    let seed1: TournamentSeed
    let seed2: TournamentSeed
    var winner: TournamentSeed?
    var scoreString: String?
    var isPlayerMatch: Bool {
        seed1.isPlayer || seed2.isPlayer
    }

    init(
        id: UUID = UUID(),
        seed1: TournamentSeed,
        seed2: TournamentSeed,
        winner: TournamentSeed? = nil,
        scoreString: String? = nil
    ) {
        self.id = id
        self.seed1 = seed1
        self.seed2 = seed2
        self.winner = winner
        self.scoreString = scoreString
    }
}

struct TournamentSeed: Identifiable, Sendable, Equatable {
    let id: UUID
    let seedNumber: Int
    let npc1: NPC
    let npc2: NPC?  // doubles partner
    let isPlayer: Bool

    var displayName: String {
        if let npc2 {
            return "\(npc1.name) & \(npc2.name)"
        }
        return npc1.name
    }

    var averageDUPR: Double {
        if let npc2 {
            return (npc1.duprRating + npc2.duprRating) / 2.0
        }
        return npc1.duprRating
    }

    static func == (lhs: TournamentSeed, rhs: TournamentSeed) -> Bool {
        lhs.id == rhs.id
    }
}

struct TournamentRewards: Sendable {
    let xpMultiplier: Double
    let coinMultiplier: Double
    let winnerLegendaryCount: Int
    let winnerEpicCount: Int
    let participationLootCount: Int

    static let standard = TournamentRewards(
        xpMultiplier: GameConstants.Tournament.xpMultiplier,
        coinMultiplier: GameConstants.Tournament.coinMultiplier,
        winnerLegendaryCount: GameConstants.Tournament.winnerLegendaryCount,
        winnerEpicCount: GameConstants.Tournament.winnerEpicCount,
        participationLootCount: GameConstants.Tournament.participationLootCount
    )
}
