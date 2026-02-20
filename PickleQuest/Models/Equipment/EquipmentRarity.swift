import Foundation
import SwiftUI

enum EquipmentRarity: String, Codable, CaseIterable, Comparable, Sendable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .blue
        case .rare: return .yellow
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    var maxStatBonus: Int {
        switch self {
        case .common: return 3
        case .uncommon: return 5
        case .rare: return 7
        case .epic: return 10
        case .legendary: return 12
        }
    }

    var maxLevel: Int {
        switch self {
        case .common: return 5
        case .uncommon: return 10
        case .rare: return 15
        case .epic: return 20
        case .legendary: return 25
        }
    }

    var baseStatValue: Int {
        switch self {
        case .common: return 2
        case .uncommon: return 3
        case .rare: return 5
        case .epic: return 7
        case .legendary: return 9
        }
    }

    var bonusStatCount: Int {
        switch self {
        case .common: return 0
        case .uncommon: return 1
        case .rare: return 2
        case .epic: return 2
        case .legendary: return 3
        }
    }

    var bonusStatBudget: Int {
        switch self {
        case .common: return 0
        case .uncommon: return 2
        case .rare: return 4
        case .epic: return 6
        case .legendary: return 8
        }
    }

    var hasAbility: Bool {
        self >= .epic
    }

    var traitSlots: (minor: Int, major: Int, unique: Int) {
        switch self {
        case .common: return (0, 0, 0)
        case .uncommon: return (0, 0, 0)
        case .rare: return (1, 0, 0)
        case .epic: return (1, 1, 0)
        case .legendary: return (1, 1, 1)
        }
    }

    var hasTrait: Bool { self >= .rare }

    var dropWeight: Double {
        switch self {
        case .common: return 0.45
        case .uncommon: return 0.30
        case .rare: return 0.15
        case .epic: return 0.08
        case .legendary: return 0.02
        }
    }

    static func < (lhs: EquipmentRarity, rhs: EquipmentRarity) -> Bool {
        let order: [EquipmentRarity] = [.common, .uncommon, .rare, .epic, .legendary]
        guard let l = order.firstIndex(of: lhs), let r = order.firstIndex(of: rhs) else { return false }
        return l < r
    }
}
