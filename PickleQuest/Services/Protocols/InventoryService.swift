import Foundation

protocol InventoryService: Sendable {
    func getInventory() async -> [Equipment]
    func addEquipment(_ equipment: Equipment) async
    func addEquipmentBatch(_ equipment: [Equipment]) async
    func removeEquipment(_ id: UUID) async
    func removeEquipmentBatch(_ ids: [UUID]) async
    func getEquipment(by id: UUID) async -> Equipment?
    func getEquippedItems(for equippedSlots: [EquipmentSlot: UUID]) async -> [Equipment]
    func updateEquipmentCondition(_ id: UUID, condition: Double) async
    func getConsumables() async -> [Consumable]
    func addConsumable(_ consumable: Consumable) async
    func removeConsumable(_ id: UUID) async
}
