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
    let traits: [EquipmentTrait]
    let ability: EquipmentAbility?
    let sellPrice: Int
    let visualColor: String?
    var condition: Double

    // Brand/Model/Level system
    let brandID: String?
    let modelID: String?
    var level: Int
    let baseStat: StatBonus?

    // MARK: - Computed Properties

    /// Generated display name: "[Rarity] [slot] of [stat phrase]"
    /// The stat phrase is a funny name derived from the item's highest stat bonus.
    var displayTitle: String {
        let allBonuses = (baseStat.map { [$0] } ?? []) + statBonuses
        let topStat = allBonuses.max(by: { $0.value < $1.value })?.stat
        let phrase = topStat?.equipmentPhrase ?? "Vibes"
        if rarity == .common {
            return "\(slot.displayName) of The \(phrase)"
        }
        return "\(rarity.displayName) \(slot.displayName) of The \(phrase)"
    }

    var totalBonusPoints: Int {
        let bonusTotal = statBonuses.reduce(0) { $0 + $1.value }
        let baseTotal = baseStat?.value ?? 0
        return bonusTotal + baseTotal
    }

    var brandName: String? {
        guard let brandID else { return nil }
        return EquipmentBrandCatalog.brand(for: brandID)?.name
    }

    var modelName: String? {
        guard let modelID else { return nil }
        return EquipmentBrandCatalog.model(for: modelID)?.name
    }

    var maxLevel: Int {
        rarity.maxLevel
    }

    var isMaxLevel: Bool {
        level >= maxLevel
    }

    /// Level multiplier: 1.0 at level 1, +5% per level
    var levelMultiplier: Double {
        1.0 + GameConstants.EquipmentLevel.statPercentPerLevel * Double(level - 1)
    }

    var upgradeCost: Int {
        GameConstants.EquipmentLevel.upgradeCost(rarity: rarity, targetLevel: level + 1)
    }

    /// Condition as a 0-100 integer for display
    var conditionPercent: Int {
        Int((condition * 100).rounded())
    }

    /// Only shoes and paddles take wear damage
    var isWearable: Bool {
        slot == .shoes || slot == .paddle
    }

    /// Equipment is broken when condition hits 0 (wearable items only)
    var isBroken: Bool {
        condition <= 0 && isWearable
    }

    /// Repair cost is ~30% of rarity base price
    var repairCost: Int {
        let basePrice: Int
        switch rarity {
        case .common: basePrice = 50
        case .uncommon: basePrice = 100
        case .rare: basePrice = 250
        case .epic: basePrice = 500
        case .legendary: basePrice = 1000
        }
        return Int(Double(basePrice) * 0.3)
    }

    /// Sell price accounts for level investment
    var effectiveSellPrice: Int {
        sellPrice + (level - 1) * GameConstants.EquipmentLevel.levelSellBonus
    }

    // MARK: - Memberwise Init

    init(
        id: UUID,
        name: String,
        slot: EquipmentSlot,
        rarity: EquipmentRarity,
        statBonuses: [StatBonus],
        flavorText: String = "",
        setID: String? = nil,
        setName: String? = nil,
        traits: [EquipmentTrait] = [],
        ability: EquipmentAbility?,
        sellPrice: Int,
        visualColor: String? = nil,
        condition: Double = 1.0,
        brandID: String? = nil,
        modelID: String? = nil,
        level: Int = 1,
        baseStat: StatBonus? = nil
    ) {
        self.id = id
        self.name = name
        self.slot = slot
        self.rarity = rarity
        self.statBonuses = statBonuses
        self.flavorText = flavorText
        self.setID = setID
        self.setName = setName
        self.traits = traits
        self.ability = ability
        self.sellPrice = sellPrice
        self.visualColor = visualColor
        self.condition = condition
        self.brandID = brandID
        self.modelID = modelID
        self.level = level
        self.baseStat = baseStat
    }

    // MARK: - Codable (backward-compatible)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slot = try container.decode(EquipmentSlot.self, forKey: .slot)
        rarity = try container.decode(EquipmentRarity.self, forKey: .rarity)
        statBonuses = try container.decode([StatBonus].self, forKey: .statBonuses)
        flavorText = try container.decodeIfPresent(String.self, forKey: .flavorText) ?? ""
        setID = try container.decodeIfPresent(String.self, forKey: .setID)
        setName = try container.decodeIfPresent(String.self, forKey: .setName)
        traits = try container.decodeIfPresent([EquipmentTrait].self, forKey: .traits) ?? []
        ability = try container.decodeIfPresent(EquipmentAbility.self, forKey: .ability)
        sellPrice = try container.decode(Int.self, forKey: .sellPrice)
        visualColor = try container.decodeIfPresent(String.self, forKey: .visualColor)
        condition = try container.decodeIfPresent(Double.self, forKey: .condition) ?? 1.0
        brandID = try container.decodeIfPresent(String.self, forKey: .brandID)
        modelID = try container.decodeIfPresent(String.self, forKey: .modelID)
        level = try container.decodeIfPresent(Int.self, forKey: .level) ?? 1
        baseStat = try container.decodeIfPresent(StatBonus.self, forKey: .baseStat)
    }
}

struct StatBonus: Codable, Equatable, Sendable {
    let stat: StatType
    let value: Int
}
