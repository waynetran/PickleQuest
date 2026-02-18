import Foundation

enum DevMatchSource: String, Codable, Sendable {
    case interactive
    case headless
}

struct DevMatchLogEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let date: Date
    let source: DevMatchSource
    let playerDUPR: Double
    let opponentDUPR: Double
    let playerScore: Int
    let opponentScore: Int
    let didPlayerWin: Bool
    let totalPoints: Int
    let avgRallyLength: Double
    let playerAces: Int
    let playerWinners: Int
    let playerErrors: Int
    let opponentAces: Int
    let opponentWinners: Int
    let opponentErrors: Int
    let matchDurationSeconds: Double
}
