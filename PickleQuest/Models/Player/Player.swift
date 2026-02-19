import Foundation

struct Player: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var stats: PlayerStats
    var progression: PlayerProgression
    var equippedItems: [EquipmentSlot: UUID] // slot → equipment ID
    var wallet: Wallet
    var duprProfile: DUPRProfile
    var matchHistory: [MatchHistoryEntry] = []
    var appearance: CharacterAppearance = .defaultPlayer
    var repProfile: RepProfile = .starter
    var consumables: [Consumable] = []
    var energy: Double = GameConstants.PersistentEnergy.maxEnergy
    var lastMatchDate: Date? = nil
    var discoveredCourtIDs: Set<UUID> = []
    var courtLadders: [CourtLadder] = []
    var courtPerks: [CourtPerk] = []
    var playerType: PlayerType = .allRounder
    var personality: Personality = .competitive
    var skills: [PlayerSkill] = []
    var skillLessonProgress: [SkillID: SkillLessonProgress] = [:]
    var coachingRecord: CoachingRecord = .empty
    var dailyChallengeState: DailyChallengeState? = nil
    var npcLossRecord: [UUID: Int] = [:] // NPC ID → consecutive player wins (for wager refusal)
    var gearDropState: GearDropState? = nil

    init(id: UUID, name: String, stats: PlayerStats, progression: PlayerProgression,
         equippedItems: [EquipmentSlot: UUID], wallet: Wallet, duprProfile: DUPRProfile,
         matchHistory: [MatchHistoryEntry] = [], appearance: CharacterAppearance = .defaultPlayer,
         repProfile: RepProfile = .starter, consumables: [Consumable] = [],
         energy: Double = GameConstants.PersistentEnergy.maxEnergy, lastMatchDate: Date? = nil,
         discoveredCourtIDs: Set<UUID> = [], courtLadders: [CourtLadder] = [],
         courtPerks: [CourtPerk] = [], playerType: PlayerType = .allRounder,
         personality: Personality = .competitive,
         skills: [PlayerSkill] = [], skillLessonProgress: [SkillID: SkillLessonProgress] = [:],
         coachingRecord: CoachingRecord = .empty, dailyChallengeState: DailyChallengeState? = nil,
         npcLossRecord: [UUID: Int] = [:], gearDropState: GearDropState? = nil) {
        self.id = id
        self.name = name
        self.stats = stats
        self.progression = progression
        self.equippedItems = equippedItems
        self.wallet = wallet
        self.duprProfile = duprProfile
        self.matchHistory = matchHistory
        self.appearance = appearance
        self.repProfile = repProfile
        self.consumables = consumables
        self.energy = energy
        self.lastMatchDate = lastMatchDate
        self.discoveredCourtIDs = discoveredCourtIDs
        self.courtLadders = courtLadders
        self.courtPerks = courtPerks
        self.playerType = playerType
        self.personality = personality
        self.skills = skills
        self.skillLessonProgress = skillLessonProgress
        self.coachingRecord = coachingRecord
        self.dailyChallengeState = dailyChallengeState
        self.npcLossRecord = npcLossRecord
        self.gearDropState = gearDropState
    }

    var duprRating: Double {
        duprProfile.rating
    }

    /// Current energy accounting for real-time recovery since last match
    var currentEnergy: Double {
        guard let lastMatch = lastMatchDate else { return energy }
        let minutesElapsed = Date().timeIntervalSince(lastMatch) / 60.0
        let recovered = minutesElapsed * GameConstants.PersistentEnergy.recoveryPerMinute
        return min(GameConstants.PersistentEnergy.maxEnergy, energy + recovered)
    }

    /// Sum of SUPR changes in the current calendar month
    var monthlyDUPRDelta: Double {
        let calendar = Calendar.current
        let now = Date()
        return matchHistory
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .compactMap(\.duprChange)
            .reduce(0, +)
    }

    var hasPaddleEquipped: Bool {
        equippedItems[.paddle] != nil
    }

    var currentWinStreak: Int {
        var streak = 0
        for entry in matchHistory.reversed() {
            if entry.didWin { streak += 1 } else { break }
        }
        return streak
    }

    var bestWinStreak: Int {
        var best = 0
        var current = 0
        for entry in matchHistory {
            if entry.didWin {
                current += 1
                if current > best { best = current }
            } else {
                current = 0
            }
        }
        return best
    }

    var overallWinRate: Double {
        guard !matchHistory.isEmpty else { return 0 }
        let wins = matchHistory.filter(\.didWin).count
        return Double(wins) / Double(matchHistory.count)
    }

    // MARK: - Codable (backwards-compatible with older saves)

    enum CodingKeys: String, CodingKey {
        case id, name, stats, progression, equippedItems, wallet, duprProfile
        case matchHistory, appearance, repProfile, consumables, energy, lastMatchDate
        case discoveredCourtIDs, courtLadders, courtPerks
        case playerType = "personality"
        case personality = "dialogPersonality"
        case skills, skillLessonProgress
        case coachingRecord, dailyChallengeState, npcLossRecord, gearDropState
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        stats = try c.decode(PlayerStats.self, forKey: .stats)
        progression = try c.decode(PlayerProgression.self, forKey: .progression)
        equippedItems = try c.decode([EquipmentSlot: UUID].self, forKey: .equippedItems)
        wallet = try c.decode(Wallet.self, forKey: .wallet)
        duprProfile = try c.decode(DUPRProfile.self, forKey: .duprProfile)
        matchHistory = try c.decodeIfPresent([MatchHistoryEntry].self, forKey: .matchHistory) ?? []
        appearance = try c.decodeIfPresent(CharacterAppearance.self, forKey: .appearance) ?? .defaultPlayer
        repProfile = try c.decodeIfPresent(RepProfile.self, forKey: .repProfile) ?? .starter
        consumables = try c.decodeIfPresent([Consumable].self, forKey: .consumables) ?? []
        energy = try c.decodeIfPresent(Double.self, forKey: .energy) ?? GameConstants.PersistentEnergy.maxEnergy
        lastMatchDate = try c.decodeIfPresent(Date.self, forKey: .lastMatchDate)
        discoveredCourtIDs = try c.decodeIfPresent(Set<UUID>.self, forKey: .discoveredCourtIDs) ?? []
        courtLadders = try c.decodeIfPresent([CourtLadder].self, forKey: .courtLadders) ?? []
        courtPerks = try c.decodeIfPresent([CourtPerk].self, forKey: .courtPerks) ?? []
        playerType = try c.decodeIfPresent(PlayerType.self, forKey: .playerType) ?? .allRounder
        personality = try c.decodeIfPresent(Personality.self, forKey: .personality) ?? .competitive
        skills = try c.decodeIfPresent([PlayerSkill].self, forKey: .skills) ?? []
        skillLessonProgress = try c.decodeIfPresent([SkillID: SkillLessonProgress].self, forKey: .skillLessonProgress) ?? [:]
        coachingRecord = try c.decodeIfPresent(CoachingRecord.self, forKey: .coachingRecord) ?? .empty
        dailyChallengeState = try c.decodeIfPresent(DailyChallengeState.self, forKey: .dailyChallengeState)
        npcLossRecord = try c.decodeIfPresent([UUID: Int].self, forKey: .npcLossRecord) ?? [:]
        gearDropState = try c.decodeIfPresent(GearDropState.self, forKey: .gearDropState)
    }

    static func newPlayer(name: String) -> Player {
        Player(
            id: UUID(),
            name: name,
            stats: .starter,
            progression: .starter,
            equippedItems: [
                .paddle: UUID(uuidString: "10000001-0000-0000-0000-000000000001")!,
                .shoes: UUID(uuidString: "10000002-0000-0000-0000-000000000002")!,
                .shirt: UUID(uuidString: "10000003-0000-0000-0000-000000000003")!
            ],
            wallet: Wallet(coins: GameConstants.Economy.startingCoins),
            duprProfile: .starter
        )
    }
}
