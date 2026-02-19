import Foundation

enum HustlerNPCGenerator {
    /// Generate the 3 pre-defined hustler NPCs.
    /// Uses deterministic UUIDs for consistency across sessions.
    static func generateHustlers() -> [NPC] {
        [hustler1, hustler2, hustler3]
    }

    // MARK: - Hustler 1: Mid-tier

    private static let hustler1 = NPC(
        id: UUID(uuidString: "A0000001-0000-0000-0000-00000000AA01")!,
        name: "Slick Rick",
        title: "The Smooth Talker",
        difficulty: .advanced,
        stats: PlayerStats(
            power: 28, accuracy: 30, spin: 26, speed: 24,
            defense: 26, reflexes: 28, positioning: 30,
            clutch: 32, focus: 30, stamina: 24, consistency: 28
        ),
        playerType: .strategist,
        dialogue: NPCDialogue(
            greeting: "Hey, looking for some action? I play for keeps.",
            onWin: "Pleasure doing business with you.",
            onLose: "Tch. Lucky shots. I'm outta here.",
            taunt: "Money on the line makes it interesting, no?"
        ),
        portraitName: "npc_hustler_1",
        rewardMultiplier: 2.0,
        isHustler: true,
        hiddenStats: true,
        baseWagerAmount: 300,
        skills: MockNPCService.generateSkills(playerType: .strategist, difficulty: .advanced)
    )

    // MARK: - Hustler 2: Upper-tier

    private static let hustler2 = NPC(
        id: UUID(uuidString: "A0000002-0000-0000-0000-00000000AA02")!,
        name: "Diamond Dee",
        title: "The High Roller",
        difficulty: .expert,
        stats: PlayerStats(
            power: 36, accuracy: 38, spin: 32, speed: 34,
            defense: 34, reflexes: 36, positioning: 36,
            clutch: 40, focus: 36, stamina: 30, consistency: 34
        ),
        playerType: .allRounder,
        dialogue: NPCDialogue(
            greeting: "You look like someone who can afford to lose.",
            onWin: "That's what happens when you play with the big dogs.",
            onLose: "What?! You'll never see me here again!",
            taunt: "Double or nothing? Just kidding. Unless..."
        ),
        portraitName: "npc_hustler_2",
        rewardMultiplier: 3.0,
        isHustler: true,
        hiddenStats: true,
        baseWagerAmount: 500,
        skills: MockNPCService.generateSkills(playerType: .allRounder, difficulty: .expert)
    )

    // MARK: - Hustler 3: Top-tier

    private static let hustler3 = NPC(
        id: UUID(uuidString: "A0000003-0000-0000-0000-00000000AA03")!,
        name: "The Shark",
        title: "Court Predator",
        difficulty: .expert,
        stats: PlayerStats(
            power: 40, accuracy: 42, spin: 36, speed: 38,
            defense: 38, reflexes: 40, positioning: 40,
            clutch: 44, focus: 40, stamina: 34, consistency: 38
        ),
        playerType: .aggressive,
        dialogue: NPCDialogue(
            greeting: "Fresh meat. Let's see what you've got.",
            onWin: "Swim with sharks, get bitten.",
            onLose: "This court just got too hot. I'm gone.",
            taunt: "I can smell blood in the water."
        ),
        portraitName: "npc_hustler_3",
        rewardMultiplier: 3.0,
        isHustler: true,
        hiddenStats: true,
        baseWagerAmount: 800,
        skills: MockNPCService.generateSkills(playerType: .aggressive, difficulty: .expert)
    )
}
