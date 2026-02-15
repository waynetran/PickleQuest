import Foundation

struct TeamSynergy: Sendable, Codable, Equatable {
    let multiplier: Double
    let description: String

    /// Calculate synergy between two personalities.
    /// Returns a multiplier (0.90-1.10) and a description of the team chemistry.
    static func calculate(p1: NPCPersonality, p2: NPCPersonality) -> TeamSynergy {
        let mult = synergyMatrix[key(p1, p2)] ?? 1.0
        let desc = synergyDescription(multiplier: mult)
        return TeamSynergy(multiplier: mult, description: desc)
    }

    // MARK: - Private

    /// Symmetric lookup: order-independent
    private static func key(_ a: NPCPersonality, _ b: NPCPersonality) -> String {
        let sorted = [a.rawValue, b.rawValue].sorted()
        return "\(sorted[0])-\(sorted[1])"
    }

    /// 5x5 symmetric synergy matrix
    private static let synergyMatrix: [String: Double] = {
        var m: [String: Double] = [:]
        func set(_ a: NPCPersonality, _ b: NPCPersonality, _ val: Double) {
            m[key(a, b)] = val
        }
        // Same personality pairs
        set(.aggressive, .aggressive, 0.92)
        set(.defensive, .defensive, 0.93)
        set(.allRounder, .allRounder, 1.00)
        set(.speedster, .speedster, 0.95)
        set(.strategist, .strategist, 0.94)

        // Cross pairs
        set(.aggressive, .defensive, 1.08)
        set(.aggressive, .allRounder, 1.02)
        set(.aggressive, .speedster, 1.00)
        set(.aggressive, .strategist, 1.05)

        set(.defensive, .allRounder, 1.03)
        set(.defensive, .speedster, 1.06)
        set(.defensive, .strategist, 1.05)

        set(.allRounder, .speedster, 1.02)
        set(.allRounder, .strategist, 1.02)

        set(.speedster, .strategist, 1.07)

        return m
    }()

    private static func synergyDescription(multiplier: Double) -> String {
        switch multiplier {
        case ..<0.94:
            return "Clashing Styles"
        case 0.94..<0.97:
            return "Awkward Fit"
        case 0.97..<1.03:
            return "Solid Teamwork"
        case 1.03..<1.06:
            return "Good Chemistry"
        case 1.06...:
            return "Great Chemistry!"
        default:
            return "Solid Teamwork"
        }
    }
}
