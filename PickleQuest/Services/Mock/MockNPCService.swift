import Foundation

actor MockNPCService: NPCService {
    private let npcs: [NPC]

    init() {
        self.npcs = MockNPCService.createAllNPCs()
    }

    func getAllNPCs() async -> [NPC] {
        npcs
    }

    func getNPC(by id: UUID) async -> NPC? {
        npcs.first { $0.id == id }
    }

    func getNPCs(forDifficulty difficulty: NPCDifficulty) async -> [NPC] {
        npcs.filter { $0.difficulty == difficulty }
    }

    // MARK: - NPC Roster

    private static func createAllNPCs() -> [NPC] {
        beginnerNPCs + intermediateNPCs + advancedNPCs + expertNPCs + masterNPCs
    }

    // MARK: Beginner (~10-15 avg)

    private static let beginnerNPCs: [NPC] = [
        NPC(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000001")!,
            name: "Gentle Gary",
            title: "Weekend Warrior",
            difficulty: .beginner,
            stats: PlayerStats(
                power: 10, accuracy: 12, spin: 5, speed: 10,
                defense: 12, reflexes: 10, positioning: 12,
                clutch: 8, stamina: 15, consistency: 15
            ),
            personality: .defensive,
            dialogue: NPCDialogue(
                greeting: "Hey there! Want to hit some balls around?",
                onWin: "Good game! I need more practice.",
                onLose: "Wow, nice shots! You're getting better!",
                taunt: "I may be slow, but I'm steady!"
            ),
            portraitName: "npc_gary",
            rewardMultiplier: 1.0
        ),
        NPC(
            id: UUID(uuidString: "00000002-0000-0000-0000-000000000002")!,
            name: "Speedy Sam",
            title: "Court Sprinter",
            difficulty: .beginner,
            stats: PlayerStats(
                power: 8, accuracy: 10, spin: 8, speed: 20,
                defense: 10, reflexes: 18, positioning: 8,
                clutch: 10, stamina: 12, consistency: 10
            ),
            personality: .speedster,
            dialogue: NPCDialogue(
                greeting: "Catch me if you can!",
                onWin: "Maybe I was too fast for ya!",
                onLose: "Okay, you caught me. Rematch?",
                taunt: "Zoom zoom!"
            ),
            portraitName: "npc_sam",
            rewardMultiplier: 1.0
        ),
        NPC(
            id: UUID(uuidString: "00000007-0000-0000-0000-000000000007")!,
            name: "Nervous Nora",
            title: "The Overthinker",
            difficulty: .beginner,
            stats: PlayerStats(
                power: 10, accuracy: 14, spin: 8, speed: 12,
                defense: 10, reflexes: 12, positioning: 10,
                clutch: 5, stamina: 14, consistency: 16
            ),
            personality: .allRounder,
            dialogue: NPCDialogue(
                greeting: "Oh gosh, okay, I can do this... probably.",
                onWin: "Wait, I won? I WON!",
                onLose: "I knew it. I should've stayed home.",
                taunt: "Please don't hit it too hard..."
            ),
            portraitName: "npc_nora",
            rewardMultiplier: 1.0
        ),
        NPC(
            id: UUID(uuidString: "00000008-0000-0000-0000-000000000008")!,
            name: "Big Serve Bob",
            title: "The Cannon",
            difficulty: .beginner,
            stats: PlayerStats(
                power: 20, accuracy: 8, spin: 10, speed: 8,
                defense: 6, reflexes: 8, positioning: 6,
                clutch: 12, stamina: 10, consistency: 5
            ),
            personality: .aggressive,
            dialogue: NPCDialogue(
                greeting: "You ready for the big serve?",
                onWin: "Nothing beats raw power, baby!",
                onLose: "Maybe I should learn some finesse...",
                taunt: "INCOMING!"
            ),
            portraitName: "npc_bob",
            rewardMultiplier: 1.0
        ),
    ]

    // MARK: Intermediate (~15-25 avg)

    private static let intermediateNPCs: [NPC] = [
        NPC(
            id: UUID(uuidString: "00000003-0000-0000-0000-000000000003")!,
            name: "Consistent Clara",
            title: "The Wall",
            difficulty: .intermediate,
            stats: PlayerStats(
                power: 15, accuracy: 20, spin: 12, speed: 15,
                defense: 22, reflexes: 18, positioning: 20,
                clutch: 15, stamina: 20, consistency: 25
            ),
            personality: .defensive,
            dialogue: NPCDialogue(
                greeting: "I never miss. Ready to test that?",
                onWin: "Every ball comes back. Every. Single. One.",
                onLose: "Hmm, I'll need to tighten up my game.",
                taunt: "You'll have to earn every point."
            ),
            portraitName: "npc_clara",
            rewardMultiplier: 1.5
        ),
        NPC(
            id: UUID(uuidString: "00000004-0000-0000-0000-000000000004")!,
            name: "Power Pete",
            title: "The Hammer",
            difficulty: .intermediate,
            stats: PlayerStats(
                power: 28, accuracy: 15, spin: 20, speed: 12,
                defense: 10, reflexes: 12, positioning: 10,
                clutch: 18, stamina: 15, consistency: 12
            ),
            personality: .aggressive,
            dialogue: NPCDialogue(
                greeting: "Hope you're ready for some heat!",
                onWin: "BOOM! That's the power of Pete!",
                onLose: "Huh... power isn't everything I guess.",
                taunt: "Here comes the thunder!"
            ),
            portraitName: "npc_pete",
            rewardMultiplier: 1.5
        ),
        NPC(
            id: UUID(uuidString: "00000009-0000-0000-0000-000000000009")!,
            name: "Tricky Tanya",
            title: "The Illusionist",
            difficulty: .intermediate,
            stats: PlayerStats(
                power: 14, accuracy: 22, spin: 25, speed: 16,
                defense: 15, reflexes: 16, positioning: 18,
                clutch: 20, stamina: 18, consistency: 20
            ),
            personality: .strategist,
            dialogue: NPCDialogue(
                greeting: "Think you can read my shots? Good luck.",
                onWin: "You never saw it coming, did you?",
                onLose: "Fine, you cracked the code. This time.",
                taunt: "Was that a drop shot or a drive? Even I don't know."
            ),
            portraitName: "npc_tanya",
            rewardMultiplier: 1.5
        ),
        NPC(
            id: UUID(uuidString: "0000000a-0000-0000-0000-00000000000a")!,
            name: "Marathon Mike",
            title: "The Endurance King",
            difficulty: .intermediate,
            stats: PlayerStats(
                power: 12, accuracy: 18, spin: 10, speed: 18,
                defense: 20, reflexes: 15, positioning: 22,
                clutch: 14, stamina: 28, consistency: 24
            ),
            personality: .defensive,
            dialogue: NPCDialogue(
                greeting: "I can do this all day. Can you?",
                onWin: "Outlasted ya. That's the game plan.",
                onLose: "Wow, you kept up. Respect.",
                taunt: "Getting tired yet? I'm just warming up."
            ),
            portraitName: "npc_mike",
            rewardMultiplier: 1.5
        ),
    ]

    // MARK: Advanced (~20-30 avg)

    private static let advancedNPCs: [NPC] = [
        NPC(
            id: UUID(uuidString: "00000005-0000-0000-0000-000000000005")!,
            name: "Strategic Sarah",
            title: "The Tactician",
            difficulty: .advanced,
            stats: PlayerStats(
                power: 20, accuracy: 30, spin: 25, speed: 20,
                defense: 25, reflexes: 22, positioning: 30,
                clutch: 25, stamina: 22, consistency: 28
            ),
            personality: .strategist,
            dialogue: NPCDialogue(
                greeting: "I've already analyzed your weaknesses.",
                onWin: "Calculated. As expected.",
                onLose: "Interesting... I didn't account for that variable.",
                taunt: "Every shot has a purpose."
            ),
            portraitName: "npc_sarah",
            rewardMultiplier: 2.0
        ),
        NPC(
            id: UUID(uuidString: "0000000b-0000-0000-0000-00000000000b")!,
            name: "Ace Angela",
            title: "Serve Machine",
            difficulty: .advanced,
            stats: PlayerStats(
                power: 32, accuracy: 28, spin: 22, speed: 22,
                defense: 18, reflexes: 20, positioning: 18,
                clutch: 28, stamina: 20, consistency: 22
            ),
            personality: .aggressive,
            dialogue: NPCDialogue(
                greeting: "Hope you packed a helmet.",
                onWin: "Another ace to add to my collection.",
                onLose: "You... returned that? Impressive.",
                taunt: "Try returning THIS one."
            ),
            portraitName: "npc_angela",
            rewardMultiplier: 2.0
        ),
        NPC(
            id: UUID(uuidString: "0000000c-0000-0000-0000-00000000000c")!,
            name: "Zen Zack",
            title: "The Monk",
            difficulty: .advanced,
            stats: PlayerStats(
                power: 18, accuracy: 26, spin: 20, speed: 22,
                defense: 30, reflexes: 28, positioning: 32,
                clutch: 22, stamina: 26, consistency: 30
            ),
            personality: .defensive,
            dialogue: NPCDialogue(
                greeting: "The court speaks. I listen.",
                onWin: "Flow like water, strike like stone.",
                onLose: "Your spirit was strong today. I must meditate on this.",
                taunt: "Breathe. Focus. You'll need it."
            ),
            portraitName: "npc_zack",
            rewardMultiplier: 2.0
        ),
        NPC(
            id: UUID(uuidString: "0000000d-0000-0000-0000-00000000000d")!,
            name: "Quick Quinn",
            title: "The Flash",
            difficulty: .advanced,
            stats: PlayerStats(
                power: 22, accuracy: 24, spin: 18, speed: 35,
                defense: 22, reflexes: 32, positioning: 20,
                clutch: 24, stamina: 24, consistency: 22
            ),
            personality: .speedster,
            dialogue: NPCDialogue(
                greeting: "Blink and you'll miss the point.",
                onWin: "Too quick for you? Don't feel bad.",
                onLose: "Okay, you're fast too. I respect that.",
                taunt: "Already there. Where were you?"
            ),
            portraitName: "npc_quinn",
            rewardMultiplier: 2.0
        ),
    ]

    // MARK: Expert (~30-40 avg)

    private static let expertNPCs: [NPC] = [
        NPC(
            id: UUID(uuidString: "00000006-0000-0000-0000-000000000006")!,
            name: "Lightning Liu",
            title: "Court Legend",
            difficulty: .expert,
            stats: PlayerStats(
                power: 35, accuracy: 38, spin: 30, speed: 40,
                defense: 35, reflexes: 40, positioning: 35,
                clutch: 38, stamina: 30, consistency: 35
            ),
            personality: .allRounder,
            dialogue: NPCDialogue(
                greeting: "Few challengers make it this far. Impressive.",
                onWin: "That was... closer than I expected.",
                onLose: "A worthy opponent. I'll remember this.",
                taunt: "Watch closely — you might learn something."
            ),
            portraitName: "npc_liu",
            rewardMultiplier: 3.0
        ),
        NPC(
            id: UUID(uuidString: "0000000e-0000-0000-0000-00000000000e")!,
            name: "Iron Ivan",
            title: "The Fortress",
            difficulty: .expert,
            stats: PlayerStats(
                power: 30, accuracy: 35, spin: 28, speed: 28,
                defense: 42, reflexes: 38, positioning: 40,
                clutch: 35, stamina: 38, consistency: 40
            ),
            personality: .defensive,
            dialogue: NPCDialogue(
                greeting: "Nothing gets past me. Nothing.",
                onWin: "An impenetrable defense wins every time.",
                onLose: "You found a crack in the armor. It won't happen again.",
                taunt: "Go ahead, hit your hardest. I'll still return it."
            ),
            portraitName: "npc_ivan",
            rewardMultiplier: 3.0
        ),
        NPC(
            id: UUID(uuidString: "0000000f-0000-0000-0000-00000000000f")!,
            name: "Smash Suki",
            title: "The Destroyer",
            difficulty: .expert,
            stats: PlayerStats(
                power: 42, accuracy: 35, spin: 35, speed: 32,
                defense: 28, reflexes: 30, positioning: 25,
                clutch: 38, stamina: 28, consistency: 30
            ),
            personality: .aggressive,
            dialogue: NPCDialogue(
                greeting: "I don't do gentle. Ready?",
                onWin: "SMASHED. Next challenger, please.",
                onLose: "...fine. You earned that one.",
                taunt: "This next shot? You're not returning it."
            ),
            portraitName: "npc_suki",
            rewardMultiplier: 3.0
        ),
    ]

    // MARK: Master (~40-50 avg)

    private static let masterNPCs: [NPC] = [
        NPC(
            id: UUID(uuidString: "00000010-0000-0000-0000-000000000010")!,
            name: "The Professor",
            title: "Grandmaster",
            difficulty: .master,
            stats: PlayerStats(
                power: 40, accuracy: 48, spin: 42, speed: 38,
                defense: 42, reflexes: 40, positioning: 50,
                clutch: 45, stamina: 40, consistency: 48
            ),
            personality: .strategist,
            dialogue: NPCDialogue(
                greeting: "Ah, a student approaches. Let's see what you've learned.",
                onWin: "The lesson today: experience trumps all.",
                onLose: "The student surpasses the teacher. A proud day.",
                taunt: "I knew what you'd do before you did."
            ),
            portraitName: "npc_professor",
            rewardMultiplier: 5.0
        ),
        NPC(
            id: UUID(uuidString: "00000011-0000-0000-0000-000000000011")!,
            name: "Blaze",
            title: "The Untouchable",
            difficulty: .master,
            stats: PlayerStats(
                power: 45, accuracy: 45, spin: 40, speed: 48,
                defense: 40, reflexes: 48, positioning: 42,
                clutch: 50, stamina: 38, consistency: 42
            ),
            personality: .allRounder,
            dialogue: NPCDialogue(
                greeting: "...",
                onWin: "Next.",
                onLose: "Interesting.",
                taunt: "..."
            ),
            portraitName: "npc_blaze",
            rewardMultiplier: 5.0
        ),
    ]
}
