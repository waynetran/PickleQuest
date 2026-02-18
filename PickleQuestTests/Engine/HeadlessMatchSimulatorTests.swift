import Testing
import Foundation
@testable import PickleQuest

@Suite("Headless Match Simulator")
struct HeadlessMatchSimulatorTests {

    /// Match completes cleanly: no infinite loops, valid scores, bounded rally count.
    @Test func matchCompletesCleanly() {
        let npc = NPC.practiceOpponent(dupr: 4.0)
        let playerStats = StatProfileLoader.shared.toPlayerStats(dupr: 4.0)
        let sim = HeadlessMatchSimulator(npc: npc, playerStats: playerStats, playerDUPR: 4.0)
        let result = sim.simulateMatch()

        // Match must have a winner
        #expect(result.playerScore > 0 || result.opponentScore > 0)

        // At least one side reached 11+ points
        let maxScore = max(result.playerScore, result.opponentScore)
        #expect(maxScore >= 11)

        // Winner must win by 2 (or sudden death at 15)
        let diff = abs(result.playerScore - result.opponentScore)
        if maxScore < 15 {
            #expect(diff >= 2)
        }

        // Rallies are bounded
        #expect(result.totalRallies > 0)
        #expect(result.totalRallies < 200, "Too many points — possible loop")
    }

    /// Higher DUPR player should win significantly more often.
    @Test func higherDUPRWinsMore() {
        let matchCount = 100

        // Strong player (5.5) vs weak NPC (3.0)
        var strongWins = 0
        for _ in 0..<matchCount {
            let npc = NPC.practiceOpponent(dupr: 3.0)
            let playerStats = StatProfileLoader.shared.toPlayerStats(dupr: 5.5)
            let sim = HeadlessMatchSimulator(npc: npc, playerStats: playerStats, playerDUPR: 5.5)
            let result = sim.simulateMatch()
            if result.winnerSide == .player { strongWins += 1 }
        }

        // Weak player (2.5) vs strong NPC (5.5)
        var weakWins = 0
        for _ in 0..<matchCount {
            let npc = NPC.practiceOpponent(dupr: 5.5)
            let playerStats = StatProfileLoader.shared.toPlayerStats(dupr: 2.5)
            let sim = HeadlessMatchSimulator(npc: npc, playerStats: playerStats, playerDUPR: 2.5)
            let result = sim.simulateMatch()
            if result.winnerSide == .player { weakWins += 1 }
        }

        let strongWinRate = Double(strongWins) / Double(matchCount)
        let weakWinRate = Double(weakWins) / Double(matchCount)

        #expect(strongWinRate > weakWinRate,
                "Strong player (5.5 vs 3.0) win rate \(strongWinRate) should exceed weak player (2.5 vs 5.5) win rate \(weakWinRate)")
        #expect(strongWinRate > 0.5,
                "Strong player should win majority: \(strongWinRate)")
    }

    /// Average rally length should be bounded reasonably.
    /// Note: rallies are shorter than real pickleball because the NPC has a +20 stat boost
    /// (designed to compensate for human joystick advantage in the interactive game).
    /// The simulated player lacks that advantage, creating an effective ~1.5 DUPR gap.
    @Test func rallyLengthIsReasonable() {
        let matchCount = 50
        var totalAvgRally = 0.0

        for _ in 0..<matchCount {
            let npc = NPC.practiceOpponent(dupr: 4.0)
            let playerStats = StatProfileLoader.shared.toPlayerStats(dupr: 4.0)
            let sim = HeadlessMatchSimulator(npc: npc, playerStats: playerStats, playerDUPR: 4.0)
            let result = sim.simulateMatch()
            totalAvgRally += result.avgRallyLength
        }

        let overallAvgRally = totalAvgRally / Double(matchCount)

        #expect(overallAvgRally >= 0.5,
                "Average rally \(overallAvgRally) too short — points ending without any returns")
        #expect(overallAvgRally <= 30.0,
                "Average rally \(overallAvgRally) too long")
    }
}
