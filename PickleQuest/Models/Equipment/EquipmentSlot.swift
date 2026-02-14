import Foundation

enum EquipmentSlot: String, Codable, CaseIterable, Sendable {
    case paddle
    case shirt
    case shoes
    case shorts
    case eyewear
    case wristband

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .paddle: return "🏓"
        case .shirt: return "👕"
        case .shoes: return "👟"
        case .shorts: return "🩳"
        case .eyewear: return "🕶️"
        case .wristband: return "⌚"
        }
    }
}
