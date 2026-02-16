import Foundation
import Testing
@testable import PickleQuest

@Suite("WagerDecision Tests")
struct WagerDecisionTests {

    // MARK: - Regular NPC Tests

    @Test("Free match always accepted for regular NPC")
    func freeMatchAccepted() {
        let npc = makeRegularNPC(duprRating: 4.0)
        let result = WagerDecision.evaluate(
            npc: npc, wagerAmount: 0, playerSUPR: 5.0, consecutivePlayerWins: 0
        )
        if case .accepted(let amount) = result {
            #expect(amount == 0)
        } else {
            Issue.record("Expected accepted, got rejected")
        }
    }

    @Test("Regular NPC accepts wager when SUPR is close")
    func regularAcceptsCloseRating() {
        let npc = makeRegularNPC(duprRating: 4.0)
        let result = WagerDecision.evaluate(
            npc: npc, wagerAmount: 100, playerSUPR: 4.2, consecutivePlayerWins: 0
        )
        if case .accepted(let amount) = result {
            #expect(amount == 100)
        } else {
            Issue.record("Expected accepted")
        }
    }

    @Test("Regular NPC rejects after 3 consecutive losses")
    func regularRejectsAfterMaxLosses() {
        let npc = makeRegularNPC(duprRating: 4.0)
        let result = WagerDecision.evaluate(
            npc: npc, wagerAmount: 100, playerSUPR: 4.0, consecutivePlayerWins: 3
        )
        if case .rejected = result {
            // Expected
        } else {
            Issue.record("Expected rejected after max consecutive losses")
        }
    }

    @Test("Regular NPC rejects when much weaker than player")
    func regularRejectsWeaker() {
        let npc = makeRegularNPC(duprRating: 3.0)
        let result = WagerDecision.evaluate(
            npc: npc, wagerAmount: 100, playerSUPR: 4.0, consecutivePlayerWins: 0
        )
        if case .rejected = result {
            // Expected — NPC is 1.0 below player, threshold is 0.5
        } else {
            Issue.record("Expected rejected when NPC is much weaker")
        }
    }

    @Test("Free match still accepted even after max consecutive losses")
    func freeMatchAcceptedDespiteLosses() {
        let npc = makeRegularNPC(duprRating: 4.0)
        let result = WagerDecision.evaluate(
            npc: npc, wagerAmount: 0, playerSUPR: 4.0, consecutivePlayerWins: 5
        )
        if case .accepted(let amount) = result {
            #expect(amount == 0)
        } else {
            Issue.record("Free match should always be accepted")
        }
    }

    // MARK: - Hustler NPC Tests

    @Test("Hustler forces their own wager amount")
    func hustlerForcesWager() {
        let hustler = makeHustlerNPC(duprRating: 4.5, baseWager: 500)
        let result = WagerDecision.evaluate(
            npc: hustler, wagerAmount: 100, playerSUPR: 4.0, consecutivePlayerWins: 0
        )
        if case .accepted(let amount) = result {
            #expect(amount == 500)
        } else {
            Issue.record("Expected hustler to force their wager")
        }
    }

    @Test("Hustler rejects when player SUPR exceeds threshold")
    func hustlerRejectsStrongPlayer() {
        let hustler = makeHustlerNPC(duprRating: 4.0, baseWager: 500)
        let result = WagerDecision.evaluate(
            npc: hustler, wagerAmount: 0, playerSUPR: 4.5, consecutivePlayerWins: 0
        )
        if case .rejected = result {
            // Expected — gap equals threshold
        } else {
            Issue.record("Expected hustler to reject strong player")
        }
    }

    @Test("Hustler accepts when player SUPR is below threshold")
    func hustlerAcceptsWeakerPlayer() {
        let hustler = makeHustlerNPC(duprRating: 4.5, baseWager: 300)
        let result = WagerDecision.evaluate(
            npc: hustler, wagerAmount: 0, playerSUPR: 4.2, consecutivePlayerWins: 0
        )
        if case .accepted(let amount) = result {
            #expect(amount == 300)
        } else {
            Issue.record("Expected hustler to accept weaker player")
        }
    }

    // MARK: - NPC Purse Tests

    @Test("Regular NPC rejects wager exceeding their purse")
    func regularRejectsOverPurse() {
        let npc = makeRegularNPC(duprRating: 4.0)
        let result = WagerDecision.evaluate(
            npc: npc, wagerAmount: 100, playerSUPR: 4.0, consecutivePlayerWins: 0, npcPurse: 50
        )
        if case .rejected = result {
            // Expected — NPC only has 50 coins
        } else {
            Issue.record("Expected rejected when wager exceeds NPC purse")
        }
    }

    @Test("Regular NPC accepts wager within their purse")
    func regularAcceptsWithinPurse() {
        let npc = makeRegularNPC(duprRating: 4.0)
        let result = WagerDecision.evaluate(
            npc: npc, wagerAmount: 50, playerSUPR: 4.0, consecutivePlayerWins: 0, npcPurse: 100
        )
        if case .accepted(let amount) = result {
            #expect(amount == 50)
        } else {
            Issue.record("Expected accepted when wager within NPC purse")
        }
    }

    @Test("Hustler caps wager at purse amount")
    func hustlerCapsWagerAtPurse() {
        let hustler = makeHustlerNPC(duprRating: 4.5, baseWager: 500)
        let result = WagerDecision.evaluate(
            npc: hustler, wagerAmount: 0, playerSUPR: 4.0, consecutivePlayerWins: 0, npcPurse: 200
        )
        if case .accepted(let amount) = result {
            #expect(amount == 200)
        } else {
            Issue.record("Expected hustler to cap wager at purse")
        }
    }

    @Test("Hustler rejects when purse is zero")
    func hustlerRejectsEmptyPurse() {
        let hustler = makeHustlerNPC(duprRating: 4.5, baseWager: 500)
        let result = WagerDecision.evaluate(
            npc: hustler, wagerAmount: 0, playerSUPR: 4.0, consecutivePlayerWins: 0, npcPurse: 0
        )
        if case .rejected = result {
            // Expected — hustler is tapped out
        } else {
            Issue.record("Expected hustler to reject when purse is 0")
        }
    }

    // MARK: - Helpers

    private func makeRegularNPC(duprRating: Double) -> NPC {
        NPC(
            id: UUID(),
            name: "Test NPC",
            title: "Tester",
            difficulty: .intermediate,
            stats: .starter,
            personality: .allRounder,
            dialogue: NPCDialogue(greeting: "", onWin: "", onLose: "", taunt: ""),
            portraitName: "test",
            rewardMultiplier: 1.0,
            duprRating: duprRating
        )
    }

    private func makeHustlerNPC(duprRating: Double, baseWager: Int) -> NPC {
        NPC(
            id: UUID(),
            name: "Test Hustler",
            title: "Hustler",
            difficulty: .expert,
            stats: .starter,
            personality: .aggressive,
            dialogue: NPCDialogue(greeting: "", onWin: "", onLose: "", taunt: ""),
            portraitName: "test",
            rewardMultiplier: 2.0,
            duprRating: duprRating,
            isHustler: true,
            hiddenStats: true,
            baseWagerAmount: baseWager
        )
    }
}
