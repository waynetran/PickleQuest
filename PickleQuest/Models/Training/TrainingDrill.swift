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
        case .returnOfServe: return "Accuracy Drill"
        }
    }

    var iconName: String {
        switch self {
        case .baselineRally: return "arrow.left.arrow.right"
        case .dinkingDrill: return "drop.fill"
        case .servePractice: return "figure.tennis"
        case .returnOfServe: return "scope"
        }
    }

    var targetStats: [StatType] {
        switch self {
        case .baselineRally: return [.consistency, .accuracy, .positioning]
        case .dinkingDrill: return [.accuracy, .focus, .consistency]
        case .servePractice: return [.power, .accuracy, .spin]
        case .returnOfServe: return [.accuracy, .focus, .positioning]
        }
    }

    var description: String {
        switch self {
        case .baselineRally: return "Extended rally exchanges to build consistency."
        case .dinkingDrill: return "Soft shots at the kitchen line. Control wins."
        case .servePractice: return "Swipe to serve! Practice placement and power."
        case .returnOfServe: return "Return serves and aim for the cone targets."
        }
    }

    /// Maps a stat to the most appropriate drill type for training it.
    static func forStat(_ stat: StatType) -> DrillType {
        switch stat {
        case .power, .spin: return .servePractice
        case .accuracy, .focus: return .returnOfServe
        case .consistency, .positioning: return .baselineRally
        case .defense, .reflexes: return .baselineRally
        case .speed, .stamina: return .dinkingDrill
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
