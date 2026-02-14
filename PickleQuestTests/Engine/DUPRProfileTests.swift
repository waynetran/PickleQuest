import Testing
import Foundation
@testable import PickleQuest

@Suite("DUPR Profile Tests")
struct DUPRProfileTests {

    // MARK: - Starting State

    @Test("Starter profile has correct defaults")
    func starterDefaults() {
        let profile = DUPRProfile.starter
        #expect(profile.rating == GameConstants.DUPRRating.startingRating)
        #expect(profile.ratedMatchCount == 0)
        #expect(profile.uniqueOpponentIDs.isEmpty)
        #expect(profile.lastRatedMatchDate == nil)
    }

    @Test("Starter profile has zero reliability")
    func starterReliability() {
        let profile = DUPRProfile.starter
        #expect(profile.reliability == 0.0)
    }

    @Test("Starter profile uses highest K-factor")
    func starterKFactor() {
        let profile = DUPRProfile.starter
        #expect(profile.kFactor == GameConstants.DUPRRating.kFactorNew)
    }

    // MARK: - Recording Matches

    @Test("Starter profile is not rated")
    func starterNotRated() {
        let profile = DUPRProfile.starter
        #expect(!profile.hasRating)
    }

    @Test("Recording a match updates all profile fields")
    func recordMatchUpdatesFields() {
        var profile = DUPRProfile.starter
        let opponentID = UUID()
        let date = Date()

        profile.recordRatedMatch(opponentID: opponentID, ratingChange: 0.10, date: date)

        #expect(profile.rating == 2.10)
        #expect(profile.hasRating)
        #expect(profile.ratedMatchCount == 1)
        #expect(profile.uniqueOpponentIDs.contains(opponentID))
        #expect(profile.lastRatedMatchDate == date)
    }

    @Test("Rating cannot go below minimum")
    func ratingFloor() {
        var profile = DUPRProfile.starter
        profile.recordRatedMatch(opponentID: UUID(), ratingChange: -5.0)
        #expect(profile.rating == GameConstants.DUPRRating.minRating)
    }

    @Test("Rating cannot exceed maximum")
    func ratingCeiling() {
        var profile = DUPRProfile(
            rating: 7.5,
            ratedMatchCount: 50,
            uniqueOpponentIDs: [],
            lastRatedMatchDate: Date()
        )
        profile.recordRatedMatch(opponentID: UUID(), ratingChange: 2.0)
        #expect(profile.rating == GameConstants.DUPRRating.maxRating)
    }

    @Test("Unique opponents tracked correctly")
    func uniqueOpponentsTracked() {
        var profile = DUPRProfile.starter
        let opponent1 = UUID()
        let opponent2 = UUID()

        profile.recordRatedMatch(opponentID: opponent1, ratingChange: 0.05)
        profile.recordRatedMatch(opponentID: opponent1, ratingChange: 0.05) // same opponent
        profile.recordRatedMatch(opponentID: opponent2, ratingChange: 0.05)

        #expect(profile.ratedMatchCount == 3)
        #expect(profile.uniqueOpponentIDs.count == 2)
    }

    // MARK: - K-Factor Tier Transitions

    @Test("K-factor transitions as reliability increases")
    func kFactorTransitions() {
        var profile = DUPRProfile.starter
        let now = Date()

        // Play matches to build reliability
        for i in 0..<30 {
            let opponentID = UUID()
            profile.recordRatedMatch(
                opponentID: opponentID,
                ratingChange: 0.01,
                date: Calendar.current.date(byAdding: .day, value: -i, to: now) ?? now
            )
        }

        // With 30 matches, 30 unique opponents, recent match → high reliability
        let reliability = DUPRCalculator.computeReliability(profile: profile, currentDate: now)
        #expect(reliability > 0.7)
        #expect(profile.kFactor == GameConstants.DUPRRating.kFactorEstablished)
    }

    // MARK: - Recency Decay

    @Test("Reliability decreases when no recent matches")
    func reliabilityDecaysWithTime() {
        let now = Date()
        let oldDate = Calendar.current.date(byAdding: .day, value: -60, to: now)!

        var profile = DUPRProfile(
            rating: 4.0,
            ratedMatchCount: 30,
            uniqueOpponentIDs: Set((0..<15).map { _ in UUID() }),
            lastRatedMatchDate: oldDate
        )

        let reliabilityOld = DUPRCalculator.computeReliability(profile: profile, currentDate: now)

        // Play a new match → recency improves
        profile.recordRatedMatch(opponentID: UUID(), ratingChange: 0.0, date: now)
        let reliabilityNew = DUPRCalculator.computeReliability(profile: profile, currentDate: now)

        #expect(reliabilityNew > reliabilityOld)
    }

    // MARK: - Rating Progression Simulation

    @Test("Player rating converges after many matches")
    func ratingConvergesOverTime() {
        var profile = DUPRProfile.starter
        let now = Date()

        // Simulate 30 matches where player wins most (7/10 avg)
        for i in 0..<30 {
            let matchDate = Calendar.current.date(byAdding: .hour, value: -i, to: now)!
            let opponentRating = 3.5
            let didWin = i % 10 < 7 // 70% win rate

            let change = DUPRCalculator.calculateRatingChange(
                playerRating: profile.rating,
                opponentRating: opponentRating,
                playerPoints: didWin ? 11 : 7,
                opponentPoints: didWin ? 7 : 11,
                pointsToWin: 11,
                kFactor: profile.kFactor
            )

            profile.recordRatedMatch(opponentID: UUID(), ratingChange: change, date: matchDate)
        }

        // After 30 matches with positive win rate, rating should increase
        #expect(profile.rating > GameConstants.DUPRRating.startingRating)
        // K-factor should have dropped as reliability increased
        #expect(profile.kFactor < GameConstants.DUPRRating.kFactorNew)
    }
}
