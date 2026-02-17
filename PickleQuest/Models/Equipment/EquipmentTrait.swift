import Foundation

struct EquipmentTrait: Codable, Equatable, Sendable {
    let type: TraitType
    let tier: TraitTier
}

enum TraitTier: String, Codable, Sendable, Comparable {
    case minor
    case major
    case unique

    static func < (lhs: TraitTier, rhs: TraitTier) -> Bool {
        let order: [TraitTier] = [.minor, .major, .unique]
        guard let l = order.firstIndex(of: lhs), let r = order.firstIndex(of: rhs) else { return false }
        return l < r
    }

    var displayName: String {
        rawValue.capitalized
    }
}

enum TraitType: String, Codable, Sendable, CaseIterable {
    // Minor traits (rare+) — trade-offs or small bonuses
    case lightfoot       // +2 speed, -1 power
    case heavyHitter     // +2 power, -1 speed
    case spinArtist      // +2 spin, -1 accuracy
    case wallBuilder     // +2 defense, -1 speed
    case quickHands      // +2 reflexes, -1 consistency

    // Major traits (epic+) — multi-stat boosts
    case rallyGrinder    // +3 consistency, +2 stamina
    case courtCoverage   // +3 positioning, +2 speed
    case pressurePlayer  // +3 spin, +2 power
    case steadyEddie     // +3 consistency, +2 focus
    case serveSpecialist // +3 power, +2 accuracy

    // Unique traits (legendary only) — strong single-stat or special
    case clutchGene       // +5 clutch
    case ironConstitution // +5 stamina
    case allRounder       // +2 to all 11 stats

    var tier: TraitTier {
        switch self {
        case .lightfoot, .heavyHitter, .spinArtist, .wallBuilder, .quickHands:
            return .minor
        case .rallyGrinder, .courtCoverage, .pressurePlayer, .steadyEddie, .serveSpecialist:
            return .major
        case .clutchGene, .ironConstitution, .allRounder:
            return .unique
        }
    }

    var statModifiers: [StatType: Int] {
        switch self {
        // Minor
        case .lightfoot:    return [.speed: 2, .power: -1]
        case .heavyHitter:  return [.power: 2, .speed: -1]
        case .spinArtist:   return [.spin: 2, .accuracy: -1]
        case .wallBuilder:  return [.defense: 2, .speed: -1]
        case .quickHands:   return [.reflexes: 2, .consistency: -1]
        // Major
        case .rallyGrinder:    return [.consistency: 3, .stamina: 2]
        case .courtCoverage:   return [.positioning: 3, .speed: 2]
        case .pressurePlayer:  return [.spin: 3, .power: 2]
        case .steadyEddie:     return [.consistency: 3, .focus: 2]
        case .serveSpecialist: return [.power: 3, .accuracy: 2]
        // Unique
        case .clutchGene:       return [.clutch: 5]
        case .ironConstitution: return [.stamina: 5]
        case .allRounder:
            var mods: [StatType: Int] = [:]
            for stat in StatType.allCases { mods[stat] = 2 }
            return mods
        }
    }

    var displayName: String {
        switch self {
        case .lightfoot: return "Lightfoot"
        case .heavyHitter: return "Heavy Hitter"
        case .spinArtist: return "Spin Artist"
        case .wallBuilder: return "Wall Builder"
        case .quickHands: return "Quick Hands"
        case .rallyGrinder: return "Rally Grinder"
        case .courtCoverage: return "Court Coverage"
        case .pressurePlayer: return "Pressure Player"
        case .steadyEddie: return "Steady Eddie"
        case .serveSpecialist: return "Serve Specialist"
        case .clutchGene: return "Clutch Gene"
        case .ironConstitution: return "Iron Constitution"
        case .allRounder: return "All-Rounder"
        }
    }

    var description: String {
        statModifiers.sorted(by: { $0.value > $1.value }).map { stat, value in
            value > 0 ? "+\(value) \(stat.displayName)" : "\(value) \(stat.displayName)"
        }.joined(separator: ", ")
    }
}
