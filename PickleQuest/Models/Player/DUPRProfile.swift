import Foundation

struct DUPRSnapshot: Codable, Equatable, Sendable {
    let date: Date
    let rating: Double
}

struct DUPRProfile: Codable, Equatable, Sendable {
    var rating: Double
    var ratedMatchCount: Int
    var uniqueOpponentIDs: Set<UUID>
    var lastRatedMatchDate: Date?
    var ratingHistory: [DUPRSnapshot] = []

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
        ratingHistory.append(DUPRSnapshot(date: date, rating: rating))
        if ratingHistory.count > 50 {
            ratingHistory.removeFirst(ratingHistory.count - 50)
        }
    }

    init(rating: Double, ratedMatchCount: Int, uniqueOpponentIDs: Set<UUID>,
         lastRatedMatchDate: Date?, ratingHistory: [DUPRSnapshot] = []) {
        self.rating = rating
        self.ratedMatchCount = ratedMatchCount
        self.uniqueOpponentIDs = uniqueOpponentIDs
        self.lastRatedMatchDate = lastRatedMatchDate
        self.ratingHistory = ratingHistory
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rating = try c.decode(Double.self, forKey: .rating)
        ratedMatchCount = try c.decode(Int.self, forKey: .ratedMatchCount)
        uniqueOpponentIDs = try c.decode(Set<UUID>.self, forKey: .uniqueOpponentIDs)
        lastRatedMatchDate = try c.decodeIfPresent(Date.self, forKey: .lastRatedMatchDate)
        ratingHistory = try c.decodeIfPresent([DUPRSnapshot].self, forKey: .ratingHistory) ?? []
    }

    static let starter = DUPRProfile(
        rating: GameConstants.DUPRRating.startingRating,
        ratedMatchCount: 0,
        uniqueOpponentIDs: [],
        lastRatedMatchDate: nil
    )
}
