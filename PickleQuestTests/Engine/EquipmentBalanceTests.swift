import Foundation
import Testing
@testable import PickleQuest

@Suite("Equipment Balance Tests")
struct EquipmentBalanceTests {
    let calculator = StatCalculator()

    // MARK: - Power Budget

    @Test("Full legendary loadout stays within ~0.7 DUPR advantage")
    func fullLegendaryLoadoutWithinBudget() {
        let base = PlayerStats(
            power: 30, accuracy: 30, spin: 30, speed: 30,
            defense: 30, reflexes: 30, positioning: 30,
            clutch: 30, stamina: 30, consistency: 30
        )

        // Minor/Major/Unique trait pools for varied assignment
        let minorTraits: [TraitType] = [.lightfoot, .heavyHitter, .spinArtist, .wallBuilder, .quickHands]
        let majorTraits: [TraitType] = [.rallyGrinder, .courtCoverage, .pressurePlayer, .steadyEddie, .serveSpecialist]
        let uniqueTraits: [TraitType] = [.clutchGene, .ironConstitution, .allRounder]

        // 6 max-level legendary items with varied traits (realistic loadout)
        let items: [Equipment] = (0..<6).map { i in
            let slot = EquipmentSlot.allCases[i % EquipmentSlot.allCases.count]
            let stats = Array(StatType.allCases.suffix(from: i).prefix(3))
            return Equipment(
                id: .init(),
                name: "Legendary \(i)",
                slot: slot,
                rarity: .legendary,
                statBonuses: stats.map { StatBonus(stat: $0, value: 3) },
                traits: [
                    EquipmentTrait(type: minorTraits[i % minorTraits.count], tier: .minor),
                    EquipmentTrait(type: majorTraits[i % majorTraits.count], tier: .major),
                    EquipmentTrait(type: uniqueTraits[i % uniqueTraits.count], tier: .unique)
                ],
                ability: nil,
                sellPrice: 600,
                level: 25,
                baseStat: StatBonus(stat: StatType.allCases[i % StatType.allCases.count], value: 9)
            )
        }

        let effective = calculator.effectiveStats(base: base, equipment: items)

        // Calculate average stat increase
        var totalIncrease = 0
        for stat in StatType.allCases {
            totalIncrease += effective.stat(stat) - base.stat(stat)
        }
        let avgIncrease = Double(totalIncrease) / Double(StatType.allCases.count)

        // Per-stat cap (15) + DR keeps this well under 1.0 DUPR (~16 avg stat increase)
        #expect(avgIncrease <= 14.0, "Avg stat increase \(avgIncrease) exceeds 14 (≈0.85 DUPR)")
    }

    // MARK: - Per-Stat Cap

    @Test("Per-stat cap limits stacked equipment bonuses")
    func perStatCapEnforced() {
        let base = PlayerStats(
            power: 30, accuracy: 30, spin: 30, speed: 30,
            defense: 30, reflexes: 30, positioning: 30,
            clutch: 30, stamina: 30, consistency: 30
        )

        // 6 items all boosting power heavily
        let items: [Equipment] = (0..<6).map { i in
            let slot = EquipmentSlot.allCases[i % EquipmentSlot.allCases.count]
            return Equipment(
                id: .init(),
                name: "Power Stack \(i)",
                slot: slot,
                rarity: .legendary,
                statBonuses: [StatBonus(stat: .power, value: 8)],
                ability: nil,
                sellPrice: 600,
                level: 1,
                baseStat: StatBonus(stat: .power, value: 9)
            )
        }

        let effective = calculator.effectiveStats(base: base, equipment: items)

        // Raw would be 6 * (9 + 8) = 102, but per-stat cap is 15
        // So effective should be base 30 + capped 15 = 45 (linear region, no DR)
        #expect(effective.power == 45, "Power should be capped at base + 15, got \(effective.power)")
    }

    // MARK: - Trait Application

    @Test("Traits modify stats correctly")
    func traitsApplyCorrectly() {
        let base = PlayerStats(
            power: 30, accuracy: 30, spin: 30, speed: 30,
            defense: 30, reflexes: 30, positioning: 30,
            clutch: 30, stamina: 30, consistency: 30
        )

        let item = Equipment(
            id: .init(),
            name: "Lightfoot Shoes",
            slot: .shoes,
            rarity: .rare,
            statBonuses: [],
            traits: [EquipmentTrait(type: .lightfoot, tier: .minor)],
            ability: nil,
            sellPrice: 100,
            baseStat: StatBonus(stat: .speed, value: 5)
        )

        let effective = calculator.effectiveStats(base: base, equipment: [item])

        // Lightfoot: +2 speed, -1 power
        // Speed: base 30 + baseStat 5 + trait 2 = 37
        #expect(effective.speed == 37, "Speed should be 37, got \(effective.speed)")
        // Power: base 30 + trait -1 = capped at 0 minimum bonus → 30 (negative bonus doesn't apply via cap)
        // Actually: rawBonus = 0 (no equip) + 0 (no set) + (-1) (trait) = -1
        // min(-1, 15) = -1, applyDR(base: 30, bonus: -1) — bonus < 0 so guard returns 30
        #expect(effective.power == 30, "Power should stay at 30 (negative trait bonus ignored by DR), got \(effective.power)")
    }

    @Test("AllRounder unique trait boosts all stats")
    func allRounderTraitBoostsAll() {
        let base = PlayerStats(
            power: 30, accuracy: 30, spin: 30, speed: 30,
            defense: 30, reflexes: 30, positioning: 30,
            clutch: 30, stamina: 30, consistency: 30
        )

        let item = Equipment(
            id: .init(),
            name: "All-Rounder Paddle",
            slot: .paddle,
            rarity: .legendary,
            statBonuses: [],
            traits: [EquipmentTrait(type: .allRounder, tier: .unique)],
            ability: nil,
            sellPrice: 600,
            baseStat: StatBonus(stat: .power, value: 9)
        )

        let effective = calculator.effectiveStats(base: base, equipment: [item])

        // All stats should increase by 2 from allRounder trait
        // Power also gets +9 from baseStat: 30 + 9 + 2 = 41
        #expect(effective.power == 41, "Power should be 41, got \(effective.power)")
        // Other stats just get +2 from trait: 30 + 2 = 32
        #expect(effective.accuracy == 32, "Accuracy should be 32, got \(effective.accuracy)")
        #expect(effective.stamina == 32, "Stamina should be 32, got \(effective.stamina)")
    }

    // MARK: - Level Multiplier

    @Test("Level multiplier is 1.24x at max legendary level")
    func levelMultiplierNerfed() {
        var item = Equipment(
            id: .init(),
            name: "Test",
            slot: .paddle,
            rarity: .legendary,
            statBonuses: [],
            ability: nil,
            sellPrice: 100,
            level: 25
        )

        // Level 25: 1.0 + 0.01 * 24 = 1.24
        #expect(abs(item.levelMultiplier - 1.24) < 0.001, "Max legendary multiplier should be 1.24, got \(item.levelMultiplier)")

        item.level = 1
        #expect(item.levelMultiplier == 1.0)
    }

    // MARK: - Backward Compatibility

    @Test("Equipment without traits field decodes with empty traits")
    func backwardCompatDecoding() throws {
        // JSON without "traits" key — simulates old saved data
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Old Paddle",
            "slot": "paddle",
            "rarity": "rare",
            "statBonuses": [{"stat": "power", "value": 5}],
            "sellPrice": 100,
            "condition": 1.0,
            "level": 1
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Equipment.self, from: data)
        #expect(decoded.traits.isEmpty, "Old items without traits should decode with empty array")
        #expect(decoded.name == "Old Paddle")
    }

    // MARK: - Trait Generation

    @Test("Trait generation matches rarity slots")
    func traitGenerationMatchesSlots() {
        for seed in UInt64(0)..<UInt64(30) {
            let generator = LootGenerator(rng: SeededRandomSource(seed: seed))

            let common = generator.generateEquipment(rarity: .common)
            #expect(common.traits.count == 0)

            let uncommon = generator.generateEquipment(rarity: .uncommon)
            #expect(uncommon.traits.count == 0)

            let rare = generator.generateEquipment(rarity: .rare)
            #expect(rare.traits.count == 1)
            #expect(rare.traits[0].tier == .minor)

            let epic = generator.generateEquipment(rarity: .epic)
            #expect(epic.traits.count == 2)
            #expect(epic.traits.contains { $0.tier == .minor })
            #expect(epic.traits.contains { $0.tier == .major })

            let legendary = generator.generateEquipment(rarity: .legendary)
            #expect(legendary.traits.count == 3)
            #expect(legendary.traits.contains { $0.tier == .minor })
            #expect(legendary.traits.contains { $0.tier == .major })
            #expect(legendary.traits.contains { $0.tier == .unique })
        }
    }

    // MARK: - Rarity Budget Sanity

    @Test("Legendary total raw budget is 17")
    func legendaryBudgetIs17() {
        let rarity = EquipmentRarity.legendary
        let total = rarity.baseStatValue + rarity.bonusStatBudget
        #expect(total == 17, "Legendary total should be 17, got \(total)")
    }

    @Test("Common total raw budget is 2")
    func commonBudgetIs2() {
        let rarity = EquipmentRarity.common
        let total = rarity.baseStatValue + rarity.bonusStatBudget
        #expect(total == 2, "Common total should be 2, got \(total)")
    }
}
