import Foundation

struct NPC: Identifiable, Codable, Equatable, Hashable, Sendable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: NPC, rhs: NPC) -> Bool { lhs.id == rhs.id }

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
    let isHustler: Bool
    let hiddenStats: Bool
    let baseWagerAmount: Int

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
        duprRating: Double? = nil,
        isHustler: Bool = false,
        hiddenStats: Bool = false,
        baseWagerAmount: Int = 0
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
        self.isHustler = isHustler
        self.hiddenStats = hiddenStats
        self.baseWagerAmount = baseWagerAmount
    }
    /// Create a practice match opponent at a target DUPR rating.
    static func practiceOpponent(dupr: Double) -> NPC {
        let baseStats = StatProfileLoader.shared.toPlayerStats(dupr: dupr)
        // Add ±20% variance per stat for natural variety
        func vary(_ base: Int) -> Int {
            let variance = max(3, base / 5)
            return max(1, min(99, base + Int.random(in: -variance...variance)))
        }
        let stats = PlayerStats(
            power: vary(baseStats.power), accuracy: vary(baseStats.accuracy),
            spin: vary(baseStats.spin), speed: vary(baseStats.speed),
            defense: vary(baseStats.defense), reflexes: vary(baseStats.reflexes),
            positioning: vary(baseStats.positioning), clutch: vary(baseStats.clutch),
            focus: vary(baseStats.focus), stamina: vary(baseStats.stamina),
            consistency: vary(baseStats.consistency)
        )
        let difficulty: NPCDifficulty
        switch dupr {
        case ..<3.0: difficulty = .beginner
        case ..<4.0: difficulty = .intermediate
        case ..<5.0: difficulty = .advanced
        case ..<6.5: difficulty = .expert
        default: difficulty = .master
        }
        let names = [
            "Coach Bot", "Sparring Partner", "Practice Pro",
            "Rally Robot", "Training Buddy", "Court Helper"
        ]
        let name = names.randomElement()!
        let duprStr = String(format: "%.1f", dupr)
        return NPC(
            id: UUID(),
            name: name,
            title: "DUPR \(duprStr) Practice",
            difficulty: difficulty,
            stats: stats,
            personality: .allRounder,
            dialogue: NPCDialogue(
                greeting: "Let's get some practice in!",
                onWin: "Good game! Keep practicing!",
                onLose: "Nice work out there!",
                taunt: "Ready for another round?"
            ),
            portraitName: "npc_practice",
            rewardMultiplier: 0, // no rewards from practice
            duprRating: dupr
        )
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
