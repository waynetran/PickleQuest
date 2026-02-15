import Foundation

struct RepProfile: Codable, Equatable, Sendable {
    var reputation: Int
    var totalRepEarned: Int // lifetime positive rep

    var title: String {
        switch reputation {
        case ..<0: return "Disgrace"
        case 0..<50: return "Unknown"
        case 50..<150: return "Local Player"
        case 150..<300: return "Rising Star"
        case 300..<500: return "Court Regular"
        case 500..<800: return "Community Favorite"
        case 800..<1200: return "Local Legend"
        default: return "Court Celebrity"
        }
    }

    /// Whether this rep level unlocks NPC selling (at "Local Player" and above)
    var canSellToNPCs: Bool {
        reputation >= 50
    }

    /// Price multiplier when selling to NPCs (higher rep = better prices)
    var sellPriceMultiplier: Double {
        switch reputation {
        case ..<50: return 0.0   // can't sell
        case 50..<150: return 0.4
        case 150..<300: return 0.5
        case 300..<500: return 0.6
        case 500..<800: return 0.7
        case 800..<1200: return 0.85
        default: return 1.0
        }
    }

    mutating func applyRepChange(_ change: Int) {
        reputation += change
        if change > 0 {
            totalRepEarned += change
        }
    }

    static let starter = RepProfile(reputation: 0, totalRepEarned: 0)
}
