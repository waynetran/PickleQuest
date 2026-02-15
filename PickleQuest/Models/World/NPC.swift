import Foundation

struct NPC: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let title: String // e.g., "Weekend Warrior", "Court Legend"
    let difficulty: NPCDifficulty
    let stats: PlayerStats
    let personality: NPCPersonality
    let dialogue: NPCDialogue
    let portraitName: String // asset catalog image name
    let rewardMultiplier: Double
    let duprRating: Double

    init(
        id: UUID,
        name: String,
        title: String,
        difficulty: NPCDifficulty,
        stats: PlayerStats,
        personality: NPCPersonality,
        dialogue: NPCDialogue,
        portraitName: String,
        rewardMultiplier: Double,
        duprRating: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.difficulty = difficulty
        self.stats = stats
        self.personality = personality
        self.dialogue = dialogue
        self.portraitName = portraitName
        self.rewardMultiplier = rewardMultiplier
        self.duprRating = duprRating ?? stats.duprRating
    }
}

enum NPCDifficulty: String, Codable, CaseIterable, Sendable, Comparable {
    case beginner
    case intermediate
    case advanced
    case expert
    case master

    var displayName: String {
        rawValue.capitalized
    }

    var rewardMultiplier: Double {
        switch self {
        case .beginner: return 1.0
        case .intermediate: return 1.5
        case .advanced: return 2.0
        case .expert: return 3.0
        case .master: return 5.0
        }
    }

    var color: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "blue"
        case .advanced: return "purple"
        case .expert: return "orange"
        case .master: return "red"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 2
        case .expert: return 3
        case .master: return 4
        }
    }

    static func < (lhs: NPCDifficulty, rhs: NPCDifficulty) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

enum NPCPersonality: String, Codable, Sendable {
    case aggressive    // high power/spin, lower defense
    case defensive     // high defense/positioning, lower power
    case allRounder    // balanced stats
    case speedster     // high speed/reflexes
    case strategist    // high accuracy/consistency/positioning
}

struct NPCDialogue: Codable, Equatable, Sendable {
    let greeting: String
    let onWin: String
    let onLose: String
    let taunt: String
}
