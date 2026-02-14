import Foundation

struct PlayerStats: Codable, Equatable, Sendable {
    // Offensive
    var power: Int
    var accuracy: Int
    var spin: Int
    var speed: Int

    // Defensive
    var defense: Int
    var reflexes: Int
    var positioning: Int

    // Mental
    var clutch: Int
    var stamina: Int
    var consistency: Int

    var allStats: [StatType: Int] {
        [
            .power: power, .accuracy: accuracy, .spin: spin, .speed: speed,
            .defense: defense, .reflexes: reflexes, .positioning: positioning,
            .clutch: clutch, .stamina: stamina, .consistency: consistency
        ]
    }

    var average: Double {
        let total = power + accuracy + spin + speed + defense + reflexes + positioning + clutch + stamina + consistency
        return Double(total) / 10.0
    }

    var duprRating: Double {
        GameConstants.DUPR.rating(fromAverageStat: average)
    }

    mutating func setStat(_ type: StatType, value: Int) {
        let clamped = min(max(value, GameConstants.Stats.minValue), GameConstants.Stats.maxValue)
        switch type {
        case .power: power = clamped
        case .accuracy: accuracy = clamped
        case .spin: spin = clamped
        case .speed: speed = clamped
        case .defense: defense = clamped
        case .reflexes: reflexes = clamped
        case .positioning: positioning = clamped
        case .clutch: clutch = clamped
        case .stamina: stamina = clamped
        case .consistency: consistency = clamped
        }
    }

    func stat(_ type: StatType) -> Int {
        switch type {
        case .power: return power
        case .accuracy: return accuracy
        case .spin: return spin
        case .speed: return speed
        case .defense: return defense
        case .reflexes: return reflexes
        case .positioning: return positioning
        case .clutch: return clutch
        case .stamina: return stamina
        case .consistency: return consistency
        }
    }

    static let starter = PlayerStats(
        power: 15, accuracy: 15, spin: 10, speed: 15,
        defense: 15, reflexes: 15, positioning: 15,
        clutch: 10, stamina: 20, consistency: 20
    )
}

enum StatType: String, Codable, CaseIterable, Sendable {
    case power, accuracy, spin, speed
    case defense, reflexes, positioning
    case clutch, stamina, consistency

    var displayName: String {
        rawValue.capitalized
    }

    var category: StatCategory {
        switch self {
        case .power, .accuracy, .spin, .speed: return .offensive
        case .defense, .reflexes, .positioning: return .defensive
        case .clutch, .stamina, .consistency: return .mental
        }
    }
}

enum StatCategory: String, CaseIterable, Sendable {
    case offensive, defensive, mental

    var displayName: String {
        rawValue.capitalized
    }

    var stats: [StatType] {
        switch self {
        case .offensive: return [.power, .accuracy, .spin, .speed]
        case .defensive: return [.defense, .reflexes, .positioning]
        case .mental: return [.clutch, .stamina, .consistency]
        }
    }
}
