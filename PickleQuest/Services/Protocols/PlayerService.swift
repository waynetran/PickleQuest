import Foundation

protocol PlayerService: Sendable {
    func getPlayer() async -> Player
    func savePlayer(_ player: Player) async
    func addXP(_ amount: Int) async -> [LevelUpReward]
    func allocateStatPoint(to stat: StatType) async -> Bool
    func equipItem(_ equipmentID: UUID, to slot: EquipmentSlot) async
    func unequipSlot(_ slot: EquipmentSlot) async
}
