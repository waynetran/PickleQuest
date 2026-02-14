import Foundation

actor MockPlayerService: PlayerService {
    private var player: Player

    init(player: Player? = nil) {
        self.player = player ?? Player.newPlayer(name: "Rookie")
    }

    func getPlayer() async -> Player {
        player
    }

    func savePlayer(_ player: Player) async {
        self.player = player
    }

    func addXP(_ amount: Int) async -> [LevelUpReward] {
        player.progression.addXP(amount)
    }

    func allocateStatPoint(to stat: StatType) async -> Bool {
        guard player.progression.availableStatPoints > 0 else { return false }
        let current = player.stats.stat(stat)
        guard current < GameConstants.Stats.maxValue else { return false }
        player.stats.setStat(stat, value: current + 1)
        player.progression.availableStatPoints -= 1
        return true
    }

    func equipItem(_ equipmentID: UUID, to slot: EquipmentSlot) async {
        player.equippedItems[slot] = equipmentID
    }

    func unequipSlot(_ slot: EquipmentSlot) async {
        player.equippedItems.removeValue(forKey: slot)
    }
}
