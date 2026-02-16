import Foundation

actor MockStoreService: StoreService {
    private var storeItems: [StoreItem]
    private var consumableItems: [StoreConsumableItem]
    private let lootGenerator: LootGenerator

    init() {
        let generator = LootGenerator()
        self.lootGenerator = generator
        self.storeItems = generator.generateStoreInventory()
        self.consumableItems = Self.generateConsumableSlots()
    }

    func getStoreInventory() async -> [StoreItem] {
        storeItems
    }

    func refreshStore() async -> [StoreItem] {
        storeItems = lootGenerator.generateStoreInventory()
        consumableItems = Self.generateConsumableSlots()
        return storeItems
    }

    func buyItem(_ itemID: UUID) async -> Equipment? {
        guard let index = storeItems.firstIndex(where: { $0.id == itemID && !$0.isSoldOut }) else {
            return nil
        }
        storeItems[index].isSoldOut = true
        return storeItems[index].equipment
    }

    func getStoreConsumables() async -> [StoreConsumableItem] {
        consumableItems
    }

    func buyConsumable(_ itemID: UUID) async -> Consumable? {
        guard let index = consumableItems.firstIndex(where: { $0.id == itemID && !$0.isSoldOut }) else {
            return nil
        }
        consumableItems[index].isSoldOut = true
        return consumableItems[index].consumable
    }

    func sellItem(_ equipment: Equipment) async -> Int {
        equipment.effectiveSellPrice
    }

    // MARK: - Consumable Pool

    private static let consumablePool: [Consumable] = [
        Consumable(
            id: UUID(), name: "Energy Drink",
            description: "Restores 20% energy during a match.",
            effect: .energyRestore(amount: 20.0), price: 50,
            iconName: "bolt.fill"
        ),
        Consumable(
            id: UUID(), name: "Protein Bar",
            description: "Restores 10% energy during a match.",
            effect: .energyRestore(amount: 10.0), price: 25,
            iconName: "leaf.fill"
        ),
        Consumable(
            id: UUID(), name: "Focus Gummies",
            description: "+5 accuracy for the rest of the match.",
            effect: .statBoost(stat: .accuracy, amount: 5, matchDuration: true), price: 75,
            iconName: "brain.head.profile"
        ),
        Consumable(
            id: UUID(), name: "Stamina Shake",
            description: "Restores 30% energy during a match.",
            effect: .energyRestore(amount: 30.0), price: 150,
            iconName: "cup.and.saucer.fill"
        ),
        Consumable(
            id: UUID(), name: "Lucky Charm",
            description: "+3 clutch for the rest of the match.",
            effect: .statBoost(stat: .clutch, amount: 3, matchDuration: true), price: 200,
            iconName: "sparkles"
        )
    ]

    private static func generateConsumableSlots() -> [StoreConsumableItem] {
        let selected = consumablePool.shuffled().prefix(GameConstants.Store.consumableSlots)
        return selected.map { template in
            // Give each a fresh ID so it's unique per rotation
            let consumable = Consumable(
                id: UUID(), name: template.name,
                description: template.description,
                effect: template.effect, price: template.price,
                iconName: template.iconName
            )
            return StoreConsumableItem(consumable: consumable)
        }
    }
}
