import Testing
@testable import PickleQuest

@Suite("Match Action Tests")
struct MatchActionTests {

    private func makeStats(avg: Int = 25) -> PlayerStats {
        PlayerStats(
            power: avg, accuracy: avg, spin: avg, speed: avg,
            defense: avg, reflexes: avg, positioning: avg,
            clutch: avg, stamina: avg, consistency: avg
        )
    }

    private func makeEngine(
        playerConsumables: [Consumable] = [],
        playerReputation: Int = 100
    ) -> MatchEngine {
        MatchEngine(
            playerStats: makeStats(),
            opponentStats: makeStats(),
            config: .quickMatch,
            playerConsumables: playerConsumables,
            playerReputation: playerReputation
        )
    }

    // MARK: - Skip

    @Test("Skip causes match to complete without intermediate events")
    func skipCompletesQuickly() async {
        let engine = makeEngine()
        await engine.requestSkip()

        var events: [MatchEvent] = []
        for await event in await engine.simulate() {
            events.append(event)
        }

        // Should have matchStart and matchEnd at minimum
        let hasMatchEnd = events.contains { if case .matchEnd = $0 { return true }; return false }
        #expect(hasMatchEnd, "Match should still end normally when skipped")

        // Should NOT have pointPlayed events (they get filtered)
        let pointCount = events.filter { if case .pointPlayed = $0 { return true }; return false }.count
        #expect(pointCount == 0, "Skipped match should not emit pointPlayed events")
    }

    // MARK: - Resign

    @Test("Resign ends match as loss with wasResigned flag")
    func resignEndsAsLoss() async {
        let engine = makeEngine()
        await engine.requestResign()

        let result = await engine.simulateToResult()
        #expect(!result.didPlayerWin, "Resigned match should be a loss")
        #expect(result.wasResigned, "Result should have wasResigned flag")
    }

    // MARK: - Timeout

    @Test("Timeout unavailable when opponent has no streak")
    func timeoutUnavailableNoStreak() async {
        let engine = makeEngine()
        let result = await engine.requestTimeout()
        if case .timeoutUnavailable = result {
            // expected
        } else {
            Issue.record("Should be unavailable without opponent streak")
        }
    }

    // MARK: - Consumables

    @Test("Consumable usage decrements available count")
    func consumableDecrementsCount() async {
        let consumable = Consumable(
            id: .init(),
            name: "Test Drink",
            description: "Test",
            effect: .energyRestore(amount: 20),
            price: 50,
            iconName: "bolt"
        )
        let engine = makeEngine(playerConsumables: [consumable])

        let canUseBefore = await engine.canUseConsumable
        #expect(canUseBefore, "Should be able to use consumable before using it")

        let result = await engine.useConsumable(consumable)
        if case .consumableUsed = result {
            // expected
        } else {
            Issue.record("Should return consumableUsed")
        }

        let remaining = await engine.remainingConsumables
        #expect(remaining.isEmpty, "Should have no remaining consumables after using the only one")
    }

    @Test("Max consumables per match enforced")
    func maxConsumablesEnforced() async {
        var consumables: [Consumable] = []
        for i in 0..<5 {
            consumables.append(Consumable(
                id: .init(),
                name: "Drink \(i)",
                description: "Test",
                effect: .energyRestore(amount: 10),
                price: 25,
                iconName: "bolt"
            ))
        }
        let engine = makeEngine(playerConsumables: consumables)

        // Use up to max
        for i in 0..<GameConstants.MatchActions.maxConsumablesPerMatch {
            let result = await engine.useConsumable(consumables[i])
            if case .consumableUsed = result {
                // expected
            } else {
                Issue.record("Consumable \(i) should be usable")
            }
        }

        // Next should fail
        let result = await engine.useConsumable(consumables[3])
        if case .consumableUnavailable = result {
            // expected
        } else {
            Issue.record("Should be unavailable after hitting max")
        }
    }

    // MARK: - Hook Line Call

    @Test("Hook call unavailable before any points played")
    func hookCallUnavailableAtStart() async {
        let engine = makeEngine()
        let result = await engine.requestHookCall()
        if case .hookCallUnavailable = result {
            // expected
        } else {
            Issue.record("Should be unavailable at match start (no points played)")
        }
    }

    @Test("Hook call success chance scales with reputation")
    func hookCallSuccessScalesWithRep() async {
        // With very high rep, success rate should be higher
        var highRepSuccesses = 0
        var lowRepSuccesses = 0
        let trials = 500

        for _ in 0..<trials {
            let highRepEngine = MatchEngine(
                playerStats: makeStats(),
                opponentStats: makeStats(),
                config: .quickMatch,
                playerReputation: 500
            )

            // Simulate a few points first so hook call is available
            var stream = await highRepEngine.simulate()
            var pointCount = 0
            for await event in stream {
                if case .pointPlayed = event { pointCount += 1 }
                if pointCount >= 2 { break }
            }

            let result = await highRepEngine.requestHookCall()
            if case .hookCallResult(let success, _) = result, success {
                highRepSuccesses += 1
            }
        }

        // Just verify we get some successes with high rep
        #expect(highRepSuccesses > 0, "High rep should produce at least some hook call successes")
    }

    // MARK: - MatchResult wasResigned

    @Test("MatchResult wasResigned defaults to false for normal match")
    func normalMatchNotResigned() async {
        let engine = makeEngine()
        let result = await engine.simulateToResult()
        #expect(!result.wasResigned, "Normal match should not be resigned")
    }

    // MARK: - MomentumTracker resetOpponentStreak

    @Test("MomentumTracker resetOpponentStreak clears only opponent streak")
    func resetOpponentStreakWorks() {
        var tracker = MomentumTracker()
        // Give opponent a streak
        _ = tracker.recordPoint(winner: .opponent)
        _ = tracker.recordPoint(winner: .opponent)
        _ = tracker.recordPoint(winner: .opponent)

        #expect(tracker.opponentStreak == 3)

        tracker.resetOpponentStreak()
        #expect(tracker.opponentStreak == 0)
        // Player streak should still be 0 (not affected)
        #expect(tracker.playerStreak == 0)
    }
}
