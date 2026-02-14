import Testing
@testable import PickleQuest

@Suite("Momentum Tracker Tests")
struct MomentumTrackerTests {

    @Test("Streaks tracked correctly")
    func streaksTrackedCorrectly() {
        var tracker = MomentumTracker()

        // First point — no streak yet
        let result1 = tracker.recordPoint(winner: .player)
        #expect(result1 == nil)

        // Second point — streak of 2
        let result2 = tracker.recordPoint(winner: .player)
        #expect(result2 == 2)

        // Third point — streak of 3
        let result3 = tracker.recordPoint(winner: .player)
        #expect(result3 == 3)

        // Opponent breaks streak
        let result4 = tracker.recordPoint(winner: .opponent)
        #expect(result4 == nil)
        #expect(tracker.playerStreak == 0)
        #expect(tracker.opponentStreak == 1)
    }

    @Test("Momentum modifier increases with streak")
    func momentumModifierIncreases() {
        var tracker = MomentumTracker()

        // Build a 4-point streak
        for _ in 0..<4 {
            _ = tracker.recordPoint(winner: .player)
        }

        let modifier = tracker.modifier(for: .player)
        #expect(modifier > 0)

        // Opponent should have negative momentum
        let oppModifier = tracker.modifier(for: .opponent)
        #expect(oppModifier < 0)
    }

    @Test("Reset clears streaks")
    func resetClearsStreaks() {
        var tracker = MomentumTracker()
        _ = tracker.recordPoint(winner: .player)
        _ = tracker.recordPoint(winner: .player)

        tracker.resetForNewGame()
        #expect(tracker.playerStreak == 0)
        #expect(tracker.opponentStreak == 0)
    }

    @Test("Longest streak is tracked")
    func longestStreakTracked() {
        var tracker = MomentumTracker()

        // Build a 3-point streak
        for _ in 0..<3 {
            _ = tracker.recordPoint(winner: .player)
        }
        // Break it
        _ = tracker.recordPoint(winner: .opponent)
        // Build a 2-point streak
        for _ in 0..<2 {
            _ = tracker.recordPoint(winner: .player)
        }

        #expect(tracker.playerLongestStreak == 3)
    }
}
