import Foundation

actor MockCoachService: CoachService {
    private var courtCoaches: [UUID: Coach] = [:] // courtID → Coach
    private var alphaCoachCourts: Set<UUID> = []   // courts where alpha IS the coach
    private var hasAssigned = false

    private static let predefinedCoaches: [Coach] = [
        Coach(
            id: UUID(uuidString: "C0AC0001-0000-0000-0000-000000000001")!,
            name: "Maria Santos",
            title: "Serve Specialist",
            specialtyStats: [.power, .accuracy],
            tier: 1,
            baseFee: 200,
            dialogue: CoachDialogue(
                greeting: "Ready to work on that serve? Let's make it untouchable!",
                onSession: "Great improvement! Your serve is getting sharper.",
                onDailyLimit: "That's enough for today. Rest up and come back tomorrow!"
            ),
            portraitName: "coach_maria"
        ),
        Coach(
            id: UUID(uuidString: "C0AC0002-0000-0000-0000-000000000002")!,
            name: "Darius Cole",
            title: "Movement Coach",
            specialtyStats: [.speed, .positioning],
            tier: 2,
            baseFee: 500,
            dialogue: CoachDialogue(
                greeting: "Court movement is everything. Let's get those feet moving!",
                onSession: "You're covering the court much better now!",
                onDailyLimit: "Your legs need recovery. See you tomorrow!"
            ),
            portraitName: "coach_darius"
        ),
        Coach(
            id: UUID(uuidString: "C0AC0003-0000-0000-0000-000000000003")!,
            name: "Yuki Tanaka",
            title: "Spin Master",
            specialtyStats: [.spin, .accuracy],
            tier: 2,
            baseFee: 500,
            dialogue: CoachDialogue(
                greeting: "Spin changes everything. Let me show you the angles.",
                onSession: "Beautiful! That spin will confuse your opponents.",
                onDailyLimit: "Your wrist needs rest. Practice what you learned!"
            ),
            portraitName: "coach_yuki"
        ),
        Coach(
            id: UUID(uuidString: "C0AC0004-0000-0000-0000-000000000004")!,
            name: "Reginald \"The Wall\" Brooks",
            title: "Defensive Expert",
            specialtyStats: [.defense, .reflexes],
            tier: 3,
            baseFee: 1000,
            dialogue: CoachDialogue(
                greeting: "Defense wins championships. Let's build that wall.",
                onSession: "Nothing's getting past you now!",
                onDailyLimit: "Even walls need maintenance. Come back tomorrow."
            ),
            portraitName: "coach_reginald"
        ),
        Coach(
            id: UUID(uuidString: "C0AC0005-0000-0000-0000-000000000005")!,
            name: "Zen Masters",
            title: "Mental Game Guru",
            specialtyStats: [.clutch, .consistency],
            tier: 3,
            baseFee: 1000,
            dialogue: CoachDialogue(
                greeting: "The mind controls the paddle. Let's sharpen your focus.",
                onSession: "You're finding that inner calm. Keep it up.",
                onDailyLimit: "Meditation takes time. Reflect on today's lesson."
            ),
            portraitName: "coach_zen"
        ),
        Coach(
            id: UUID(uuidString: "C0AC0006-0000-0000-0000-000000000006")!,
            name: "Sofia Reyes",
            title: "Tactical Genius",
            specialtyStats: [.positioning, .consistency],
            tier: 4,
            baseFee: 2000,
            dialogue: CoachDialogue(
                greeting: "Every shot is a choice. Let's make every choice count.",
                onSession: "Your court IQ just went up a level!",
                onDailyLimit: "Study today's patterns. I'll have new ones tomorrow."
            ),
            portraitName: "coach_sofia"
        )
    ]

    func getCoachAtCourt(_ courtID: UUID) async -> Coach? {
        courtCoaches[courtID]
    }

    func getAllCoaches() async -> [UUID: Coach] {
        courtCoaches
    }

    func isAlphaCoachCourt(_ courtID: UUID) async -> Bool {
        alphaCoachCourts.contains(courtID)
    }

    func setAlphaCoach(_ coach: Coach, courtID: UUID) async {
        courtCoaches[courtID] = coach
    }

    func assignCoaches(to courtIDs: [UUID], courtDifficulties: [UUID: NPCDifficulty]) async {
        guard !hasAssigned else { return }
        hasAssigned = true

        let targetCount = max(1, Int(Double(courtIDs.count) * GameConstants.Coaching.coachCourtPercentage))
        let selectedCourts = Array(courtIDs.shuffled().prefix(targetCount))

        var availableCoaches = Self.predefinedCoaches.shuffled()

        for courtID in selectedCourts {
            // 80% chance: alpha is the coach (will be resolved when court is selected)
            if Double.random(in: 0...1) < GameConstants.Coaching.alphaCoachChance {
                alphaCoachCourts.insert(courtID)
                // Coach will be set dynamically in MapViewModel when alpha is known
            } else {
                // 20% chance: predefined coach
                guard !availableCoaches.isEmpty else {
                    alphaCoachCourts.insert(courtID) // fallback to alpha if no predefined left
                    continue
                }

                let courtDifficulty = courtDifficulties[courtID] ?? .beginner
                let targetTier = tierForDifficulty(courtDifficulty)

                if let matchIdx = availableCoaches.firstIndex(where: { $0.tier == targetTier }) {
                    courtCoaches[courtID] = availableCoaches.remove(at: matchIdx)
                } else {
                    courtCoaches[courtID] = availableCoaches.removeFirst()
                }
            }
        }
    }

    private func tierForDifficulty(_ difficulty: NPCDifficulty) -> Int {
        switch difficulty {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        case .expert, .master: return 4
        }
    }
}
