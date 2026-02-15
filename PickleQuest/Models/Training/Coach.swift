import Foundation

struct Coach: Identifiable, Sendable {
    let id: UUID
    let name: String
    let title: String
    let specialtyStats: [StatType]
    let tier: Int // 1-4
    let baseFee: Int
    let dialogue: CoachDialogue
    let portraitName: String
    let isAlphaCoach: Bool
    var alphaDefeated: Bool

    init(
        id: UUID,
        name: String,
        title: String,
        specialtyStats: [StatType],
        tier: Int,
        baseFee: Int,
        dialogue: CoachDialogue,
        portraitName: String,
        isAlphaCoach: Bool = false,
        alphaDefeated: Bool = false
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.specialtyStats = specialtyStats
        self.tier = tier
        self.baseFee = baseFee
        self.dialogue = dialogue
        self.portraitName = portraitName
        self.isAlphaCoach = isAlphaCoach
        self.alphaDefeated = alphaDefeated
    }

    func feeForStat(_ stat: StatType, existingBoosts: Int) -> Int {
        guard specialtyStats.contains(stat) else { return baseFee * 3 }
        let multiplier = pow(GameConstants.Coaching.feeDoublePerExistingBoost, Double(existingBoosts))
        var fee = Int(Double(baseFee) * multiplier)
        if isAlphaCoach && alphaDefeated {
            fee = Int(Double(fee) * GameConstants.Coaching.alphaDefeatedDiscount)
        }
        return max(fee, 1)
    }

    /// Create a coach from the alpha NPC at a court.
    /// Derives specialty stats from the NPC's top 2 stats.
    static func fromAlphaNPC(_ npc: NPC, alphaDefeated: Bool) -> Coach {
        let sorted = npc.stats.allStats.sorted { $0.value > $1.value }
        let topStats = Array(sorted.prefix(2).map(\.key))
        let tier = tierForDifficulty(npc.difficulty)
        let baseFee = GameConstants.Coaching.baseFees[tier] ?? 500

        return Coach(
            id: npc.id,
            name: npc.name,
            title: "\(npc.title) (Coach)",
            specialtyStats: topStats,
            tier: tier,
            baseFee: baseFee,
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

    private static func tierForDifficulty(_ difficulty: NPCDifficulty) -> Int {
        switch difficulty {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        case .expert, .master: return 4
        }
    }
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

    func fee(for coach: Coach, stat: StatType) -> Int {
        let existing = currentBoost(for: stat)
        return coach.feeForStat(stat, existingBoosts: existing)
    }

    func canTrain(stat: StatType) -> Bool {
        currentBoost(for: stat) < GameConstants.Coaching.maxCoachingBoostPerStat
    }

    mutating func recordSession(coachID: UUID, stat: StatType) {
        sessionsToday[coachID.uuidString] = Date()
        statBoosts[stat, default: 0] += GameConstants.Coaching.baseStatBoost
    }

    mutating func resetDailySessions() {
        // Remove sessions that aren't from today
        let calendar = Calendar.current
        sessionsToday = sessionsToday.filter { _, date in
            calendar.isDateInToday(date)
        }
    }
}
