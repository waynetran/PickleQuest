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
        let hash = djb2Hash(combined)
        let allStats = StatType.allCases
        return allStats[hash % allStats.count]
    }

    /// The drill type for today's specialty stat.
    var dailyDrillType: DrillType {
        DrillType.forStat(dailySpecialtyStat)
    }

    /// Flat training fee (with alpha discount if applicable).
    func trainingFee() -> Int {
        var fee = baseFee
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
                onExhausted: "I'm spent for today. Come back tomorrow."
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

/// Deterministic hash (djb2) — stable across process launches unlike String.hashValue.
private func djb2Hash(_ string: String) -> Int {
    var hash: UInt64 = 5381
    for byte in string.utf8 {
        hash = hash &* 33 &+ UInt64(byte)
    }
    return Int(hash % UInt64(Int.max))
}

struct CoachDialogue: Sendable {
    let greeting: String
    let onSession: String
    let onExhausted: String
}

struct CoachEnergyEntry: Codable, Equatable, Sendable {
    var energy: Double
    var date: Date
}

struct CoachingRecord: Codable, Equatable, Sendable {
    var sessionsToday: [String: Date] // coachID string → last session date
    var statBoosts: [StatType: Int]   // stat → total coaching boosts applied
    var coachDailyEnergy: [String: CoachEnergyEntry] // coachID → energy for the day

    init(sessionsToday: [String: Date] = [:], statBoosts: [StatType: Int] = [:], coachDailyEnergy: [String: CoachEnergyEntry] = [:]) {
        self.sessionsToday = sessionsToday
        self.statBoosts = statBoosts
        self.coachDailyEnergy = coachDailyEnergy
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionsToday = try c.decodeIfPresent([String: Date].self, forKey: .sessionsToday) ?? [:]
        statBoosts = try c.decodeIfPresent([StatType: Int].self, forKey: .statBoosts) ?? [:]
        coachDailyEnergy = try c.decodeIfPresent([String: CoachEnergyEntry].self, forKey: .coachDailyEnergy) ?? [:]
    }

    static let empty = CoachingRecord(sessionsToday: [:], statBoosts: [:], coachDailyEnergy: [:])

    /// Remaining energy for a coach today (100% if no sessions yet).
    func coachRemainingEnergy(coachID: UUID) -> Double {
        guard let entry = coachDailyEnergy[coachID.uuidString],
              Calendar.current.isDateInToday(entry.date) else {
            return GameConstants.Coaching.coachMaxEnergy
        }
        return max(0, entry.energy)
    }

    /// Drain a coach's energy after a session.
    mutating func drainCoach(coachID: UUID, amount: Double) {
        let key = coachID.uuidString
        var current = coachRemainingEnergy(coachID: coachID)
        current = max(0, current - amount)
        coachDailyEnergy[key] = CoachEnergyEntry(energy: current, date: Date())
    }

    func currentBoost(for stat: StatType) -> Int {
        statBoosts[stat] ?? 0
    }

    /// Flat fee for training with a coach.
    func fee(for coach: Coach) -> Int {
        coach.trainingFee()
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
        coachDailyEnergy = coachDailyEnergy.filter { _, entry in
            calendar.isDateInToday(entry.date)
        }
    }
}
