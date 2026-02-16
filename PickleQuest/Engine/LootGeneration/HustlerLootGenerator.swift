import Foundation

enum HustlerLootGenerator {
    /// Generate premium loot for defeating a hustler NPC.
    /// 1 guaranteed epic + 1 guaranteed rare + 1 bonus roll (50/50 epic/rare).
    static func generateHustlerLoot() -> [Equipment] {
        let generator = LootGenerator()
        var drops: [Equipment] = []

        // 1 guaranteed epic
        drops.append(generator.generateEquipment(rarity: .epic))

        // 1 guaranteed rare
        drops.append(generator.generateEquipment(rarity: .rare))

        // 1 bonus roll: 50% epic, 50% rare
        let bonusRarity: EquipmentRarity = Bool.random() ? .epic : .rare
        drops.append(generator.generateEquipment(rarity: bonusRarity))

        return drops
    }
}
