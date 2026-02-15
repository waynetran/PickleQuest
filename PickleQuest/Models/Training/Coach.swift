import Foundation

struct Coach: Identifiable, Sendable {
    let id: UUID
    let name: String
    let title: String
    let level: Int // 1-5
    let dialogue: CoachDialogue
    let portraitName: String
    let isAlphaCoach: Bool
    var alphaDefeated: Bool

    init(
        id: UUID,
        name: String,
        title: String,
        level: Int,
        dialogue: CoachDialogue,
        portraitName: String,
        isAlphaCoach: Bool = false,
        alphaDefeated: Bool = false
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.level = min(max(level, 1), 5)
        self.dialogue = dialogue
        self.portraitName = portraitName
        self.isAlphaCoach = isAlphaCoach
        self.alphaDefeated = alphaDefeated
    }

    /// Base fee derived from coach level.
    var baseFee: Int {
        GameConstants.Coaching.coachLevelFees[level] ?? 500
    }

    /// Deterministic daily specialty stat based on coach ID + date.
    var dailySpecialtyStat: StatType {
        let dateString = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }()
        let combined = id.uuidString + dateString
        let hash = abs(combined.hashValue)
        let allStats = StatType.allCases
        return allStats[hash % allStats.count]
    }

    /// The drill type for today's specialty stat.
    var dailyDrillType: DrillType {
        DrillType.forStat(dailySpecialtyStat)
    }

    /// Training fee accounting for existing boosts (diminishing returns).
    func trainingFee(existingBoosts: Int) -> Int {
        let multiplier = pow(GameConstants.Coaching.feeDoublePerExistingBoost, Double(existingBoosts))
        var fee = Int(Double(baseFee) * multiplier)
        if isAlphaCoach && alphaDefeated {
            fee = Int(Double(fee) * GameConstants.Coaching.alphaDefeatedDiscount)
        }
        return max(fee, 1)
    }

    /// Create a coach from the alpha NPC at a court.
    static func fromAlphaNPC(_ npc: NPC, alphaDefeated: Bool) -> Coach {
        let level = levelForDifficulty(npc.difficulty)

        return Coach(
            id: npc.id,
            name: npc.name,
            title: "\(npc.title) (Coach)",
            level: level,
            dialogue: CoachDialogue(
                greeting: alphaDefeated
                    ? "You beat me fair and square. Let me teach you what I know — at a discount."
                    : "I run this court. Pay up if you want to learn from the best.",
                onSession: "Not bad. You might actually have some potential.",
                onDailyLimit: "That's enough for today. Come back tomorrow."
            ),
            portraitName: npc.portraitName,
            isAlphaCoach: true,
            alphaDefeated: alphaDefeated
        )
    }

    private static func levelForDifficulty(_ difficulty: NPCDifficulty) -> Int {
        switch difficulty {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        case .expert: return 4
        case .master: return 5
        }
    }

    /// All-white appearance for coach sprites in drill scenes.
    static let coachAppearance = CharacterAppearance(
        hairColor: "#FFFFFF",
        skinTone: "#FFFFFF",
        shirtColor: "#FFFFFF",
        shortsColor: "#FFFFFF",
        headbandColor: "#FFFFFF",
        shoeColor: "#FFFFFF",
        paddleColor: "#FFFFFF"
    )
}

struct CoachDialogue: Sendable {
    let greeting: String
    let onSession: String
    let onDailyLimit: String
}

struct CoachingRecord: Codable, Equatable, Sendable {
    var sessionsToday: [String: Date] // coachID string → last session date
    var statBoosts: [StatType: Int]   // stat → total coaching boosts applied

    static let empty = CoachingRecord(sessionsToday: [:], statBoosts: [:])

    func hasSessionToday(coachID: UUID) -> Bool {
        guard let lastSession = sessionsToday[coachID.uuidString] else { return false }
        return Calendar.current.isDateInToday(lastSession)
    }

    func currentBoost(for stat: StatType) -> Int {
        statBoosts[stat] ?? 0
    }

    /// Fee for training with a coach (uses coach's daily specialty stat).
    func fee(for coach: Coach) -> Int {
        let existing = currentBoost(for: coach.dailySpecialtyStat)
        return coach.trainingFee(existingBoosts: existing)
    }

    func canTrain(stat: StatType) -> Bool {
        currentBoost(for: stat) < GameConstants.Coaching.maxCoachingBoostPerStat
    }

    mutating func recordSession(coachID: UUID, stat: StatType, amount: Int) {
        sessionsToday[coachID.uuidString] = Date()
        statBoosts[stat, default: 0] += amount
    }

    mutating func resetDailySessions() {
        let calendar = Calendar.current
        sessionsToday = sessionsToday.filter { _, date in
            calendar.isDateInToday(date)
        }
    }
}
