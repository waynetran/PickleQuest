import Foundation

struct EquipmentAbility: Codable, Equatable, Sendable {
    let name: String
    let description: String
    let trigger: AbilityTrigger
    let effect: AbilityEffect
}

enum AbilityTrigger: String, Codable, Sendable {
    case onServe
    case onMatchPoint
    case onStreakThree
    case onLowEnergy   // below 30% energy
    case onClutch      // score within 2 points of winning
}

enum AbilityEffect: Codable, Equatable, Sendable {
    case statBoost(stat: StatType, amount: Int, durationPoints: Int)
    case energyRestore(amount: Double)
    case momentumBoost(amount: Double)

    var description: String {
        switch self {
        case .statBoost(let stat, let amount, let duration):
            return "+\(amount) \(stat.displayName) for \(duration) points"
        case .energyRestore(let amount):
            return "Restore \(Int(amount))% energy"
        case .momentumBoost(let amount):
            return "+\(Int(amount * 100))% momentum"
        }
    }
}
