import Foundation
import SwiftUI

@MainActor
@Observable
final class PlayerProfileViewModel {
    private let playerService: PlayerService
    private let inventoryService: InventoryService
    private let statCalculator = StatCalculator()

    var player: Player?
    var equippedItems: [Equipment] = []
    var effectiveStats: PlayerStats?
    var isLoading = false
    var showStatAllocation = false

    init(playerService: PlayerService, inventoryService: InventoryService) {
        self.playerService = playerService
        self.inventoryService = inventoryService
    }

    func loadPlayer() async {
        isLoading = true
        player = await playerService.getPlayer()
        await loadEquippedItems()
        isLoading = false
    }

    func allocateStatPoint(to stat: StatType, player: inout Player) async -> Bool {
        guard player.progression.availableStatPoints > 0 else { return false }
        let current = player.stats.stat(stat)
        guard current < GameConstants.Stats.maxValue else { return false }
        player.stats.setStat(stat, value: current + 1)
        player.progression.availableStatPoints -= 1
        await playerService.savePlayer(player)
        await loadEquippedItems()
        return true
    }

    func calculateEffectiveStats(for player: Player) -> PlayerStats {
        statCalculator.effectiveStats(base: player.stats, equipment: equippedItems, playerLevel: player.progression.level)
    }

    // MARK: - Private

    private func loadEquippedItems() async {
        guard let player else { return }
        equippedItems = await inventoryService.getEquippedItems(for: player.equippedItems)
        effectiveStats = statCalculator.effectiveStats(base: player.stats, equipment: equippedItems, playerLevel: player.progression.level)
    }
}
