import Foundation

enum DrillType: String, CaseIterable, Codable, Sendable {
    case baselineRally
    case dinkingDrill
    case servePractice
    case returnOfServe

    var displayName: String {
        switch self {
        case .baselineRally: return "Baseline Rally"
        case .dinkingDrill: return "Dinking Drill"
        case .servePractice: return "Serve Practice"
        case .returnOfServe: return "Return of Serve"
        }
    }

    var iconName: String {
        switch self {
        case .baselineRally: return "arrow.left.arrow.right"
        case .dinkingDrill: return "drop.fill"
        case .servePractice: return "figure.tennis"
        case .returnOfServe: return "shield.fill"
        }
    }

    var targetStats: [StatType] {
        switch self {
        case .baselineRally: return [.consistency, .accuracy, .positioning]
        case .dinkingDrill: return [.accuracy, .focus, .consistency]
        case .servePractice: return [.power, .accuracy, .spin]
        case .returnOfServe: return [.defense, .reflexes, .positioning]
        }
    }

    var description: String {
        switch self {
        case .baselineRally: return "Extended rally exchanges to build consistency."
        case .dinkingDrill: return "Soft shots at the kitchen line. Control wins."
        case .servePractice: return "Swipe to serve! Practice placement and power."
        case .returnOfServe: return "Return the coach's serves and aim for the cones."
        }
    }

    /// Maps a stat to the most appropriate drill type for training it.
    static func forStat(_ stat: StatType) -> DrillType {
        switch stat {
        case .power, .spin: return .servePractice
        case .accuracy, .focus: return .dinkingDrill
        case .consistency, .positioning: return .baselineRally
        case .defense, .reflexes: return .returnOfServe
        case .speed, .stamina: return .baselineRally
        case .clutch: return .dinkingDrill
        }
    }
}

struct TrainingDrill: Sendable {
    let id: UUID
    let type: DrillType

    var energyCost: Double {
        GameConstants.Training.drillEnergyCost
    }

    init(type: DrillType) {
        self.id = UUID()
        self.type = type
    }
}
