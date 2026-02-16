import Foundation
import SwiftUI

@MainActor
@Observable
final class InventoryViewModel {
    private let inventoryService: InventoryService
    private let playerService: PlayerService
    private let statCalculator = StatCalculator()

    var inventory: [Equipment] = []
    var filteredInventory: [Equipment] = []
    var selectedFilter: EquipmentSlot?
    var selectedItem: Equipment?
    var showingDetail = false
    var isLoading = false

    // Stat preview when considering equipping an item
    var previewStats: PlayerStats?

    init(inventoryService: InventoryService, playerService: PlayerService) {
        self.inventoryService = inventoryService
        self.playerService = playerService
    }

    func loadInventory() async {
        isLoading = true
        inventory = await inventoryService.getInventory()
        applyFilter()
        isLoading = false
    }

    func setFilter(_ slot: EquipmentSlot?) {
        selectedFilter = slot
        applyFilter()
    }

    func selectItem(_ item: Equipment, player: Player) {
        selectedItem = item
        previewStats = calculatePreviewStats(equipping: item, player: player)
        showingDetail = true
    }

    func equipItem(_ item: Equipment, player: inout Player) async {
        // Unequip existing item in that slot (if any)
        player.equippedItems[item.slot] = item.id
        await playerService.savePlayer(player)
    }

    func unequipSlot(_ slot: EquipmentSlot, player: inout Player) async {
        player.equippedItems.removeValue(forKey: slot)
        await playerService.savePlayer(player)
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
        await loadInventory()
        showingDetail = false
        selectedItem = nil
    }

    func repairItem(_ item: Equipment) async -> Bool {
        let success = await inventoryService.repairEquipment(item.id)
        if success {
            await loadInventory()
        }
        return success
    }

    func upgradeItem(_ item: Equipment, player: inout Player) async -> Equipment? {
        let cost = item.upgradeCost
        guard player.wallet.coins >= cost else { return nil }
        guard !item.isMaxLevel else { return nil }

        guard let upgraded = await inventoryService.upgradeEquipment(item.id) else { return nil }
        player.wallet.coins -= cost
        await playerService.savePlayer(player)
        await loadInventory()
        selectedItem = upgraded
        return upgraded
    }

    func equippedItem(for slot: EquipmentSlot, player: Player) -> Equipment? {
        guard let id = player.equippedItems[slot] else { return nil }
        return inventory.first { $0.id == id }
    }

    func effectiveStats(for player: Player) -> PlayerStats {
        let equipped = player.equippedItems.values.compactMap { id in
            inventory.first { $0.id == id }
        }
        return statCalculator.effectiveStats(base: player.stats, equipment: equipped, playerLevel: player.progression.level)
    }

    // MARK: - Private

    private func applyFilter() {
        if let slot = selectedFilter {
            filteredInventory = inventory.filter { $0.slot == slot }
        } else {
            filteredInventory = inventory
        }
        // Sort by rarity (highest first), then by total bonus
        filteredInventory.sort { a, b in
            if a.rarity != b.rarity { return a.rarity > b.rarity }
            return a.totalBonusPoints > b.totalBonusPoints
        }
    }

    private func calculatePreviewStats(equipping item: Equipment, player: Player) -> PlayerStats {
        var equippedItems = player.equippedItems.values.compactMap { id in
            inventory.first { $0.id == id }
        }
        // Remove current item in same slot
        equippedItems.removeAll { $0.slot == item.slot }
        equippedItems.append(item)
        return statCalculator.effectiveStats(base: player.stats, equipment: equippedItems, playerLevel: player.progression.level)
    }
}
