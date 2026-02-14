import Testing
@testable import PickleQuest

@Suite("Stat Calculator Tests")
struct StatCalculatorTests {
    let calculator = StatCalculator()

    @Test("Equipment bonuses increase stats")
    func equipmentBonusesWork() {
        let base = PlayerStats.starter
        let paddle = Equipment(
            id: .init(),
            name: "Test Paddle",
            slot: .paddle,
            rarity: .uncommon,
            statBonuses: [StatBonus(stat: .power, value: 10)],
            ability: nil,
            sellPrice: 50
        )

        let effective = calculator.effectiveStats(base: base, equipment: [paddle])
        #expect(effective.power > base.power)
    }

    @Test("Diminishing returns cap stats at 99")
    func diminishingReturnsCap() {
        let base = PlayerStats(
            power: 90, accuracy: 90, spin: 90, speed: 90,
            defense: 90, reflexes: 90, positioning: 90,
            clutch: 90, stamina: 90, consistency: 90
        )
        let equipment = Equipment(
            id: .init(),
            name: "Mega Paddle",
            slot: .paddle,
            rarity: .legendary,
            statBonuses: [StatBonus(stat: .power, value: 25)],
            ability: nil,
            sellPrice: 500
        )

        let effective = calculator.effectiveStats(base: base, equipment: [equipment])
        #expect(effective.power <= 99)
    }

    @Test("Fatigue reduces stats at threshold")
    func fatigueReducesStats() {
        let stats = PlayerStats(
            power: 50, accuracy: 50, spin: 50, speed: 50,
            defense: 50, reflexes: 50, positioning: 50,
            clutch: 50, stamina: 50, consistency: 50
        )

        let fatigued = calculator.applyFatigue(stats: stats, energy: 25.0) // severe fatigue
        #expect(fatigued.power < stats.power)
        #expect(fatigued.accuracy < stats.accuracy)
        // Stamina should NOT be reduced by fatigue
        #expect(fatigued.stamina == stats.stamina)
    }

    @Test("No fatigue penalty when energy is high")
    func noFatiguePenaltyWhenFresh() {
        let stats = PlayerStats(
            power: 50, accuracy: 50, spin: 50, speed: 50,
            defense: 50, reflexes: 50, positioning: 50,
            clutch: 50, stamina: 50, consistency: 50
        )

        let result = calculator.applyFatigue(stats: stats, energy: 100.0)
        #expect(result == stats)
    }

    @Test("Momentum modifies stats positively and negatively")
    func momentumModifiesStats() {
        let stats = PlayerStats(
            power: 50, accuracy: 50, spin: 50, speed: 50,
            defense: 50, reflexes: 50, positioning: 50,
            clutch: 50, stamina: 50, consistency: 50
        )

        let boosted = calculator.applyMomentum(stats: stats, modifier: 0.05)
        #expect(boosted.power > stats.power)

        let penalized = calculator.applyMomentum(stats: stats, modifier: -0.05)
        #expect(penalized.power < stats.power)
    }
}
