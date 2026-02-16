import Foundation
import SwiftUI

@MainActor
@Observable
final class StoreViewModel {
    private let storeService: StoreService
    private let inventoryService: InventoryService
    private let playerService: PlayerService
    private let statCalculator = StatCalculator()

    var storeItems: [StoreItem] = []
    var consumableItems: [StoreConsumableItem] = []
    var isLoading = false
    var purchaseMessage: String?

    // Detail sheet state
    var playerInventory: [Equipment] = []
    var selectedEquipment: Equipment?
    var showingDetail = false
    var previewStats: PlayerStats?
    var isStoreItem = false

    init(storeService: StoreService, inventoryService: InventoryService, playerService: PlayerService) {
        self.storeService = storeService
        self.inventoryService = inventoryService
        self.playerService = playerService
    }

    func loadStore() async {
        isLoading = true
        storeItems = await storeService.getStoreInventory()
        consumableItems = await storeService.getStoreConsumables()
        isLoading = false
    }

    func loadPlayerInventory() async {
        playerInventory = await inventoryService.getInventory()
    }

    // MARK: - Detail Selection

    func selectStoreItem(_ item: StoreItem, player: Player) {
        selectedEquipment = item.equipment
        previewStats = calculatePreviewStats(equipping: item.equipment, player: player)
        isStoreItem = true
        showingDetail = true
    }

    func selectOwnedItem(_ item: Equipment, player: Player) {
        selectedEquipment = item
        previewStats = calculatePreviewStats(equipping: item, player: player)
        isStoreItem = false
        showingDetail = true
    }

    // MARK: - Buy / Sell / Equip

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

        await loadPlayerInventory()
        purchaseMessage = "Purchased \(equipment.name)!"
        return true
    }

    func sellItem(_ item: Equipment, player: inout Player) async {
        // Remove from equipped if currently equipped
        if player.equippedItems.values.contains(item.id) {
            for (slot, id) in player.equippedItems where id == item.id {
                player.equippedItems.removeValue(forKey: slot)
            }
        }
        player.wallet.add(item.effectiveSellPrice)
        await inventoryService.removeEquipment(item.id)
        await playerService.savePlayer(player)
        await loadPlayerInventory()
        showingDetail = false
        selectedEquipment = nil
    }

    func equipItem(_ item: Equipment, player: inout Player) async {
        player.equippedItems[item.slot] = item.id
        await playerService.savePlayer(player)
    }

    func unequipSlot(_ slot: EquipmentSlot, player: inout Player) async {
        player.equippedItems.removeValue(forKey: slot)
        await playerService.savePlayer(player)
    }

    func refreshStore(player: inout Player) async -> Bool {
        guard player.wallet.spend(GameConstants.Store.refreshCost) else {
            purchaseMessage = "Not enough coins to refresh!"
            return false
        }

        storeItems = await storeService.refreshStore()
        consumableItems = await storeService.getStoreConsumables()
        purchaseMessage = "Store refreshed!"
        return true
    }

    func buyConsumable(_ item: StoreConsumableItem, player: inout Player) async -> Bool {
        guard player.wallet.coins >= item.consumable.price else {
            purchaseMessage = "Not enough coins!"
            return false
        }

        guard let consumable = await storeService.buyConsumable(item.id) else {
            purchaseMessage = "Item no longer available."
            return false
        }

        let spent = player.wallet.spend(consumable.price)
        guard spent else { return false }

        await inventoryService.addConsumable(consumable)
        player.consumables.append(consumable)

        // Update local state
        if let index = consumableItems.firstIndex(where: { $0.id == item.id }) {
            consumableItems[index].isSoldOut = true
        }

        purchaseMessage = "Purchased \(consumable.name)!"
        return true
    }

    // MARK: - Stats

    func effectiveStats(for player: Player) -> PlayerStats {
        let equipped = player.equippedItems.values.compactMap { id in
            playerInventory.first { $0.id == id }
        }
        return statCalculator.effectiveStats(base: player.stats, equipment: equipped, playerLevel: player.progression.level)
    }

    func sellableInventory(player: Player) -> [Equipment] {
        playerInventory
            .filter { !player.equippedItems.values.contains($0.id) }
            .sorted { a, b in
                if a.rarity != b.rarity { return a.rarity > b.rarity }
                return a.totalBonusPoints > b.totalBonusPoints
            }
    }

    // MARK: - Private

    private func calculatePreviewStats(equipping item: Equipment, player: Player) -> PlayerStats {
        var equippedItems = player.equippedItems.values.compactMap { id in
            playerInventory.first { $0.id == id }
        }
        // Remove current item in same slot
        equippedItems.removeAll { $0.slot == item.slot }
        equippedItems.append(item)
        return statCalculator.effectiveStats(base: player.stats, equipment: equippedItems, playerLevel: player.progression.level)
    }
}
