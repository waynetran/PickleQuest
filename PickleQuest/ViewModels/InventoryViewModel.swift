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

    // --- Inventory grid paging ---
    var currentTab: Int = 0

    private let itemsPerPage = 16

    var tabCount: Int {
        max(2, Int(ceil(Double(filteredInventory.count) / Double(itemsPerPage))))
    }

    // --- Drag state ---
    var dragState: DragState?

    // --- Character animation ---
    var animationState: CharacterAnimationState = .idleFront

    // --- Slot frame registration for drop targeting ---
    var slotFrames: [EquipmentSlot: CGRect] = [:]

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
        currentTab = 0
    }

    func selectItem(_ item: Equipment, player: Player) {
        selectedItem = item
        previewStats = calculatePreviewStats(equipping: item, player: player)
        showingDetail = true
    }

    func equipItem(_ item: Equipment, player: inout Player) async {
        player.equippedItems[item.slot] = item.id
        await playerService.savePlayer(player)
    }

    func unequipSlot(_ slot: EquipmentSlot, player: inout Player) async {
        player.equippedItems.removeValue(forKey: slot)
        await playerService.savePlayer(player)
    }

    func sellItem(_ item: Equipment, player: inout Player) async {
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

    // MARK: - Grid Paging

    func itemForSlot(tab: Int, index: Int, player: Player) -> Equipment? {
        let allItems = filteredInventory
        let offset = tab * itemsPerPage + index
        guard offset < allItems.count else { return nil }
        return allItems[offset]
    }

    // MARK: - Drag & Drop

    func startDrag(item: Equipment, at location: CGPoint, player: Player) {
        let deltas = computeStatDeltas(equipping: item, player: player)
        dragState = DragState(item: item, location: location, statDeltas: deltas)
    }

    func updateDragLocation(_ point: CGPoint) {
        dragState?.location = point
    }

    func endDrag(player: inout Player) async {
        guard let drag = dragState else { return }
        // Check if drop location intersects a compatible slot frame
        for (slot, frame) in slotFrames {
            if frame.contains(drag.location) && drag.item.slot == slot {
                player.equippedItems[slot] = drag.item.id
                await playerService.savePlayer(player)
                break
            }
        }
        dragState = nil
    }

    func cancelDrag() {
        dragState = nil
    }

    func computeStatDeltas(equipping item: Equipment, player: Player) -> [StatDelta] {
        let current = effectiveStats(for: player)
        let preview = calculatePreviewStats(equipping: item, player: player)
        var deltas: [StatDelta] = []
        for stat in StatType.allCases {
            let diff = preview.stat(stat) - current.stat(stat)
            if diff != 0 {
                deltas.append(StatDelta(stat: stat, value: diff))
            }
        }
        return deltas
    }

    // MARK: - Character Animation

    private static let hitAnimations: [CharacterAnimationState] = [
        .forehandFront, .backhandFront, .smashFront
    ]

    func cycleAnimation() {
        let hit = Self.hitAnimations.randomElement() ?? .forehandFront
        animationState = hit
        // Return to idle after the animation plays (~0.5s)
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            animationState = .idleFront
        }
    }

    // MARK: - Private

    private func applyFilter() {
        if let slot = selectedFilter {
            filteredInventory = inventory.filter { $0.slot == slot }
        } else {
            filteredInventory = inventory
        }
        filteredInventory.sort { a, b in
            if a.rarity != b.rarity { return a.rarity > b.rarity }
            return a.totalBonusPoints > b.totalBonusPoints
        }
    }

    private func calculatePreviewStats(equipping item: Equipment, player: Player) -> PlayerStats {
        var equippedItems = player.equippedItems.values.compactMap { id in
            inventory.first { $0.id == id }
        }
        equippedItems.removeAll { $0.slot == item.slot }
        equippedItems.append(item)
        return statCalculator.effectiveStats(base: player.stats, equipment: equippedItems, playerLevel: player.progression.level)
    }
}

// MARK: - Supporting Types

struct DragState {
    let item: Equipment
    var location: CGPoint
    var statDeltas: [StatDelta]
}

struct StatDelta: Identifiable {
    let stat: StatType
    let value: Int
    var id: StatType { stat }

    var formatted: String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    var color: Color {
        value > 0 ? .green : .red
    }
}
