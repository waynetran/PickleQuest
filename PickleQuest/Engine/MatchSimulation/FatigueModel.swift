import Foundation

/// Tracks energy for a single participant during a match.
struct FatigueModel: Sendable {
    private(set) var energy: Double
    let staminaStat: Int
    var stamina: Int { staminaStat }

    init(stamina: Int, startingEnergy: Double = GameConstants.Fatigue.maxEnergy) {
        self.energy = startingEnergy
        self.staminaStat = stamina
    }

    /// Drain energy based on rally length. Returns the new energy level.
    mutating func drainEnergy(rallyLength: Int) -> Double {
        let baseDrain = GameConstants.Fatigue.baseEnergyDrainPerShot * Double(rallyLength)
        let lengthBonus = GameConstants.Fatigue.rallyLengthDrainMultiplier * Double(max(0, rallyLength - 5))
        let staminaReduction = Double(staminaStat) * GameConstants.Fatigue.staminaReductionFactor
        let totalDrain = max(0.1, (baseDrain + lengthBonus) * (1.0 - staminaReduction))
        energy = max(0, energy - totalDrain)
        return energy
    }

    /// Restore a small amount of energy between games.
    mutating func restBetweenGames() {
        energy = min(GameConstants.Fatigue.maxEnergy, energy + 10.0)
    }

    /// Restore energy from a consumable or ability.
    mutating func restore(amount: Double) {
        energy = min(GameConstants.Fatigue.maxEnergy, energy + amount)
    }

    var fatigueLevel: FatigueLevel {
        if energy <= GameConstants.Fatigue.threshold3 { return .severe }
        if energy <= GameConstants.Fatigue.threshold2 { return .moderate }
        if energy <= GameConstants.Fatigue.threshold1 { return .mild }
        return .fresh
    }
}

enum FatigueLevel: String, Sendable {
    case fresh
    case mild
    case moderate
    case severe
}
