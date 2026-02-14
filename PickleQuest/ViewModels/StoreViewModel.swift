import Foundation
import SwiftUI

@MainActor
@Observable
final class StoreViewModel {
    private let storeService: StoreService
    private let inventoryService: InventoryService

    var storeItems: [StoreItem] = []
    var isLoading = false
    var purchaseMessage: String?

    init(storeService: StoreService, inventoryService: InventoryService) {
        self.storeService = storeService
        self.inventoryService = inventoryService
    }

    func loadStore() async {
        isLoading = true
        storeItems = await storeService.getStoreInventory()
        isLoading = false
    }

    func buyItem(_ item: StoreItem, player: inout Player) async -> Bool {
        guard player.wallet.coins >= item.price else {
            purchaseMessage = "Not enough coins!"
            return false
        }

        guard let equipment = await storeService.buyItem(item.id) else {
            purchaseMessage = "Item no longer available."
            return false
        }

        let spent = player.wallet.spend(item.price)
        guard spent else { return false }

        await inventoryService.addEquipment(equipment)

        // Update local store state
        if let index = storeItems.firstIndex(where: { $0.id == item.id }) {
            storeItems[index].isSoldOut = true
        }

        purchaseMessage = "Purchased \(equipment.name)!"
        return true
    }

    func refreshStore(player: inout Player) async -> Bool {
        guard player.wallet.spend(GameConstants.Store.refreshCost) else {
            purchaseMessage = "Not enough coins to refresh!"
            return false
        }

        storeItems = await storeService.refreshStore()
        purchaseMessage = "Store refreshed!"
        return true
    }
}
