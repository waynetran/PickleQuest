import Foundation

struct DUPRProfile: Codable, Equatable, Sendable {
    var rating: Double
    var ratedMatchCount: Int
    var uniqueOpponentIDs: Set<UUID>
    var lastRatedMatchDate: Date?

    /// True once the player has completed at least one rated match.
    var hasRating: Bool {
        ratedMatchCount > 0
    }

    var reliability: Double {
        DUPRCalculator.computeReliability(profile: self)
    }

    var kFactor: Double {
        DUPRCalculator.kFactor(forReliability: reliability)
    }

    mutating func recordRatedMatch(opponentID: UUID, ratingChange: Double, date: Date = Date()) {
        rating = max(
            GameConstants.DUPRRating.minRating,
            min(GameConstants.DUPRRating.maxRating, rating + ratingChange)
        )
        ratedMatchCount += 1
        uniqueOpponentIDs.insert(opponentID)
        lastRatedMatchDate = date
    }

    static let starter = DUPRProfile(
        rating: GameConstants.DUPRRating.startingRating,
        ratedMatchCount: 0,
        uniqueOpponentIDs: [],
        lastRatedMatchDate: nil
    )
}
