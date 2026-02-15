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
}
