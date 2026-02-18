import Foundation

struct MatchHistoryEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let opponentName: String
    let opponentDifficulty: NPCDifficulty
    let opponentDUPR: Double
    let didWin: Bool
    let scoreString: String
    let isRated: Bool
    let duprChange: Double?
    let suprBefore: Double
    let suprAfter: Double
    let repChange: Int
    let xpEarned: Int
    let coinsEarned: Int
    let equipmentBroken: [String] // names of items that broke
    let wasResigned: Bool
    let matchType: MatchType
    let partnerName: String?
    let opponent2Name: String?
    let wagerAmount: Int
    let aces: Int
    let winners: Int
    let unforcedErrors: Int
    let longestRally: Int

    init(
        id: UUID,
        date: Date,
        opponentName: String,
        opponentDifficulty: NPCDifficulty,
        opponentDUPR: Double,
        didWin: Bool,
        scoreString: String,
        isRated: Bool,
        duprChange: Double?,
        suprBefore: Double,
        suprAfter: Double,
        repChange: Int,
        xpEarned: Int,
        coinsEarned: Int,
        equipmentBroken: [String],
        wasResigned: Bool = false,
        matchType: MatchType = .singles,
        partnerName: String? = nil,
        opponent2Name: String? = nil,
        wagerAmount: Int = 0,
        aces: Int = 0,
        winners: Int = 0,
        unforcedErrors: Int = 0,
        longestRally: Int = 0
    ) {
        self.id = id
        self.date = date
        self.opponentName = opponentName
        self.opponentDifficulty = opponentDifficulty
        self.opponentDUPR = opponentDUPR
        self.didWin = didWin
        self.scoreString = scoreString
        self.isRated = isRated
        self.duprChange = duprChange
        self.suprBefore = suprBefore
        self.suprAfter = suprAfter
        self.repChange = repChange
        self.xpEarned = xpEarned
        self.coinsEarned = coinsEarned
        self.equipmentBroken = equipmentBroken
        self.wasResigned = wasResigned
        self.matchType = matchType
        self.partnerName = partnerName
        self.opponent2Name = opponent2Name
        self.wagerAmount = wagerAmount
        self.aces = aces
        self.winners = winners
        self.unforcedErrors = unforcedErrors
        self.longestRally = longestRally
    }

    // MARK: - Codable (backwards-compatible with older saves)

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        opponentName = try c.decode(String.self, forKey: .opponentName)
        opponentDifficulty = try c.decode(NPCDifficulty.self, forKey: .opponentDifficulty)
        opponentDUPR = try c.decode(Double.self, forKey: .opponentDUPR)
        didWin = try c.decode(Bool.self, forKey: .didWin)
        scoreString = try c.decode(String.self, forKey: .scoreString)
        isRated = try c.decode(Bool.self, forKey: .isRated)
        duprChange = try c.decodeIfPresent(Double.self, forKey: .duprChange)
        suprBefore = try c.decode(Double.self, forKey: .suprBefore)
        suprAfter = try c.decode(Double.self, forKey: .suprAfter)
        repChange = try c.decode(Int.self, forKey: .repChange)
        xpEarned = try c.decode(Int.self, forKey: .xpEarned)
        coinsEarned = try c.decode(Int.self, forKey: .coinsEarned)
        equipmentBroken = try c.decode([String].self, forKey: .equipmentBroken)
        wasResigned = try c.decodeIfPresent(Bool.self, forKey: .wasResigned) ?? false
        matchType = try c.decodeIfPresent(MatchType.self, forKey: .matchType) ?? .singles
        partnerName = try c.decodeIfPresent(String.self, forKey: .partnerName)
        opponent2Name = try c.decodeIfPresent(String.self, forKey: .opponent2Name)
        wagerAmount = try c.decodeIfPresent(Int.self, forKey: .wagerAmount) ?? 0
        aces = try c.decodeIfPresent(Int.self, forKey: .aces) ?? 0
        winners = try c.decodeIfPresent(Int.self, forKey: .winners) ?? 0
        unforcedErrors = try c.decodeIfPresent(Int.self, forKey: .unforcedErrors) ?? 0
        longestRally = try c.decodeIfPresent(Int.self, forKey: .longestRally) ?? 0
    }
}
