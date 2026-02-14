import Foundation

protocol StoreService: Sendable {
    func getStoreInventory() async -> [StoreItem]
    func refreshStore() async -> [StoreItem]
    func buyItem(_ itemID: UUID) async -> Equipment?
}
