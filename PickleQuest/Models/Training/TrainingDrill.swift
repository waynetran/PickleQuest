import Foundation
import SwiftUI

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
}

enum DrillDifficulty: String, CaseIterable, Codable, Sendable {
    case easy
    case medium
    case hard

    var displayName: String {
        rawValue.capitalized
    }
}

enum DrillGrade: String, CaseIterable, Codable, Comparable, Sendable {
    case S, A, B, C, D

    var color: Color {
        switch self {
        case .S: return .yellow
        case .A: return .green
        case .B: return .blue
        case .C: return .orange
        case .D: return .red
        }
    }

    static func < (lhs: DrillGrade, rhs: DrillGrade) -> Bool {
        let order: [DrillGrade] = [.S, .A, .B, .C, .D]
        guard let l = order.firstIndex(of: lhs), let r = order.firstIndex(of: rhs) else { return false }
        return l < r // S is "best" so S < A means S comes first
    }
}

struct TrainingDrill: Sendable {
    let id: UUID
    let type: DrillType
    let difficulty: DrillDifficulty

    var coinCost: Int {
        GameConstants.Training.drillCoinCost[difficulty] ?? 15
    }

    var energyCost: Double {
        GameConstants.Training.drillEnergyCost
    }

    init(type: DrillType, difficulty: DrillDifficulty) {
        self.id = UUID()
        self.type = type
        self.difficulty = difficulty
    }
}
