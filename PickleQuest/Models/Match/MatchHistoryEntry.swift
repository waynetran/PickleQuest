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
        opponent2Name: String? = nil
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
    }
}
