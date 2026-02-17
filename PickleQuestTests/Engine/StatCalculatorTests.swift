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

    @Test("Set bonuses apply with 2+ pieces of same set")
    func setBonusesApplyWithTwoPieces() {
        let base = PlayerStats(
            power: 30, accuracy: 30, spin: 30, speed: 30,
            defense: 30, reflexes: 30, positioning: 30,
            clutch: 30, stamina: 30, consistency: 30
        )
        let piece1 = Equipment(
            id: .init(), name: "CK Paddle", slot: .paddle, rarity: .rare,
            statBonuses: [StatBonus(stat: .power, value: 5)],
            setID: "court_king", setName: "Court King",
            ability: nil, sellPrice: 100
        )
        let piece2 = Equipment(
            id: .init(), name: "CK Shirt", slot: .shirt, rarity: .rare,
            statBonuses: [StatBonus(stat: .accuracy, value: 5)],
            setID: "court_king", setName: "Court King",
            ability: nil, sellPrice: 100
        )

        let effective = calculator.effectiveStats(base: base, equipment: [piece1, piece2])
        // 2-piece Court King: +3 power → base 30 + item 5 + set 3 = 38
        #expect(effective.power == 38)
    }

    @Test("No set bonus with only 1 piece")
    func noSetBonusWithOnePiece() {
        let base = PlayerStats(
            power: 30, accuracy: 30, spin: 30, speed: 30,
            defense: 30, reflexes: 30, positioning: 30,
            clutch: 30, stamina: 30, consistency: 30
        )
        let piece1 = Equipment(
            id: .init(), name: "CK Paddle", slot: .paddle, rarity: .rare,
            statBonuses: [StatBonus(stat: .power, value: 5)],
            setID: "court_king", setName: "Court King",
            ability: nil, sellPrice: 100
        )

        let effective = calculator.effectiveStats(base: base, equipment: [piece1])
        // Only item bonus, no set bonus → 30 + 5 = 35
        #expect(effective.power == 35)
    }

    // MARK: - Level Multiplier Tests

    @Test("Level multiplier scales equipment bonuses")
    func levelMultiplierScalesBonuses() {
        let base = PlayerStats(
            power: 20, accuracy: 20, spin: 20, speed: 20,
            defense: 20, reflexes: 20, positioning: 20,
            clutch: 20, stamina: 20, consistency: 20
        )
        let level1Item = Equipment(
            id: .init(), name: "Test", slot: .paddle, rarity: .rare,
            statBonuses: [StatBonus(stat: .accuracy, value: 10)],
            ability: nil, sellPrice: 100, level: 1,
            baseStat: StatBonus(stat: .power, value: 8)
        )
        var level15Item = level1Item
        level15Item.level = 15

        let effectLv1 = calculator.effectiveStats(base: base, equipment: [level1Item])
        let effectLv15 = calculator.effectiveStats(base: base, equipment: [level15Item])

        // Level 15 should give more power than level 1
        #expect(effectLv15.power > effectLv1.power)
        #expect(effectLv15.accuracy > effectLv1.accuracy)
    }

    @Test("Level gate zeroes contribution when equipment level exceeds player level")
    func levelGateZeroesStats() {
        let base = PlayerStats(
            power: 20, accuracy: 20, spin: 20, speed: 20,
            defense: 20, reflexes: 20, positioning: 20,
            clutch: 20, stamina: 20, consistency: 20
        )
        let highLevelItem = Equipment(
            id: .init(), name: "Test", slot: .paddle, rarity: .rare,
            statBonuses: [StatBonus(stat: .accuracy, value: 10)],
            ability: nil, sellPrice: 100, level: 10,
            baseStat: StatBonus(stat: .power, value: 8)
        )

        // Player level 5 < equipment level 10 → item should contribute nothing
        let gated = calculator.effectiveStats(base: base, equipment: [highLevelItem], playerLevel: 5)
        #expect(gated.power == 20) // no bonus applied
        #expect(gated.accuracy == 20)

        // Player level 10 = equipment level 10 → item should work
        let ungated = calculator.effectiveStats(base: base, equipment: [highLevelItem], playerLevel: 10)
        #expect(ungated.power > 20)
        #expect(ungated.accuracy > 20)
    }

    @Test("Default playerLevel of 50 allows all standard equipment")
    func defaultPlayerLevelAllowsAll() {
        let base = PlayerStats.starter
        let item = Equipment(
            id: .init(), name: "Test", slot: .paddle, rarity: .legendary,
            statBonuses: [StatBonus(stat: .accuracy, value: 10)],
            ability: nil, sellPrice: 100, level: 25,
            baseStat: StatBonus(stat: .power, value: 16)
        )

        // Default playerLevel = 50 should allow level 25 legendary
        let effective = calculator.effectiveStats(base: base, equipment: [item])
        #expect(effective.power > base.power)
    }
}
