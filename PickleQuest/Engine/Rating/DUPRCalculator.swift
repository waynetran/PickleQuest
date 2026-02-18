import Foundation

enum DUPRCalculator {

    // MARK: - Rating Change (Single Game)

    /// Calculate rating change for a single game using margin-based performance.
    ///
    /// Real DUPR rules modeled here:
    /// - 0.1 DUPR gap ≈ 1.2 expected point margin in an 11-point game
    /// - Score matters, not just win/loss: winning by less than expected DECREASES rating
    /// - Losing by less than expected INCREASES rating
    /// - Lopsided matches (gap > 0.625) are discounted
    /// - Higher-rated players (4.0+) have dampened swings
    static func calculateRatingChange(
        playerRating: Double,
        opponentRating: Double,
        playerPoints: Int,
        opponentPoints: Int,
        pointsToWin: Int,
        kFactor: Double
    ) -> Double {
        let C = GameConstants.DUPRRating.self
        let gap = playerRating - opponentRating

        // Expected point margin: 0.1 DUPR gap = 1.2 points, scaled to game length
        let expectedMargin = gap * C.pointsPerDUPRGap * Double(pointsToWin) / 11.0
        let actualMargin = Double(playerPoints - opponentPoints)

        // Performance: how much better/worse than expected, normalized
        let rawPerformance = (actualMargin - expectedMargin) / Double(pointsToWin)
        let performance = tanh(rawPerformance * C.performanceCurve)

        let effectiveK = effectiveKFactor(kFactor: kFactor, playerRating: playerRating, gap: gap)
        return effectiveK * performance / C.ratingChangeDivisor
    }

    // MARK: - Rating Change (Multi-Game)

    /// Calculate rating change across multiple games (e.g., best-of-3).
    /// Averages performance across all games — every game counts, not just the last.
    static func calculateRatingChange(
        playerRating: Double,
        opponentRating: Double,
        gameScores: [MatchScore],
        pointsToWin: Int,
        kFactor: Double
    ) -> Double {
        guard !gameScores.isEmpty else { return 0.0 }

        let C = GameConstants.DUPRRating.self
        let gap = playerRating - opponentRating
        let expectedMargin = gap * C.pointsPerDUPRGap * Double(pointsToWin) / 11.0

        var totalPerformance = 0.0
        for score in gameScores {
            let actualMargin = Double(score.playerPoints - score.opponentPoints)
            let rawPerf = (actualMargin - expectedMargin) / Double(pointsToWin)
            totalPerformance += tanh(rawPerf * C.performanceCurve)
        }
        let avgPerformance = totalPerformance / Double(gameScores.count)

        let effectiveK = effectiveKFactor(kFactor: kFactor, playerRating: playerRating, gap: gap)
        return effectiveK * avgPerformance / C.ratingChangeDivisor
    }

    // MARK: - K-Factor

    /// Effective K-factor after applying lopsidedness discount and high-level damping.
    private static func effectiveKFactor(kFactor: Double, playerRating: Double, gap: Double) -> Double {
        let C = GameConstants.DUPRRating.self
        var k = kFactor

        // Lopsidedness discount: graduated reduction above 0.625 gap
        let absGap = abs(gap)
        if absGap > C.lopsidedGapThreshold {
            let discountRange = C.maxRatedGap - C.lopsidedGapThreshold
            if discountRange > 0 {
                let discountProgress = min(1.0, (absGap - C.lopsidedGapThreshold) / discountRange)
                let discount = 1.0 - discountProgress * (1.0 - C.lopsidedDiscountFloor)
                k *= discount
            }
        }

        // High-level convergence: dampened swings at 4.0+
        if playerRating >= C.highLevelThreshold {
            k *= C.highLevelDamping
        }

        return k
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

    // MARK: - Reliability

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

    // MARK: - Auto-Unrate

    /// Whether a match should be auto-unrated due to rating gap.
    static func shouldAutoUnrate(playerRating: Double, opponentRating: Double) -> Bool {
        abs(playerRating - opponentRating) > GameConstants.DUPRRating.maxRatedGap
    }
}
