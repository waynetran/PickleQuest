import Foundation

enum ChallengeType: String, Codable, CaseIterable, Sendable {
    case winMatches
    case completeDrills
    case visitCourts
    case beatStrongerNPC
    case winWithoutConsumables
    case playDoublesMatch
    case earnGrade

    var displayName: String {
        switch self {
        case .winMatches: return "Win Matches"
        case .completeDrills: return "Complete Drills"
        case .visitCourts: return "Visit Courts"
        case .beatStrongerNPC: return "Beat Stronger NPC"
        case .winWithoutConsumables: return "Win Clean"
        case .playDoublesMatch: return "Play Doubles"
        case .earnGrade: return "Earn Drill Grade"
        }
    }

    var iconName: String {
        switch self {
        case .winMatches: return "trophy.fill"
        case .completeDrills: return "figure.tennis"
        case .visitCourts: return "map.fill"
        case .beatStrongerNPC: return "bolt.fill"
        case .winWithoutConsumables: return "hand.raised.fill"
        case .playDoublesMatch: return "person.2.fill"
        case .earnGrade: return "star.fill"
        }
    }

    /// Description template for the challenge.
    var descriptionTemplate: String {
        switch self {
        case .winMatches: return "Win %d match(es)"
        case .completeDrills: return "Complete %d drill(s)"
        case .visitCourts: return "Visit %d court(s)"
        case .beatStrongerNPC: return "Beat an NPC with higher SUPR"
        case .winWithoutConsumables: return "Win a match without using consumables"
        case .playDoublesMatch: return "Play a doubles match"
        case .earnGrade: return "Earn a B or better grade in a drill"
        }
    }

    var requiresCount: Bool {
        switch self {
        case .winMatches, .completeDrills, .visitCourts: return true
        default: return false
        }
    }

    var targetCount: Int {
        switch self {
        case .winMatches: return 2
        case .completeDrills: return 2
        case .visitCourts: return 3
        default: return 1
        }
    }
}

struct DailyChallenge: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let type: ChallengeType
    let targetCount: Int
    var currentCount: Int
    let coinReward: Int
    let xpReward: Int

    var isCompleted: Bool {
        currentCount >= targetCount
    }

    var description: String {
        if type.requiresCount {
            return String(format: type.descriptionTemplate, targetCount)
        }
        return type.descriptionTemplate
    }
}

struct DailyChallengeState: Codable, Equatable, Sendable {
    var challenges: [DailyChallenge]
    var lastResetDate: Date
    var bonusClaimed: Bool

    var completedCount: Int {
        challenges.filter(\.isCompleted).count
    }

    var allCompleted: Bool {
        completedCount == challenges.count
    }

    static let empty = DailyChallengeState(
        challenges: [],
        lastResetDate: .distantPast,
        bonusClaimed: false
    )

    mutating func incrementProgress(for type: ChallengeType, by amount: Int = 1) {
        for i in challenges.indices where challenges[i].type == type && !challenges[i].isCompleted {
            challenges[i].currentCount = min(
                challenges[i].currentCount + amount,
                challenges[i].targetCount
            )
        }
    }
}
