import Foundation

struct LootGenerator: Sendable {
    private let rng: RandomSource
    private let nameGenerator: EquipmentNameGenerator

    init(rng: RandomSource = SystemRandomSource()) {
        self.rng = rng
        self.nameGenerator = EquipmentNameGenerator(rng: rng)
    }

    // MARK: - Match Loot

    func generateMatchLoot(
        didWin: Bool,
        opponentDifficulty: NPCDifficulty,
        playerLevel: Int,
        suprGap: Double = 0
    ) -> [Equipment] {
        var loot: [Equipment] = []

        if didWin {
            var boost = GameConstants.Loot.difficultyRarityBoost[opponentDifficulty] ?? 0
            // Beat someone stronger (suprGap > 0) → better loot
            if suprGap > 0 {
                boost += min(
                    GameConstants.Loot.maxSuprLootBoost,
                    suprGap * GameConstants.Loot.suprGapRarityBoost
                )
            }
            for _ in 0..<GameConstants.Loot.winDropCount {
                loot.append(generateEquipment(difficultyBoost: boost))
            }
        } else {
            if rng.nextDouble() < GameConstants.Loot.lossDropChance {
                loot.append(generateEquipment(difficultyBoost: 0))
            }
        }

        return loot
    }

    // MARK: - Store Inventory

    func generateStoreInventory(count: Int = GameConstants.Store.shopSize) -> [StoreItem] {
        (0..<count).map { _ in
            let rarity = rollStoreRarity()
            let equipment = generateEquipment(rarity: rarity, difficultyBoost: 0)
            let priceRange = GameConstants.Store.priceRange[rarity] ?? 50...100
            let price = rng.nextInt(in: priceRange)
            return StoreItem(equipment: equipment, price: price)
        }
    }

    // MARK: - Equipment Generation

    func generateEquipment(
        rarity: EquipmentRarity? = nil,
        difficultyBoost: Double = 0
    ) -> Equipment {
        let finalRarity = rarity ?? rollRarity(boost: difficultyBoost)
        let slot = EquipmentSlot.allCases[rng.nextInt(in: 0...EquipmentSlot.allCases.count - 1)]

        // Pick a random brand+model for this slot
        let model = EquipmentBrandCatalog.randomModel(for: slot, using: rng)
        let brand = EquipmentBrandCatalog.brand(for: model.brandID)

        // Base stat from model
        let baseStat = StatBonus(stat: model.baseStat, value: finalRarity.baseStatValue)

        // Bonus stats (excluding the base stat)
        let bonuses = generateBonuses(rarity: finalRarity, excludingStat: model.baseStat)

        let traits = generateTraits(rarity: finalRarity)
        let ability: EquipmentAbility? = nil // deprecated — traits replace abilities
        let allBonuses = baseStat.value > 0 ? [baseStat] + bonuses : bonuses
        let flavorText = nameGenerator.generateFlavorText(slot: slot, rarity: finalRarity, statBonuses: allBonuses)

        // Roll for set piece
        let (setID, setName) = rollSetPiece(rarity: finalRarity, slot: slot)

        // Name = "Brand Model"
        let brandName = brand?.name ?? "Unknown"
        let modelName = model.name
        let baseName = "\(brandName) \(modelName)"
        let name = setName.map { "\($0) \(baseName)" } ?? baseName

        let sellPrice = calculateSellPrice(rarity: finalRarity, baseStat: baseStat, bonuses: bonuses)

        return Equipment(
            id: UUID(),
            name: name,
            slot: slot,
            rarity: finalRarity,
            statBonuses: bonuses,
            flavorText: flavorText,
            setID: setID,
            setName: setName,
            traits: traits,
            ability: ability,
            sellPrice: sellPrice,
            brandID: model.brandID,
            modelID: model.id,
            level: 1,
            baseStat: baseStat
        )
    }

    private func generateTraits(rarity: EquipmentRarity) -> [EquipmentTrait] {
        let slots = rarity.traitSlots
        var traits: [EquipmentTrait] = []

        let minorPool = TraitType.allCases.filter { $0.tier == .minor }
        let majorPool = TraitType.allCases.filter { $0.tier == .major }
        let uniquePool = TraitType.allCases.filter { $0.tier == .unique }

        if slots.minor > 0, !minorPool.isEmpty {
            let type = minorPool[rng.nextInt(in: 0...minorPool.count - 1)]
            traits.append(EquipmentTrait(type: type, tier: .minor))
        }
        if slots.major > 0, !majorPool.isEmpty {
            let type = majorPool[rng.nextInt(in: 0...majorPool.count - 1)]
            traits.append(EquipmentTrait(type: type, tier: .major))
        }
        if slots.unique > 0, !uniquePool.isEmpty {
            let type = uniquePool[rng.nextInt(in: 0...uniquePool.count - 1)]
            traits.append(EquipmentTrait(type: type, tier: .unique))
        }

        return traits
    }

    private func rollSetPiece(rarity: EquipmentRarity, slot: EquipmentSlot) -> (String?, String?) {
        let setChance: Double
        switch rarity {
        case .rare: setChance = GameConstants.Equipment.setChanceRare
        case .epic: setChance = GameConstants.Equipment.setChanceEpic
        case .legendary: setChance = GameConstants.Equipment.setChanceLegendary
        default: return (nil, nil)
        }

        guard rng.nextDouble() < setChance else { return (nil, nil) }

        // Pick a random set that includes this slot
        let eligibleSets = EquipmentSet.allSets.filter { $0.pieces.contains(slot) }
        guard !eligibleSets.isEmpty else { return (nil, nil) }

        let chosen = eligibleSets[rng.nextInt(in: 0...eligibleSets.count - 1)]
        return (chosen.id, chosen.name)
    }

    // MARK: - Rarity Rolling

    private func rollRarity(boost: Double) -> EquipmentRarity {
        let roll = rng.nextDouble()
        var cumulative = 0.0

        // Shift weights: reduce common weight by boost, distribute to higher rarities
        let weights: [(EquipmentRarity, Double)] = EquipmentRarity.allCases.map { rarity in
            var weight = rarity.dropWeight
            if rarity == .common {
                weight = max(0.1, weight - boost)
            } else {
                weight += boost / 4.0
            }
            return (rarity, weight)
        }

        let totalWeight = weights.reduce(0) { $0 + $1.1 }

        for (rarity, weight) in weights {
            cumulative += weight / totalWeight
            if roll < cumulative {
                return rarity
            }
        }

        return .common
    }

    private func rollStoreRarity() -> EquipmentRarity {
        let roll = rng.nextDouble()
        var cumulative = 0.0

        let weights = GameConstants.Store.storeRarityWeights
        let sorted = EquipmentRarity.allCases

        for rarity in sorted {
            cumulative += weights[rarity] ?? 0
            if roll < cumulative {
                return rarity
            }
        }

        return .common
    }

    // MARK: - Stat Bonuses

    private func generateBonuses(rarity: EquipmentRarity, excludingStat: StatType) -> [StatBonus] {
        let count = rarity.bonusStatCount
        let budget = rarity.bonusStatBudget
        guard count > 0 && budget > 0 else { return [] }

        // Pick unique stats (excluding the base stat)
        var availableStats = StatType.allCases.filter { $0 != excludingStat }.shuffled(using: rng)
        var bonuses: [StatBonus] = []
        var remaining = budget

        for i in 0..<count {
            guard !availableStats.isEmpty && remaining > 0 else { break }
            let stat = availableStats.removeFirst()
            let isLast = i == count - 1
            let value: Int
            if isLast {
                value = remaining
            } else {
                let maxForThis = remaining - (count - i - 1) // leave at least 1 for remaining
                value = rng.nextInt(in: 1...max(1, maxForThis))
            }
            remaining -= value
            bonuses.append(StatBonus(stat: stat, value: value))
        }

        return bonuses
    }

    // MARK: - Abilities

    private func generateAbility() -> EquipmentAbility {
        let triggers = AbilityTrigger.allCases
        let trigger = triggers[rng.nextInt(in: 0...triggers.count - 1)]

        let effect = generateEffect()
        let name = abilityName(trigger: trigger, effect: effect)
        let description = "\(trigger.displayName): \(effect.description)"

        return EquipmentAbility(name: name, description: description, trigger: trigger, effect: effect)
    }

    private func generateEffect() -> AbilityEffect {
        let roll = rng.nextInt(in: 0...2)
        switch roll {
        case 0:
            let stat = StatType.allCases[rng.nextInt(in: 0...StatType.allCases.count - 1)]
            let amount = rng.nextInt(in: 3...8)
            return .statBoost(stat: stat, amount: amount, durationPoints: rng.nextInt(in: 2...4))
        case 1:
            return .energyRestore(amount: Double(rng.nextInt(in: 10...25)))
        default:
            return .momentumBoost(amount: Double(rng.nextInt(in: 3...7)) / 100.0)
        }
    }

    private func abilityName(trigger: AbilityTrigger, effect: AbilityEffect) -> String {
        switch effect {
        case .statBoost(let stat, _, _):
            return "\(trigger.displayName) \(stat.displayName) Surge"
        case .energyRestore:
            return "\(trigger.displayName) Recovery"
        case .momentumBoost:
            return "\(trigger.displayName) Momentum Wave"
        }
    }

    // MARK: - Pricing

    private func calculateSellPrice(rarity: EquipmentRarity, baseStat: StatBonus, bonuses: [StatBonus]) -> Int {
        let basePrice: Int
        switch rarity {
        case .common: basePrice = 15
        case .uncommon: basePrice = 40
        case .rare: basePrice = 100
        case .epic: basePrice = 250
        case .legendary: basePrice = 600
        }
        let totalStatValue = baseStat.value + bonuses.reduce(0) { $0 + $1.value }
        return basePrice + totalStatValue * 2
    }
}

// MARK: - Helper Extensions

private extension Array {
    func shuffled(using rng: RandomSource) -> [Element] {
        var result = self
        for i in stride(from: result.count - 1, through: 1, by: -1) {
            let j = rng.nextInt(in: 0...i)
            result.swapAt(i, j)
        }
        return result
    }
}

extension AbilityTrigger: CaseIterable {
    static var allCases: [AbilityTrigger] {
        [.onServe, .onMatchPoint, .onStreakThree, .onLowEnergy, .onClutch]
    }

    var displayName: String {
        switch self {
        case .onServe: return "Serve"
        case .onMatchPoint: return "Match Point"
        case .onStreakThree: return "Streak"
        case .onLowEnergy: return "Low Energy"
        case .onClutch: return "Clutch"
        }
    }
}
