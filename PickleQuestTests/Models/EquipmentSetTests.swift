import Testing
@testable import PickleQuest

@Suite("EquipmentSet Tests")
struct EquipmentSetTests {
    @Test("All sets have ascending tier requirements")
    func ascendingTierRequirements() {
        for set in EquipmentSet.allSets {
            for i in 1..<set.bonusTiers.count {
                #expect(set.bonusTiers[i].piecesRequired > set.bonusTiers[i - 1].piecesRequired,
                        "Set \(set.name) has non-ascending tier at index \(i)")
            }
        }
    }

    @Test("EquipmentSet.set(for:) lookup works")
    func setLookup() {
        let courtKing = EquipmentSet.set(for: "court_king")
        #expect(courtKing != nil)
        #expect(courtKing?.name == "Court King")

        let speedDemon = EquipmentSet.set(for: "speed_demon")
        #expect(speedDemon != nil)
        #expect(speedDemon?.name == "Speed Demon")

        let nonexistent = EquipmentSet.set(for: "does_not_exist")
        #expect(nonexistent == nil)
    }

    @Test("New player has paddle equipped")
    func newPlayerHasPaddleEquipped() {
        let player = Player.newPlayer(name: "TestPlayer")
        #expect(player.hasPaddleEquipped)
        #expect(player.equippedItems[.paddle] != nil)
        #expect(player.equippedItems[.shoes] != nil)
        #expect(player.equippedItems[.shirt] != nil)
    }

    @Test("Set bonus aggregation works with 2+ matching pieces")
    func setBonusAggregation() {
        let calculator = StatCalculator()

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

        let base = PlayerStats.starter
        let effective = calculator.effectiveStats(base: base, equipment: [piece1, piece2])

        // 2-piece Court King gives +3 power, so power should be higher than just the item bonus
        let effectiveWithoutSet = calculator.effectiveStats(base: base, equipment: [
            Equipment(id: .init(), name: "Solo Paddle", slot: .paddle, rarity: .rare,
                      statBonuses: [StatBonus(stat: .power, value: 5)],
                      ability: nil, sellPrice: 100),
            Equipment(id: .init(), name: "Solo Shirt", slot: .shirt, rarity: .rare,
                      statBonuses: [StatBonus(stat: .accuracy, value: 5)],
                      ability: nil, sellPrice: 100)
        ])

        #expect(effective.power > effectiveWithoutSet.power)
    }

    @Test("No set bonus with only 1 piece")
    func noSetBonusWithOnePiece() {
        let calculator = StatCalculator()

        let piece1 = Equipment(
            id: .init(), name: "CK Paddle", slot: .paddle, rarity: .rare,
            statBonuses: [StatBonus(stat: .power, value: 5)],
            setID: "court_king", setName: "Court King",
            ability: nil, sellPrice: 100
        )

        let base = PlayerStats.starter
        let withSet = calculator.effectiveStats(base: base, equipment: [piece1])

        let withoutSet = calculator.effectiveStats(base: base, equipment: [
            Equipment(id: .init(), name: "Solo Paddle", slot: .paddle, rarity: .rare,
                      statBonuses: [StatBonus(stat: .power, value: 5)],
                      ability: nil, sellPrice: 100)
        ])

        // Same stats — 1 piece shouldn't trigger any set bonus
        #expect(withSet.power == withoutSet.power)
    }

    @Test("All sets in catalog have at least one tier")
    func allSetsHaveTiers() {
        for set in EquipmentSet.allSets {
            #expect(!set.bonusTiers.isEmpty, "Set \(set.name) has no bonus tiers")
        }
    }

    @Test("All sets have unique IDs")
    func uniqueSetIDs() {
        let ids = EquipmentSet.allSets.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
