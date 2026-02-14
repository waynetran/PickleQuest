import Foundation

actor MockNPCService: NPCService {
    private let npcs: [NPC]

    init() {
        self.npcs = MockNPCService.createStarterNPCs()
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

    // MARK: - Starter NPCs

    private static func createStarterNPCs() -> [NPC] {
        [
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
            )
        ]
    }
}
