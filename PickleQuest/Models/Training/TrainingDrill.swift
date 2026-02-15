import Foundation

enum DrillType: String, CaseIterable, Codable, Sendable {
    case servePractice
    case rallyDrill
    case defenseDrill
    case footworkTraining

    var displayName: String {
        switch self {
        case .servePractice: return "Serve Practice"
        case .rallyDrill: return "Rally Drill"
        case .defenseDrill: return "Defense Drill"
        case .footworkTraining: return "Footwork Training"
        }
    }

    var iconName: String {
        switch self {
        case .servePractice: return "figure.tennis"
        case .rallyDrill: return "arrow.left.arrow.right"
        case .defenseDrill: return "shield.fill"
        case .footworkTraining: return "figure.run"
        }
    }

    var targetStats: [StatType] {
        switch self {
        case .servePractice: return [.power, .accuracy, .spin]
        case .rallyDrill: return [.consistency, .accuracy, .positioning]
        case .defenseDrill: return [.defense, .reflexes, .positioning]
        case .footworkTraining: return [.speed, .reflexes, .stamina]
        }
    }

    var description: String {
        switch self {
        case .servePractice: return "Practice your serve placement and power."
        case .rallyDrill: return "Extended rally exchanges to build consistency."
        case .defenseDrill: return "React to incoming shots and return them."
        case .footworkTraining: return "Quick lateral movements across the court."
        }
    }

    /// Maps a stat to the most appropriate drill type for training it.
    static func forStat(_ stat: StatType) -> DrillType {
        switch stat {
        case .power, .accuracy, .spin: return .servePractice
        case .consistency, .positioning: return .rallyDrill
        case .defense, .reflexes: return .defenseDrill
        case .speed, .stamina: return .footworkTraining
        case .clutch: return .rallyDrill
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
