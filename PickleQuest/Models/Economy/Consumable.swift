import Foundation

struct Consumable: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let effect: ConsumableEffect
    let price: Int
    let iconName: String
}

enum ConsumableEffect: Codable, Equatable, Sendable {
    case energyRestore(amount: Double)
    case statBoost(stat: StatType, amount: Int, matchDuration: Bool)
    case xpMultiplier(multiplier: Double, matches: Int)
}
