import Foundation

struct Equipment: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let slot: EquipmentSlot
    let rarity: EquipmentRarity
    let statBonuses: [StatBonus]
    let flavorText: String
    let setID: String?
    let setName: String?
    let ability: EquipmentAbility?
    let sellPrice: Int
    let visualColor: String?
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
        flavorText: String = "",
        setID: String? = nil,
        setName: String? = nil,
        ability: EquipmentAbility?,
        sellPrice: Int,
        visualColor: String? = nil,
        condition: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.slot = slot
        self.rarity = rarity
        self.statBonuses = statBonuses
        self.flavorText = flavorText
        self.setID = setID
        self.setName = setName
        self.ability = ability
        self.sellPrice = sellPrice
        self.visualColor = visualColor
        self.condition = condition
    }
}

struct StatBonus: Codable, Equatable, Sendable {
    let stat: StatType
    let value: Int
}
