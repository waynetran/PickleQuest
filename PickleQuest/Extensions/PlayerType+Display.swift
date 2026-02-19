import Foundation

extension PlayerType {
    var displayName: String {
        switch self {
        case .aggressive: return "Power Player"
        case .defensive: return "The Wall"
        case .allRounder: return "All-Rounder"
        case .speedster: return "Speedster"
        case .strategist: return "Strategist"
        }
    }

    var displayDescription: String {
        switch self {
        case .aggressive:
            return "Dominate with raw power and aggressive spin. Higher power and spin, but lower defense."
        case .defensive:
            return "Outlast opponents with rock-solid defense and smart positioning. Higher defense, but lower power."
        case .allRounder:
            return "Jack of all trades. Balanced stats across the board with no major weaknesses."
        case .speedster:
            return "Blinding speed and lightning reflexes. Cover the whole court, but less raw power."
        case .strategist:
            return "Pinpoint accuracy and unshakable consistency. Win with brains over brawn."
        }
    }

    var displayIcon: String {
        switch self {
        case .aggressive: return "flame.fill"
        case .defensive: return "shield.fill"
        case .allRounder: return "circle.hexagongrid.fill"
        case .speedster: return "bolt.fill"
        case .strategist: return "brain.head.profile"
        }
    }

    var statBias: [StatType: Int] {
        switch self {
        case .aggressive:
            return [.power: 4, .spin: 3, .defense: -3, .positioning: -2, .consistency: -2]
        case .defensive:
            return [.defense: 4, .positioning: 3, .power: -3, .spin: -2, .speed: -2]
        case .allRounder:
            return [:]
        case .speedster:
            return [.speed: 4, .reflexes: 3, .power: -3, .spin: -2, .clutch: -2]
        case .strategist:
            return [.accuracy: 4, .consistency: 3, .power: -3, .speed: -2, .spin: -2]
        }
    }

    var exclusiveSkillPreview: [SkillID] {
        switch self {
        case .aggressive: return [.intimidate, .powerSurge, .smashMaster]
        case .defensive: return [.ironWall, .counterPunch, .softHands]
        case .allRounder: return [.quickStudy, .versatile, .momentumShift]
        case .speedster: return [.erne, .sprintRecovery, .transitionBurst]
        case .strategist: return [.patternRead, .shotDisguise, .angledMastery]
        }
    }
}
