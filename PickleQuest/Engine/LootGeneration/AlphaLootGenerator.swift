import Foundation

enum AlphaLootGenerator {
    /// Generate boss-quality loot: 1 legendary + 2 epic, all with abilities.
    static func generateAlphaLoot() -> [Equipment] {
        let generator = LootGenerator()
        var drops: [Equipment] = []

        // 1 guaranteed legendary
        drops.append(generator.generateEquipment(rarity: .legendary))

        // 2 guaranteed epic
        for _ in 0..<2 {
            drops.append(generator.generateEquipment(rarity: .epic))
        }

        return drops
    }
}
