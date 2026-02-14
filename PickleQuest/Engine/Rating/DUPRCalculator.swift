import Foundation

enum DUPRCalculator {
    /// Expected score (0.0-1.0) based on rating gap, using Elo formula.
    /// A player with a higher rating has expectedScore > 0.5.
    static func expectedScore(playerRating: Double, opponentRating: Double) -> Double {
        let gap = (opponentRating - playerRating) * GameConstants.DUPRRating.duprToEloScale
        return 1.0 / (1.0 + pow(10.0, gap / GameConstants.DUPRRating.eloScaleFactor))
    }

    /// Actual score (0.0-1.0) derived from margin of victory.
    /// Uses the final game score to produce a normalized performance value.
    /// - Blowout win (11-2): ~0.95
    /// - Close win (11-9): ~0.6
    /// - Close loss (9-11): ~0.4
    /// - Blowout loss (2-11): ~0.05
    static func actualScore(playerPoints: Int, opponentPoints: Int, pointsToWin: Int) -> Double {
        let total = playerPoints + opponentPoints
        guard total > 0 else { return 0.5 }

        let margin = Double(playerPoints - opponentPoints)
        let maxMargin = Double(pointsToWin)
        let normalizedMargin = margin / maxMargin // -1.0 to ~1.0

        // Apply sigmoid-like curve for smooth 0-1 mapping
        // tanh maps (-inf, inf) → (-1, 1), we shift to (0, 1)
        let curved = tanh(normalizedMargin * GameConstants.DUPRRating.marginExponent)
        return 0.5 + curved * 0.5
    }

    /// Calculate rating change for a single match.
    /// Returns the raw change value (positive or negative).
    static func calculateRatingChange(
        playerRating: Double,
        opponentRating: Double,
        playerPoints: Int,
        opponentPoints: Int,
        pointsToWin: Int,
        kFactor: Double
    ) -> Double {
        let expected = expectedScore(playerRating: playerRating, opponentRating: opponentRating)
        let actual = actualScore(playerPoints: playerPoints, opponentPoints: opponentPoints, pointsToWin: pointsToWin)
        return kFactor * (actual - expected) / GameConstants.DUPRRating.ratingChangeDivisor
    }

    /// K-factor based on reliability tier.
    static func kFactor(forReliability reliability: Double) -> Double {
        if reliability < 0.3 {
            return GameConstants.DUPRRating.kFactorNew
        } else if reliability < 0.7 {
            return GameConstants.DUPRRating.kFactorDeveloping
        } else {
            return GameConstants.DUPRRating.kFactorEstablished
        }
    }

    /// Compute reliability (0.0-1.0) from profile data.
    static func computeReliability(profile: DUPRProfile, currentDate: Date = Date()) -> Double {
        let depth = depthReliability(matchCount: profile.ratedMatchCount)
        let breadth = breadthReliability(uniqueOpponents: profile.uniqueOpponentIDs.count)
        let recency = recencyReliability(lastMatchDate: profile.lastRatedMatchDate, currentDate: currentDate)

        let weights = GameConstants.DUPRRating.self
        return depth * weights.depthWeight + breadth * weights.breadthWeight + recency * weights.recencyWeight
    }

    /// Depth: rated matches played → 1.0 at depthMax.
    static func depthReliability(matchCount: Int) -> Double {
        min(1.0, Double(matchCount) / Double(GameConstants.DUPRRating.depthMax))
    }

    /// Breadth: unique opponents faced → 1.0 at breadthMax.
    static func breadthReliability(uniqueOpponents: Int) -> Double {
        min(1.0, Double(uniqueOpponents) / Double(GameConstants.DUPRRating.breadthMax))
    }

    /// Recency: days since last rated match.
    /// 1.0 if < recencyFullDays, decays linearly to recencyMinimum at recencyDecayDays.
    static func recencyReliability(lastMatchDate: Date?, currentDate: Date = Date()) -> Double {
        guard let lastDate = lastMatchDate else { return 0.0 }

        let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: currentDate).day ?? 0

        let fullDays = GameConstants.DUPRRating.recencyFullDays
        let decayDays = GameConstants.DUPRRating.recencyDecayDays
        let minimum = GameConstants.DUPRRating.recencyMinimum

        if daysSince <= fullDays {
            return 1.0
        } else if daysSince >= decayDays {
            return minimum
        } else {
            let decayRange = Double(decayDays - fullDays)
            let elapsed = Double(daysSince - fullDays)
            return 1.0 - (1.0 - minimum) * (elapsed / decayRange)
        }
    }

    /// Whether a match should be auto-unrated due to rating gap.
    static func shouldAutoUnrate(playerRating: Double, opponentRating: Double) -> Bool {
        abs(playerRating - opponentRating) > GameConstants.DUPRRating.maxRatedGap
    }
}
