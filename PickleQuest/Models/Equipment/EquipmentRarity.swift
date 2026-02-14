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
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    var maxStatBonus: Int {
        switch self {
        case .common: return 5
        case .uncommon: return 10
        case .rare: return 15
        case .epic: return 20
        case .legendary: return 25
        }
    }

    var hasAbility: Bool {
        self >= .epic
    }

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
