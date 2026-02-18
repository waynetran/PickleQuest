import Testing
import Foundation
@testable import PickleQuest

@Suite("DUPR Calculator Tests")
struct DUPRCalculatorTests {

    // MARK: - Rating Change (Single Game)

    @Test("Win against equal opponent gains rating")
    func winAgainstEqualGainsRating() {
        let change = DUPRCalculator.calculateRatingChange(
            playerRating: 4.0, opponentRating: 4.0,
            playerPoints: 11, opponentPoints: 5, pointsToWin: 11,
            kFactor: 32.0
        )
        #expect(change > 0)
    }

    @Test("Loss against equal opponent loses rating")
    func lossAgainstEqualLosesRating() {
        let change = DUPRCalculator.calculateRatingChange(
            playerRating: 4.0, opponentRating: 4.0,
            playerPoints: 5, opponentPoints: 11, pointsToWin: 11,
            kFactor: 32.0
        )
        #expect(change < 0)
    }

    @Test("Bigger margin of victory produces bigger rating gain")
    func biggerMarginBiggerGain() {
        let closeWin = DUPRCalculator.calculateRatingChange(
            playerRating: 4.0, opponentRating: 4.0,
            playerPoints: 11, opponentPoints: 9, pointsToWin: 11,
            kFactor: 32.0
        )
        let blowoutWin = DUPRCalculator.calculateRatingChange(
            playerRating: 4.0, opponentRating: 4.0,
            playerPoints: 11, opponentPoints: 2, pointsToWin: 11,
            kFactor: 32.0
        )
        #expect(blowoutWin > closeWin)
    }

    @Test("Winning by less than expected loses rating")
    func winByLessThanExpectedLosesRating() {
        // 5.0 vs 3.0: expected margin is huge. Winning 11-10 is way below expected.
        let change = DUPRCalculator.calculateRatingChange(
            playerRating: 5.0, opponentRating: 3.0,
            playerPoints: 11, opponentPoints: 10, pointsToWin: 11,
            kFactor: 32.0
        )
        #expect(change < 0)
    }

    @Test("Losing by less than expected gains rating")
    func losingByLessThanExpectedGainsRating() {
        // 3.0 vs 5.0: expected to lose badly. A close 9-11 loss beats expectations.
        let change = DUPRCalculator.calculateRatingChange(
            playerRating: 3.0, opponentRating: 5.0,
            playerPoints: 9, opponentPoints: 11, pointsToWin: 11,
            kFactor: 32.0
        )
        #expect(change > 0)
    }

    @Test("Higher K-factor produces larger swings")
    func higherKFactorLargerSwings() {
        let lowK = DUPRCalculator.calculateRatingChange(
            playerRating: 4.0, opponentRating: 4.0,
            playerPoints: 11, opponentPoints: 5, pointsToWin: 11,
            kFactor: 16.0
        )
        let highK = DUPRCalculator.calculateRatingChange(
            playerRating: 4.0, opponentRating: 4.0,
            playerPoints: 11, opponentPoints: 5, pointsToWin: 11,
            kFactor: 64.0
        )
        #expect(abs(highK) > abs(lowK))
    }

    @Test("Rating change is bounded by sensible values")
    func ratingChangeBounded() {
        let change = DUPRCalculator.calculateRatingChange(
            playerRating: 3.0, opponentRating: 3.0,
            playerPoints: 11, opponentPoints: 0, pointsToWin: 11,
            kFactor: 64.0
        )
        #expect(abs(change) < 1.0)
    }

    // MARK: - Rating Change (Multi-Game)

    @Test("Multi-game averages performance across all games")
    func multiGameAveragesPerformance() {
        let scores = [
            MatchScore(playerPoints: 11, opponentPoints: 5, playerGames: 1, opponentGames: 0),
            MatchScore(playerPoints: 11, opponentPoints: 8, playerGames: 2, opponentGames: 0)
        ]
        let multiChange = DUPRCalculator.calculateRatingChange(
            playerRating: 4.0, opponentRating: 4.0,
            gameScores: scores, pointsToWin: 11, kFactor: 32.0
        )
        // Average of two wins → positive
        #expect(multiChange > 0)
    }

    @Test("Multi-game split produces smaller change than sweep")
    func multiGameSplitSmallerThanSweep() {
        let sweep = [
            MatchScore(playerPoints: 11, opponentPoints: 5, playerGames: 1, opponentGames: 0),
            MatchScore(playerPoints: 11, opponentPoints: 5, playerGames: 2, opponentGames: 0)
        ]
        let split = [
            MatchScore(playerPoints: 11, opponentPoints: 5, playerGames: 1, opponentGames: 0),
            MatchScore(playerPoints: 5, opponentPoints: 11, playerGames: 1, opponentGames: 1),
            MatchScore(playerPoints: 11, opponentPoints: 5, playerGames: 2, opponentGames: 1)
        ]
        let sweepChange = DUPRCalculator.calculateRatingChange(
            playerRating: 4.0, opponentRating: 4.0,
            gameScores: sweep, pointsToWin: 11, kFactor: 32.0
        )
        let splitChange = DUPRCalculator.calculateRatingChange(
            playerRating: 4.0, opponentRating: 4.0,
            gameScores: split, pointsToWin: 11, kFactor: 32.0
        )
        #expect(sweepChange > splitChange)
    }

    @Test("Empty game scores returns zero")
    func emptyGameScoresReturnsZero() {
        let change = DUPRCalculator.calculateRatingChange(
            playerRating: 4.0, opponentRating: 4.0,
            gameScores: [], pointsToWin: 11, kFactor: 32.0
        )
        #expect(change == 0.0)
    }

    // MARK: - Lopsidedness Discount

    @Test("Lopsided match produces smaller rating change")
    func lopsidedMatchSmallChange() {
        // Equal gap: no discount
        let normalChange = DUPRCalculator.calculateRatingChange(
            playerRating: 4.0, opponentRating: 4.0,
            playerPoints: 11, opponentPoints: 5, pointsToWin: 11,
            kFactor: 32.0
        )
        // 1.0 gap: lopsidedness discount kicks in (threshold is 0.625)
        let lopsidedChange = DUPRCalculator.calculateRatingChange(
            playerRating: 4.0, opponentRating: 3.0,
            playerPoints: 11, opponentPoints: 5, pointsToWin: 11,
            kFactor: 32.0
        )
        #expect(abs(lopsidedChange) < abs(normalChange))
    }

    // MARK: - High-Level Damping

    @Test("High-rated players have dampened rating changes")
    func highLevelDamping() {
        let midLevelChange = DUPRCalculator.calculateRatingChange(
            playerRating: 3.5, opponentRating: 3.5,
            playerPoints: 11, opponentPoints: 5, pointsToWin: 11,
            kFactor: 32.0
        )
        let highLevelChange = DUPRCalculator.calculateRatingChange(
            playerRating: 5.0, opponentRating: 5.0,
            playerPoints: 11, opponentPoints: 5, pointsToWin: 11,
            kFactor: 32.0
        )
        #expect(abs(highLevelChange) < abs(midLevelChange))
    }

    // MARK: - K-Factor Tiers

    @Test("New player gets highest K-factor")
    func newPlayerKFactor() {
        let k = DUPRCalculator.kFactor(forReliability: 0.0)
        #expect(k == GameConstants.DUPRRating.kFactorNew)
    }

    @Test("Developing player gets medium K-factor")
    func developingPlayerKFactor() {
        let k = DUPRCalculator.kFactor(forReliability: 0.5)
        #expect(k == GameConstants.DUPRRating.kFactorDeveloping)
    }

    @Test("Established player gets lowest K-factor")
    func establishedPlayerKFactor() {
        let k = DUPRCalculator.kFactor(forReliability: 0.8)
        #expect(k == GameConstants.DUPRRating.kFactorEstablished)
    }

    // MARK: - Reliability Components

    @Test("Depth reliability scales linearly to cap")
    func depthReliabilityScaling() {
        #expect(DUPRCalculator.depthReliability(matchCount: 0) == 0.0)
        #expect(abs(DUPRCalculator.depthReliability(matchCount: 15) - 0.5) < 0.01)
        #expect(DUPRCalculator.depthReliability(matchCount: 30) == 1.0)
        #expect(DUPRCalculator.depthReliability(matchCount: 100) == 1.0) // capped
    }

    @Test("Breadth reliability scales linearly to cap")
    func breadthReliabilityScaling() {
        #expect(DUPRCalculator.breadthReliability(uniqueOpponents: 0) == 0.0)
        #expect(DUPRCalculator.breadthReliability(uniqueOpponents: 15) == 1.0)
        #expect(DUPRCalculator.breadthReliability(uniqueOpponents: 50) == 1.0) // capped
    }

    @Test("Recency reliability is 1.0 within window")
    func recencyReliabilityFresh() {
        let now = Date()
        let recent = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        let recency = DUPRCalculator.recencyReliability(lastMatchDate: recent, currentDate: now)
        #expect(recency == 1.0)
    }

    @Test("Recency reliability decays after window")
    func recencyReliabilityDecay() {
        let now = Date()
        let old = Calendar.current.date(byAdding: .day, value: -45, to: now)!
        let recency = DUPRCalculator.recencyReliability(lastMatchDate: old, currentDate: now)
        #expect(recency < 1.0)
        #expect(recency > GameConstants.DUPRRating.recencyMinimum)
    }

    @Test("Recency reliability hits minimum at threshold")
    func recencyReliabilityMinimum() {
        let now = Date()
        let veryOld = Calendar.current.date(byAdding: .day, value: -90, to: now)!
        let recency = DUPRCalculator.recencyReliability(lastMatchDate: veryOld, currentDate: now)
        #expect(abs(recency - GameConstants.DUPRRating.recencyMinimum) < 0.01)
    }

    @Test("No match date gives 0 recency")
    func noMatchDateRecency() {
        let recency = DUPRCalculator.recencyReliability(lastMatchDate: nil)
        #expect(recency == 0.0)
    }

    // MARK: - Auto-Unrate

    @Test("Large rating gap triggers auto-unrate")
    func autoUnrateLargeGap() {
        // maxRatedGap is 1.5, so >1.5 triggers auto-unrate
        #expect(DUPRCalculator.shouldAutoUnrate(playerRating: 3.0, opponentRating: 5.0))
        #expect(DUPRCalculator.shouldAutoUnrate(playerRating: 6.0, opponentRating: 4.0))
    }

    @Test("Small rating gap does not auto-unrate")
    func noAutoUnrateSmallGap() {
        #expect(!DUPRCalculator.shouldAutoUnrate(playerRating: 4.0, opponentRating: 4.5))
        #expect(!DUPRCalculator.shouldAutoUnrate(playerRating: 4.0, opponentRating: 4.0))
    }

    @Test("Exactly maxRatedGap does not auto-unrate")
    func exactGapNoAutoUnrate() {
        // 1.5 gap is exactly at the boundary — uses > not >=
        #expect(!DUPRCalculator.shouldAutoUnrate(playerRating: 3.0, opponentRating: 4.5))
    }
}
