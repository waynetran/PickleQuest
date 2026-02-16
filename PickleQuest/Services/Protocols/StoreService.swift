import Foundation

protocol StoreService: Sendable {
    func getStoreInventory() async -> [StoreItem]
    func refreshStore() async -> [StoreItem]
    func buyItem(_ itemID: UUID) async -> Equipment?
    func getStoreConsumables() async -> [StoreConsumableItem]
    func buyConsumable(_ itemID: UUID) async -> Consumable?
    func sellItem(_ equipment: Equipment) async -> Int
}
