import Foundation

enum AlphaLootGenerator {
    /// Generate boss-quality loot: 3-5 items with elevated rarity.
    /// Guaranteed: 1 legendary + 1 epic. Bonus items roll with higher rare+ chances.
    static func generateAlphaLoot() -> [Equipment] {
        let generator = LootGenerator()
        var drops: [Equipment] = []

        // 1 guaranteed legendary
        drops.append(generator.generateEquipment(rarity: .legendary))

        // 1 guaranteed epic
        drops.append(generator.generateEquipment(rarity: .epic))

        // 1-3 bonus drops with elevated rarity (weighted: 30% epic, 40% rare, 30% uncommon)
        let bonusCount = Int.random(in: 1...3)
        for _ in 0..<bonusCount {
            let roll = Double.random(in: 0..<1)
            let rarity: EquipmentRarity
            if roll < 0.30 {
                rarity = .epic
            } else if roll < 0.70 {
                rarity = .rare
            } else {
                rarity = .uncommon
            }
            drops.append(generator.generateEquipment(rarity: rarity))
        }

        return drops
    }
}
