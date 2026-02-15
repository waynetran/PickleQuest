import Foundation

enum EquipmentSlot: String, Codable, CaseIterable, Sendable {
    case paddle
    case shirt
    case shoes
    case bottoms
    case headwear
    case wristband

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .paddle: return "🏓"
        case .shirt: return "👕"
        case .shoes: return "👟"
        case .bottoms: return "🩳"
        case .headwear: return "🧢"
        case .wristband: return "⌚"
        }
    }
}
