import Foundation

enum TutorialNPC {
    static let opponent = NPC(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Coach Pickles",
        title: "Your First Opponent",
        difficulty: .beginner,
        stats: PlayerStats(
            power: 5, accuracy: 5, spin: 3, speed: 5,
            defense: 5, reflexes: 5, positioning: 5,
            clutch: 3, focus: 3, stamina: 5, consistency: 5
        ),
        playerType: .allRounder,
        dialogue: NPCDialogue(
            greeting: "Welcome to the court! Let's see what you've got, rookie!",
            onWin: "Not bad for your first match! You've got potential!",
            onLose: "Hey, no worries! Everyone starts somewhere. Let's try again!",
            taunt: "Come on, you can do better than that!"
        ),
        portraitName: "npc_coach",
        rewardMultiplier: 2.0,
        duprRating: 2.0
    )
}
