import Foundation

enum SkillID: String, Codable, CaseIterable, Sendable {
    // Shared (8)
    case topspin, slice, focus, lobMastery, dropShot, powerServe, spinServe, thirdShot
    // Aggressive exclusive (3)
    case intimidate, powerSurge, smashMaster
    // Defensive exclusive (3)
    case ironWall, counterPunch, softHands
    // All-Rounder exclusive (3)
    case quickStudy, versatile, momentumShift
    // Speedster exclusive (3)
    case erne, sprintRecovery, transitionBurst
    // Strategist exclusive (3)
    case patternRead, shotDisguise, angledMastery
}

struct SkillDefinition: Sendable {
    let id: SkillID
    let name: String
    let description: String
    let icon: String
    let maxRank: Int
    let requiredLevel: Int
    let exclusiveTo: PlayerType?
    let teachingDrills: Set<DrillType>
}

extension SkillDefinition {
    static let all: [SkillDefinition] = [
        // Shared skills
        SkillDefinition(
            id: .topspin, name: "Topspin", description: "Unlocks topspin shot mode — adds forward spin for deeper, faster-bouncing shots.",
            icon: "arrow.up.forward.circle", maxRank: 5, requiredLevel: 3, exclusiveTo: nil,
            teachingDrills: [.returnOfServe]
        ),
        SkillDefinition(
            id: .slice, name: "Slice", description: "Unlocks slice shot mode — adds backspin for low, skidding shots that stay short.",
            icon: "arrow.down.forward.circle", maxRank: 5, requiredLevel: 3, exclusiveTo: nil,
            teachingDrills: [.returnOfServe]
        ),
        SkillDefinition(
            id: .focus, name: "Focus", description: "Unlocks focus mode — trades stamina for pinpoint accuracy on every shot.",
            icon: "scope", maxRank: 5, requiredLevel: 5, exclusiveTo: nil,
            teachingDrills: [.accuracyDrill]
        ),
        SkillDefinition(
            id: .lobMastery, name: "Lob Mastery", description: "Improved lob accuracy and placement — harder for opponents to track and smash.",
            icon: "arrow.up.to.line", maxRank: 5, requiredLevel: 5, exclusiveTo: nil,
            teachingDrills: [.baselineRally]
        ),
        SkillDefinition(
            id: .dropShot, name: "Drop Shot", description: "Enhanced touch and dink placement — shots die closer to the net.",
            icon: "hand.point.down", maxRank: 5, requiredLevel: 8, exclusiveTo: nil,
            teachingDrills: [.dinkingDrill]
        ),
        SkillDefinition(
            id: .powerServe, name: "Power Serve", description: "Increases serve speed and depth — push opponents behind the baseline.",
            icon: "bolt.circle", maxRank: 5, requiredLevel: 10, exclusiveTo: nil,
            teachingDrills: [.servePractice]
        ),
        SkillDefinition(
            id: .spinServe, name: "Spin Serve", description: "Adds spin variation to serves — unpredictable bounces that wrong-foot opponents.",
            icon: "tornado", maxRank: 5, requiredLevel: 13, exclusiveTo: nil,
            teachingDrills: [.servePractice]
        ),
        SkillDefinition(
            id: .thirdShot, name: "Third Shot", description: "Reduced error rate on the rally's third shot — consistent transition play.",
            icon: "3.circle", maxRank: 5, requiredLevel: 15, exclusiveTo: nil,
            teachingDrills: [.baselineRally]
        ),

        // Aggressive exclusive
        SkillDefinition(
            id: .intimidate, name: "Intimidate", description: "A 2-point streak increases the opponent's error rate — mental pressure.",
            icon: "eye.fill", maxRank: 5, requiredLevel: 5, exclusiveTo: .aggressive,
            teachingDrills: [.baselineRally]
        ),
        SkillDefinition(
            id: .powerSurge, name: "Power Surge", description: "Below 30% stamina, power increases — desperation fuels your strongest shots.",
            icon: "flame.fill", maxRank: 5, requiredLevel: 10, exclusiveTo: .aggressive,
            teachingDrills: [.servePractice]
        ),
        SkillDefinition(
            id: .smashMaster, name: "Smash Master", description: "Overhead smash power and success rate increase — dominate the high ball.",
            icon: "hammer.fill", maxRank: 5, requiredLevel: 15, exclusiveTo: .aggressive,
            teachingDrills: [.accuracyDrill]
        ),

        // Defensive exclusive
        SkillDefinition(
            id: .ironWall, name: "Iron Wall", description: "Stamina drain while defending is reduced — outlast your opponent.",
            icon: "shield.fill", maxRank: 5, requiredLevel: 5, exclusiveTo: .defensive,
            teachingDrills: [.returnOfServe]
        ),
        SkillDefinition(
            id: .counterPunch, name: "Counter Punch", description: "After 3+ rally shots, accuracy increases — patience is rewarded.",
            icon: "arrow.turn.up.right", maxRank: 5, requiredLevel: 10, exclusiveTo: .defensive,
            teachingDrills: [.baselineRally]
        ),
        SkillDefinition(
            id: .softHands, name: "Soft Hands", description: "Dink and reset error rate decreases — your touch game is untouchable.",
            icon: "hand.raised.fill", maxRank: 5, requiredLevel: 15, exclusiveTo: .defensive,
            teachingDrills: [.dinkingDrill]
        ),

        // All-Rounder exclusive
        SkillDefinition(
            id: .quickStudy, name: "Quick Study", description: "Bonus XP from coaching sessions and training drills — learn faster.",
            icon: "book.fill", maxRank: 5, requiredLevel: 5, exclusiveTo: .allRounder,
            teachingDrills: [.dinkingDrill]
        ),
        SkillDefinition(
            id: .versatile, name: "Versatile", description: "Small bonus to all shot modes — jack of all trades, master of adaptation.",
            icon: "circle.hexagongrid.fill", maxRank: 5, requiredLevel: 10, exclusiveTo: .allRounder,
            teachingDrills: [.baselineRally]
        ),
        SkillDefinition(
            id: .momentumShift, name: "Momentum Shift", description: "Losing 2 points in a row triggers a temporary stat boost — comeback king.",
            icon: "arrow.triangle.2.circlepath", maxRank: 5, requiredLevel: 15, exclusiveTo: .allRounder,
            teachingDrills: [.returnOfServe]
        ),

        // Speedster exclusive
        SkillDefinition(
            id: .erne, name: "Erne", description: "Unlocks a side-jump attack at the net — surprise volleys that catch opponents flat-footed.",
            icon: "figure.walk", maxRank: 5, requiredLevel: 5, exclusiveTo: .speedster,
            teachingDrills: [.dinkingDrill]
        ),
        SkillDefinition(
            id: .sprintRecovery, name: "Sprint Recovery", description: "Faster movement after shots — get back into position before the ball comes back.",
            icon: "hare.fill", maxRank: 5, requiredLevel: 10, exclusiveTo: .speedster,
            teachingDrills: [.returnOfServe]
        ),
        SkillDefinition(
            id: .transitionBurst, name: "Transition Burst", description: "Speed bonus when approaching the kitchen line — own the transition zone.",
            icon: "bolt.fill", maxRank: 5, requiredLevel: 15, exclusiveTo: .speedster,
            teachingDrills: [.baselineRally]
        ),

        // Strategist exclusive
        SkillDefinition(
            id: .patternRead, name: "Pattern Read", description: "Hints at the opponent's next shot direction — read them like a book.",
            icon: "brain.head.profile", maxRank: 5, requiredLevel: 5, exclusiveTo: .strategist,
            teachingDrills: [.accuracyDrill]
        ),
        SkillDefinition(
            id: .shotDisguise, name: "Shot Disguise", description: "Opponent reaction time decreases — your shots look the same until they're not.",
            icon: "theatermasks", maxRank: 5, requiredLevel: 10, exclusiveTo: .strategist,
            teachingDrills: [.servePractice]
        ),
        SkillDefinition(
            id: .angledMastery, name: "Angled Mastery", description: "Sharper cross-court angles — pull opponents off the court with surgical precision.",
            icon: "angle", maxRank: 5, requiredLevel: 15, exclusiveTo: .strategist,
            teachingDrills: [.accuracyDrill]
        ),
    ]

    static func forPlayerType(_ type: PlayerType) -> [SkillDefinition] {
        all.filter { $0.exclusiveTo == nil || $0.exclusiveTo == type }
    }

    static func definition(for id: SkillID) -> SkillDefinition? {
        all.first { $0.id == id }
    }
}
