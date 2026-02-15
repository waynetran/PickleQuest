import Testing
@testable import PickleQuest

@Suite("LootGenerator Tests")
struct LootGeneratorTests {
    // MARK: - Rarity Distribution

    @Test("Win drops produce exactly winDropCount items")
    func winDropCount() {
        let generator = LootGenerator(rng: SeededRandomSource(seed: 42))
        let loot = generator.generateMatchLoot(didWin: true, opponentDifficulty: .beginner, playerLevel: 1)
        #expect(loot.count == GameConstants.Loot.winDropCount)
    }

    @Test("Loss drops produce 0 or 1 items")
    func lossDropCount() {
        var dropCount = 0
        for seed in UInt64(0)..<UInt64(200) {
            let generator = LootGenerator(rng: SeededRandomSource(seed: seed))
            let loot = generator.generateMatchLoot(didWin: false, opponentDifficulty: .beginner, playerLevel: 1)
            #expect(loot.count <= 1)
            dropCount += loot.count
        }
        // Over 200 trials, ~30% should drop (60 expected, allow wide range)
        #expect(dropCount > 10 && dropCount < 180)
    }

    @Test("Rarity distribution follows expected weights over many rolls")
    func rarityDistribution() {
        var counts: [EquipmentRarity: Int] = [:]
        for seed in UInt64(0)..<UInt64(500) {
            let generator = LootGenerator(rng: SeededRandomSource(seed: seed))
            let loot = generator.generateMatchLoot(didWin: true, opponentDifficulty: .beginner, playerLevel: 1)
            for item in loot {
                counts[item.rarity, default: 0] += 1
            }
        }
        // Common should be the most frequent
        #expect((counts[.common] ?? 0) > (counts[.legendary] ?? 0))
        // Legendary should be rare
        #expect((counts[.legendary] ?? 0) < 30)
    }

    @Test("Higher difficulty boosts rarity")
    func difficultyRarityBoost() {
        var beginnerRareCount = 0
        var masterRareCount = 0
        for seed in UInt64(0)..<UInt64(500) {
            let bgGenerator = LootGenerator(rng: SeededRandomSource(seed: seed))
            let bgLoot = bgGenerator.generateMatchLoot(didWin: true, opponentDifficulty: .beginner, playerLevel: 1)
            beginnerRareCount += bgLoot.filter { $0.rarity >= .rare }.count

            let mGenerator = LootGenerator(rng: SeededRandomSource(seed: seed))
            let mLoot = mGenerator.generateMatchLoot(didWin: true, opponentDifficulty: .master, playerLevel: 1)
            masterRareCount += mLoot.filter { $0.rarity >= .rare }.count
        }
        #expect(masterRareCount >= beginnerRareCount)
    }

    // MARK: - Stat Caps

    @Test("Generated equipment respects rarity stat caps")
    func statCapsRespected() {
        for seed in UInt64(0)..<UInt64(100) {
            let generator = LootGenerator(rng: SeededRandomSource(seed: seed))
            let item = generator.generateEquipment()
            let totalBonus = item.statBonuses.reduce(0) { $0 + $1.value }
            #expect(totalBonus <= item.rarity.maxStatBonus)
            #expect(totalBonus > 0)
        }
    }

    @Test("All stat bonus values are positive")
    func positiveBonuses() {
        for seed in UInt64(0)..<UInt64(100) {
            let generator = LootGenerator(rng: SeededRandomSource(seed: seed))
            let item = generator.generateEquipment()
            for bonus in item.statBonuses {
                #expect(bonus.value > 0)
            }
        }
    }

    // MARK: - Abilities

    @Test("Epic and legendary items have abilities")
    func epicHasAbility() {
        for seed in UInt64(0)..<UInt64(50) {
            let generator = LootGenerator(rng: SeededRandomSource(seed: seed))
            let epic = generator.generateEquipment(rarity: .epic)
            #expect(epic.ability != nil)
            let legendary = generator.generateEquipment(rarity: .legendary)
            #expect(legendary.ability != nil)
        }
    }

    @Test("Common and uncommon items do not have abilities")
    func commonNoAbility() {
        for seed in UInt64(0)..<UInt64(50) {
            let generator = LootGenerator(rng: SeededRandomSource(seed: seed))
            let common = generator.generateEquipment(rarity: .common)
            #expect(common.ability == nil)
            let uncommon = generator.generateEquipment(rarity: .uncommon)
            #expect(uncommon.ability == nil)
        }
    }

    // MARK: - Determinism

    @Test("Same seed produces same equipment")
    func seededDeterminism() {
        let gen1 = LootGenerator(rng: SeededRandomSource(seed: 12345))
        let item1 = gen1.generateEquipment()

        let gen2 = LootGenerator(rng: SeededRandomSource(seed: 12345))
        let item2 = gen2.generateEquipment()

        #expect(item1.name == item2.name)
        #expect(item1.slot == item2.slot)
        #expect(item1.rarity == item2.rarity)
        #expect(item1.statBonuses == item2.statBonuses)
    }

    // MARK: - Store Inventory

    @Test("Store generates correct number of items")
    func storeInventoryCount() {
        let generator = LootGenerator(rng: SeededRandomSource(seed: 42))
        let items = generator.generateStoreInventory()
        #expect(items.count == GameConstants.Store.shopSize)
    }

    @Test("Store items have positive prices")
    func storePrices() {
        let generator = LootGenerator(rng: SeededRandomSource(seed: 42))
        let items = generator.generateStoreInventory()
        for item in items {
            #expect(item.price > 0)
            #expect(!item.isSoldOut)
        }
    }

    // MARK: - Name Generation

    @Test("Generated names are non-empty")
    func namesNonEmpty() {
        for seed in UInt64(0)..<UInt64(50) {
            let generator = LootGenerator(rng: SeededRandomSource(seed: seed))
            let item = generator.generateEquipment()
            #expect(!item.name.isEmpty)
            #expect(item.name.contains(" ")) // prefix + base name
        }
    }

    // MARK: - Flavor Text

    @Test("Generated equipment has non-empty flavor text")
    func flavorTextNonEmpty() {
        for seed in UInt64(0)..<UInt64(50) {
            let generator = LootGenerator(rng: SeededRandomSource(seed: seed))
            let item = generator.generateEquipment()
            #expect(!item.flavorText.isEmpty, "Seed \(seed) produced empty flavor text")
        }
    }
}
