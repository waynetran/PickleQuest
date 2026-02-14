import Testing
import Foundation
@testable import PickleQuest

@Suite("DUPR Calculator Tests")
struct DUPRCalculatorTests {

    // MARK: - Expected Score

    @Test("Equal ratings produce 0.5 expected score")
    func equalRatingsExpectedScore() {
        let expected = DUPRCalculator.expectedScore(playerRating: 4.0, opponentRating: 4.0)
        #expect(abs(expected - 0.5) < 0.001)
    }

    @Test("Higher rated player has expected score > 0.5")
    func higherRatedPlayerExpectedScore() {
        let expected = DUPRCalculator.expectedScore(playerRating: 5.0, opponentRating: 4.0)
        #expect(expected > 0.5)
        #expect(expected < 1.0)
    }

    @Test("Lower rated player has expected score < 0.5")
    func lowerRatedPlayerExpectedScore() {
        let expected = DUPRCalculator.expectedScore(playerRating: 3.0, opponentRating: 4.0)
        #expect(expected < 0.5)
        #expect(expected > 0.0)
    }

    @Test("Expected scores are symmetric")
    func expectedScoresSymmetric() {
        let highExpected = DUPRCalculator.expectedScore(playerRating: 5.0, opponentRating: 4.0)
        let lowExpected = DUPRCalculator.expectedScore(playerRating: 4.0, opponentRating: 5.0)
        #expect(abs(highExpected + lowExpected - 1.0) < 0.001)
    }

    // MARK: - Actual Score (Margin of Victory)

    @Test("Blowout win produces high actual score")
    func blowoutWinActualScore() {
        let actual = DUPRCalculator.actualScore(playerPoints: 11, opponentPoints: 2, pointsToWin: 11)
        #expect(actual > 0.85)
        #expect(actual <= 1.0)
    }

    @Test("Close win produces moderate actual score above 0.5")
    func closeWinActualScore() {
        let actual = DUPRCalculator.actualScore(playerPoints: 11, opponentPoints: 9, pointsToWin: 11)
        #expect(actual > 0.5)
        #expect(actual < 0.75)
    }

    @Test("Close loss produces moderate actual score below 0.5")
    func closeLossActualScore() {
        let actual = DUPRCalculator.actualScore(playerPoints: 9, opponentPoints: 11, pointsToWin: 11)
        #expect(actual < 0.5)
        #expect(actual > 0.25)
    }

    @Test("Blowout loss produces low actual score")
    func blowoutLossActualScore() {
        let actual = DUPRCalculator.actualScore(playerPoints: 2, opponentPoints: 11, pointsToWin: 11)
        #expect(actual < 0.15)
        #expect(actual >= 0.0)
    }

    @Test("Actual scores are symmetric")
    func actualScoresSymmetric() {
        let winScore = DUPRCalculator.actualScore(playerPoints: 11, opponentPoints: 5, pointsToWin: 11)
        let lossScore = DUPRCalculator.actualScore(playerPoints: 5, opponentPoints: 11, pointsToWin: 11)
        #expect(abs(winScore + lossScore - 1.0) < 0.001)
    }

    // MARK: - Rating Change Scenarios

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

    @Test("Close loss to stronger opponent can gain rating")
    func closeLossToStrongerCanGain() {
        // With a 1.5 DUPR gap, expected score is low (~0.30).
        // A close 9-11 loss gives actual ~0.37, which exceeds expected → gain.
        let change = DUPRCalculator.calculateRatingChange(
            playerRating: 3.0, opponentRating: 4.5,
            playerPoints: 9, opponentPoints: 11, pointsToWin: 11,
            kFactor: 64.0
        )
        #expect(change > 0)
    }

    @Test("Blowout loss to weaker opponent loses significant rating")
    func blowoutLossToWeakerLosesBig() {
        let change = DUPRCalculator.calculateRatingChange(
            playerRating: 5.0, opponentRating: 3.5,
            playerPoints: 2, opponentPoints: 11, pointsToWin: 11,
            kFactor: 32.0
        )
        #expect(change < -0.05)
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
        #expect(DUPRCalculator.shouldAutoUnrate(playerRating: 3.0, opponentRating: 4.5))
        #expect(DUPRCalculator.shouldAutoUnrate(playerRating: 5.0, opponentRating: 3.5))
    }

    @Test("Small rating gap does not auto-unrate")
    func noAutoUnrateSmallGap() {
        #expect(!DUPRCalculator.shouldAutoUnrate(playerRating: 4.0, opponentRating: 4.5))
        #expect(!DUPRCalculator.shouldAutoUnrate(playerRating: 4.0, opponentRating: 4.0))
    }

    @Test("Exactly 1.0 gap does not auto-unrate")
    func exactGapNoAutoUnrate() {
        #expect(!DUPRCalculator.shouldAutoUnrate(playerRating: 3.0, opponentRating: 4.0))
    }

    // MARK: - Edge Cases

    @Test("Zero-zero score returns 0.5 actual score")
    func zeroZeroScore() {
        let actual = DUPRCalculator.actualScore(playerPoints: 0, opponentPoints: 0, pointsToWin: 11)
        #expect(actual == 0.5)
    }

    @Test("Rating change is bounded by sensible values")
    func ratingChangeBounded() {
        // Even with max K-factor and max margin, change should be reasonable
        let change = DUPRCalculator.calculateRatingChange(
            playerRating: 3.0, opponentRating: 3.0,
            playerPoints: 11, opponentPoints: 0, pointsToWin: 11,
            kFactor: 64.0
        )
        #expect(abs(change) < 1.0)
    }
}
