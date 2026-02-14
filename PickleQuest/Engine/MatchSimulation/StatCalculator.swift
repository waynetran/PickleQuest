import Foundation

/// Calculates effective stats from base stats + equipment bonuses, with diminishing returns.
struct StatCalculator: Sendable {
    /// Compute effective stats for a player given their base stats and equipped items.
    func effectiveStats(base: PlayerStats, equipment: [Equipment]) -> PlayerStats {
        var result = base
        let bonuses = aggregateBonuses(from: equipment)

        for type in StatType.allCases {
            let baseValue = base.stat(type)
            let bonus = bonuses[type] ?? 0
            let effective = applyDiminishingReturns(base: baseValue, bonus: bonus)
            result.setStat(type, value: effective)
        }

        return result
    }

    /// Apply fatigue penalty to stats. Returns a new stat set with reduced values.
    func applyFatigue(stats: PlayerStats, energy: Double) -> PlayerStats {
        let penalty = fatiguePenalty(energy: energy)
        guard penalty > 0 else { return stats }

        var result = stats
        for type in StatType.allCases {
            // Stamina is not reduced by fatigue
            guard type != .stamina else { continue }
            let current = Double(stats.stat(type))
            let reduced = Int(current * (1.0 - penalty))
            result.setStat(type, value: max(reduced, GameConstants.Stats.minValue))
        }
        return result
    }

    /// Apply momentum modifier to offensive/defensive stats.
    func applyMomentum(stats: PlayerStats, modifier: Double) -> PlayerStats {
        guard modifier != 0 else { return stats }
        var result = stats
        let affectedStats: [StatType] = [.power, .accuracy, .spin, .speed, .clutch, .consistency]
        for type in affectedStats {
            let current = Double(stats.stat(type))
            let adjusted = Int(current * (1.0 + modifier))
            result.setStat(type, value: min(max(adjusted, GameConstants.Stats.minValue), GameConstants.Stats.maxValue))
        }
        return result
    }

    // MARK: - Private

    private func aggregateBonuses(from equipment: [Equipment]) -> [StatType: Int] {
        var bonuses: [StatType: Int] = [:]
        for item in equipment {
            for bonus in item.statBonuses {
                bonuses[bonus.stat, default: 0] += bonus.value
            }
        }
        return bonuses
    }

    /// Diminishing returns: linear below 60, 0.7x 60-80, 0.4x 80+, hard cap 99
    private func applyDiminishingReturns(base: Int, bonus: Int) -> Int {
        guard bonus > 0 else { return base }

        var remaining = bonus
        var current = base

        // Linear region: up to 60
        if current < GameConstants.Stats.linearCap {
            let room = GameConstants.Stats.linearCap - current
            let applied = min(remaining, room)
            current += Int(Double(applied) * GameConstants.Stats.linearScale)
            remaining -= applied
        }

        // Mid region: 60-80
        if remaining > 0 && current < GameConstants.Stats.midCap {
            let room = GameConstants.Stats.midCap - current
            let applied = min(remaining, room)
            current += Int(Double(applied) * GameConstants.Stats.midScale)
            remaining -= applied
        }

        // High region: 80+
        if remaining > 0 {
            current += Int(Double(remaining) * GameConstants.Stats.highScale)
        }

        return min(current, GameConstants.Stats.hardCap)
    }

    private func fatiguePenalty(energy: Double) -> Double {
        if energy <= GameConstants.Fatigue.threshold3 {
            return GameConstants.Fatigue.penalty3
        } else if energy <= GameConstants.Fatigue.threshold2 {
            return GameConstants.Fatigue.penalty2
        } else if energy <= GameConstants.Fatigue.threshold1 {
            return GameConstants.Fatigue.penalty1
        }
        return 0
    }
}
