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
        playerLevel: Int
    ) -> [Equipment] {
        var loot: [Equipment] = []

        if didWin {
            for _ in 0..<GameConstants.Loot.winDropCount {
                loot.append(generateEquipment(
                    difficultyBoost: GameConstants.Loot.difficultyRarityBoost[opponentDifficulty] ?? 0
                ))
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
        let name = nameGenerator.generateName(slot: slot, rarity: finalRarity)
        let bonuses = generateBonuses(rarity: finalRarity)
        let ability = finalRarity.hasAbility ? generateAbility() : nil
        let sellPrice = calculateSellPrice(rarity: finalRarity, bonuses: bonuses)

        return Equipment(
            id: UUID(),
            name: name,
            slot: slot,
            rarity: finalRarity,
            statBonuses: bonuses,
            ability: ability,
            sellPrice: sellPrice
        )
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

    private func generateBonuses(rarity: EquipmentRarity) -> [StatBonus] {
        let countRange = GameConstants.Loot.bonusStatCount[rarity] ?? 1...2
        let count = rng.nextInt(in: countRange)
        let maxTotal = rarity.maxStatBonus

        // Pick unique stats
        var availableStats = StatType.allCases.shuffled(using: rng)
        var bonuses: [StatBonus] = []
        var remaining = maxTotal

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

    private func calculateSellPrice(rarity: EquipmentRarity, bonuses: [StatBonus]) -> Int {
        let basePrice: Int
        switch rarity {
        case .common: basePrice = 15
        case .uncommon: basePrice = 40
        case .rare: basePrice = 100
        case .epic: basePrice = 250
        case .legendary: basePrice = 600
        }
        let bonusValue = bonuses.reduce(0) { $0 + $1.value } * 2
        return basePrice + bonusValue
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
