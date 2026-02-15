import Foundation

struct Equipment: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let slot: EquipmentSlot
    let rarity: EquipmentRarity
    let statBonuses: [StatBonus]
    let ability: EquipmentAbility?
    let sellPrice: Int
    var condition: Double

    var totalBonusPoints: Int {
        statBonuses.reduce(0) { $0 + $1.value }
    }

    /// Condition as a 0-100 integer for display
    var conditionPercent: Int {
        Int((condition * 100).rounded())
    }

    /// Only shoes and paddles take wear damage
    var isWearable: Bool {
        slot == .shoes || slot == .paddle
    }

    init(
        id: UUID,
        name: String,
        slot: EquipmentSlot,
        rarity: EquipmentRarity,
        statBonuses: [StatBonus],
        ability: EquipmentAbility?,
        sellPrice: Int,
        condition: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.slot = slot
        self.rarity = rarity
        self.statBonuses = statBonuses
        self.ability = ability
        self.sellPrice = sellPrice
        self.condition = condition
    }
}

struct StatBonus: Codable, Equatable, Sendable {
    let stat: StatType
    let value: Int
}
