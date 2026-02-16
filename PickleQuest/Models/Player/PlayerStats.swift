import Foundation

struct PlayerStats: Equatable, Sendable {
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
    var focus: Int
    var stamina: Int
    var consistency: Int

    init(
        power: Int, accuracy: Int, spin: Int, speed: Int,
        defense: Int, reflexes: Int, positioning: Int,
        clutch: Int, focus: Int = 15, stamina: Int, consistency: Int
    ) {
        self.power = power
        self.accuracy = accuracy
        self.spin = spin
        self.speed = speed
        self.defense = defense
        self.reflexes = reflexes
        self.positioning = positioning
        self.clutch = clutch
        self.focus = focus
        self.stamina = stamina
        self.consistency = consistency
    }

    var allStats: [StatType: Int] {
        [
            .power: power, .accuracy: accuracy, .spin: spin, .speed: speed,
            .defense: defense, .reflexes: reflexes, .positioning: positioning,
            .clutch: clutch, .focus: focus, .stamina: stamina, .consistency: consistency
        ]
    }

    var average: Double {
        let total = power + accuracy + spin + speed + defense + reflexes + positioning + clutch + focus + stamina + consistency
        return Double(total) / 11.0
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
        case .focus: focus = clamped
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
        case .focus: return focus
        case .stamina: return stamina
        case .consistency: return consistency
        }
    }

    static let starter = PlayerStats(
        power: 15, accuracy: 15, spin: 10, speed: 15,
        defense: 15, reflexes: 15, positioning: 15,
        clutch: 10, focus: 15, stamina: 20, consistency: 20
    )
}

// MARK: - Codable (backward compatible)

extension PlayerStats: Codable {
    enum CodingKeys: String, CodingKey {
        case power, accuracy, spin, speed
        case defense, reflexes, positioning
        case clutch, focus, stamina, consistency
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        power = try c.decode(Int.self, forKey: .power)
        accuracy = try c.decode(Int.self, forKey: .accuracy)
        spin = try c.decode(Int.self, forKey: .spin)
        speed = try c.decode(Int.self, forKey: .speed)
        defense = try c.decode(Int.self, forKey: .defense)
        reflexes = try c.decode(Int.self, forKey: .reflexes)
        positioning = try c.decode(Int.self, forKey: .positioning)
        clutch = try c.decode(Int.self, forKey: .clutch)
        focus = try c.decodeIfPresent(Int.self, forKey: .focus) ?? 15
        stamina = try c.decode(Int.self, forKey: .stamina)
        consistency = try c.decode(Int.self, forKey: .consistency)
    }
}

enum StatType: String, Codable, CaseIterable, Sendable {
    case power, accuracy, spin, speed
    case defense, reflexes, positioning
    case clutch, focus, stamina, consistency

    var displayName: String {
        rawValue.capitalized
    }

    var category: StatCategory {
        switch self {
        case .power, .accuracy, .spin, .speed: return .offensive
        case .defense, .reflexes, .positioning: return .defensive
        case .clutch, .focus, .stamina, .consistency: return .mental
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
        case .mental: return [.clutch, .focus, .stamina, .consistency]
        }
    }
}
