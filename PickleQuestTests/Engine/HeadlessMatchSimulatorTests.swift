import Testing
import Foundation
@testable import PickleQuest

@Suite("Headless Match Simulator")
struct HeadlessMatchSimulatorTests {

    /// Match completes cleanly: no infinite loops, valid scores, bounded rally count.
    @Test func matchCompletesCleanly() {
        let npc = NPC.headlessOpponent(dupr: 4.0)
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
            let npc = NPC.headlessOpponent(dupr: 3.0)
            let playerStats = StatProfileLoader.shared.toPlayerStats(dupr: 5.5)
            let sim = HeadlessMatchSimulator(npc: npc, playerStats: playerStats, playerDUPR: 5.5)
            let result = sim.simulateMatch()
            if result.winnerSide == .player { strongWins += 1 }
        }

        // Weak player (2.5) vs strong NPC (5.5)
        var weakWins = 0
        for _ in 0..<matchCount {
            let npc = NPC.headlessOpponent(dupr: 5.5)
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

    /// Diagnostic: print detailed stats per DUPR matchup to understand balance.
    @Test func diagnosticBalance() {
        let matchCount = 200
        let duprPairs: [(Double, Double)] = [
            (3.0, 3.0), (4.0, 4.0), (5.0, 5.0),
            (5.5, 3.0), (2.5, 5.5)
        ]

        for (pDUPR, nDUPR) in duprPairs {
            // Verify stats are identical at equal DUPR
            if pDUPR == nDUPR {
                let ps = StatProfileLoader.shared.toPlayerStats(dupr: pDUPR)
                let npc = NPC.headlessOpponent(dupr: nDUPR)
                let ns = npc.stats
                print("Stats at DUPR \(pDUPR): P=[con=\(ps.consistency) foc=\(ps.focus) ref=\(ps.reflexes) acc=\(ps.accuracy) pos=\(ps.positioning) spd=\(ps.speed)] N=[con=\(ns.consistency) foc=\(ns.focus) ref=\(ns.reflexes) acc=\(ns.accuracy) pos=\(ns.positioning) spd=\(ns.speed)]")
            }
            var pWins = 0
            var totalPScore = 0
            var totalNScore = 0
            var totalPErrors = 0
            var totalNErrors = 0
            var totalRally = 0.0
            var totalPAces = 0
            var totalPWinners = 0
            var totalNAces = 0
            var totalNWinners = 0
            // Diagnostic error source breakdown
            var totalPShouldMake = 0
            var totalNShouldMake = 0
            var totalPNet = 0
            var totalNNet = 0
            var totalPOut = 0
            var totalNOut = 0
            var totalPPhysicsOut = 0
            var totalNPhysicsOut = 0
            var totalPOutLong = 0
            var totalNOutLong = 0
            var totalPOutWide = 0
            var totalNOutWide = 0
            var totalPKitchenFault = 0
            var totalNKitchenFault = 0

            for _ in 0..<matchCount {
                let npc = NPC.headlessOpponent(dupr: nDUPR)
                let playerStats = StatProfileLoader.shared.toPlayerStats(dupr: pDUPR)
                let sim = HeadlessMatchSimulator(npc: npc, playerStats: playerStats, playerDUPR: pDUPR)
                let result = sim.simulateMatch()
                if result.winnerSide == .player { pWins += 1 }
                totalPScore += result.playerScore
                totalNScore += result.opponentScore
                totalPErrors += result.playerErrors
                totalNErrors += result.npcErrors
                totalRally += result.avgRallyLength
                totalPAces += result.playerAces
                totalPWinners += result.playerWinners
                totalNAces += result.npcAces
                totalNWinners += result.npcWinners
                totalPShouldMake += result.playerErrorsFromShouldMake
                totalNShouldMake += result.npcErrorsFromShouldMake
                totalPNet += result.playerNetErrors
                totalNNet += result.npcNetErrors
                totalPOut += result.playerOutErrors
                totalNOut += result.npcOutErrors
                totalPPhysicsOut += result.playerPhysicsOut
                totalNPhysicsOut += result.npcPhysicsOut
                totalPOutLong += result.playerOutLong
                totalNOutLong += result.npcOutLong
                totalPOutWide += result.playerOutWide
                totalNOutWide += result.npcOutWide
                totalPKitchenFault += result.playerKitchenFaults
                totalNKitchenFault += result.npcKitchenFaults
            }

            let n = Double(matchCount)
            let f = { (v: Int) in String(format: "%.1f", Double(v)/n) }
            let fp = { (v: Int) in String(format: "%.1f", Double(v)/n*100) }
            print("""
                P\(pDUPR) vs N\(nDUPR): WR=\(fp(pWins))% Score=\(f(totalPScore))-\(f(totalNScore)) Rally=\(String(format: "%.1f", totalRally/n))
                  Errors:  P=\(f(totalPErrors)) N=\(f(totalNErrors))
                  ShouldMake: P=\(f(totalPShouldMake)) N=\(f(totalNShouldMake))
                  Net:     P=\(f(totalPNet)) N=\(f(totalNNet))
                  Out(total): P=\(f(totalPOut)) N=\(f(totalNOut))
                  Physics(L/W): P=\(f(totalPOutLong))/\(f(totalPOutWide)) N=\(f(totalNOutLong))/\(f(totalNOutWide))
                  Kitchen:  P=\(f(totalPKitchenFault)) N=\(f(totalNKitchenFault))
                  Aces:    P=\(f(totalPAces)) N=\(f(totalNAces))
                  Winners: P=\(f(totalPWinners)) N=\(f(totalNWinners))
                """)
        }
    }

    /// Average rally length should be bounded reasonably.
    /// In headless mode, NPC stat boost is disabled so both sides play on equal footing.
    @Test func rallyLengthIsReasonable() {
        let matchCount = 50
        var totalAvgRally = 0.0

        for _ in 0..<matchCount {
            let npc = NPC.headlessOpponent(dupr: 4.0)
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
