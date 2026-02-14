import Foundation

protocol InventoryService: Sendable {
    func getInventory() async -> [Equipment]
    func addEquipment(_ equipment: Equipment) async
    func removeEquipment(_ id: UUID) async
    func getEquipment(by id: UUID) async -> Equipment?
}
