import Foundation

actor MockInventoryService: InventoryService {
    private var inventory: [Equipment]
    private var consumables: [Consumable]

    init() {
        self.inventory = MockInventoryService.createStarterInventory()
        self.consumables = MockInventoryService.createStarterConsumables()
    }

    func getInventory() async -> [Equipment] {
        inventory
    }

    func addEquipment(_ equipment: Equipment) async {
        inventory.append(equipment)
    }

    func addEquipmentBatch(_ equipment: [Equipment]) async {
        inventory.append(contentsOf: equipment)
    }

    func removeEquipment(_ id: UUID) async {
        inventory.removeAll { $0.id == id }
    }

    func removeEquipmentBatch(_ ids: [UUID]) async {
        let idSet = Set(ids)
        inventory.removeAll { idSet.contains($0.id) }
    }

    func getEquipment(by id: UUID) async -> Equipment? {
        inventory.first { $0.id == id }
    }

    func updateEquipmentCondition(_ id: UUID, condition: Double) async {
        guard let index = inventory.firstIndex(where: { $0.id == id }) else { return }
        inventory[index].condition = condition
    }

    func getEquippedItems(for equippedSlots: [EquipmentSlot: UUID]) async -> [Equipment] {
        equippedSlots.values.compactMap { id in
            inventory.first { $0.id == id }
        }
    }

    // MARK: - Consumables

    func getConsumables() async -> [Consumable] {
        consumables
    }

    func addConsumable(_ consumable: Consumable) async {
        consumables.append(consumable)
    }

    func removeConsumable(_ id: UUID) async {
        consumables.removeAll { $0.id == id }
    }

    // MARK: - Starter Equipment

    private static func createStarterInventory() -> [Equipment] {
        [
            Equipment(
                id: UUID(uuidString: "10000001-0000-0000-0000-000000000001")!,
                name: "Beginner's Paddle",
                slot: .paddle,
                rarity: .common,
                statBonuses: [StatBonus(stat: .power, value: 2), StatBonus(stat: .accuracy, value: 1)],
                flavorText: "Every legend starts somewhere. Usually at the free paddle bin.",
                ability: nil,
                sellPrice: 25
            ),
            Equipment(
                id: UUID(uuidString: "10000002-0000-0000-0000-000000000002")!,
                name: "Basic Court Shoes",
                slot: .shoes,
                rarity: .common,
                statBonuses: [StatBonus(stat: .speed, value: 2), StatBonus(stat: .positioning, value: 1)],
                flavorText: "They squeak. That's how you know they're working.",
                ability: nil,
                sellPrice: 20
            ),
            Equipment(
                id: UUID(uuidString: "10000003-0000-0000-0000-000000000003")!,
                name: "Cotton T-Shirt",
                slot: .shirt,
                rarity: .common,
                statBonuses: [StatBonus(stat: .stamina, value: 3)],
                flavorText: "100% cotton, 0% aerodynamics. But hey, it's comfortable.",
                ability: nil,
                sellPrice: 15
            )
        ]
    }

    private static func createStarterConsumables() -> [Consumable] {
        [
            Consumable(
                id: UUID(uuidString: "20000001-0000-0000-0000-000000000001")!,
                name: "Energy Drink",
                description: "Restores 20% energy during a match.",
                effect: .energyRestore(amount: 20.0),
                price: 50,
                iconName: "bolt.fill"
            ),
            Consumable(
                id: UUID(uuidString: "20000002-0000-0000-0000-000000000002")!,
                name: "Protein Bar",
                description: "Restores 10% energy during a match.",
                effect: .energyRestore(amount: 10.0),
                price: 25,
                iconName: "leaf.fill"
            ),
            Consumable(
                id: UUID(uuidString: "20000003-0000-0000-0000-000000000003")!,
                name: "Focus Gummies",
                description: "+5 accuracy for the rest of the match.",
                effect: .statBoost(stat: .accuracy, amount: 5, matchDuration: true),
                price: 75,
                iconName: "brain.head.profile"
            )
        ]
    }
}
