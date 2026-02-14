import Foundation

struct Equipment: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let slot: EquipmentSlot
    let rarity: EquipmentRarity
    let statBonuses: [StatBonus]
    let ability: EquipmentAbility?
    let sellPrice: Int

    var totalBonusPoints: Int {
        statBonuses.reduce(0) { $0 + $1.value }
    }
}

struct StatBonus: Codable, Equatable, Sendable {
    let stat: StatType
    let value: Int
}
