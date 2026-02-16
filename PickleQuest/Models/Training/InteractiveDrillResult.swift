import Foundation

struct InteractiveDrillResult: Sendable {
    let drill: TrainingDrill
    let statGained: StatType
    let statGainAmount: Int
    let xpEarned: Int
    let successfulReturns: Int
    let totalBalls: Int
    let longestRally: Int
    let performanceGrade: PerformanceGrade
    let ralliesCompleted: Int
    let coneHits: Int
}

enum PerformanceGrade: String, Sendable {
    case poor = "D"
    case okay = "C"
    case good = "B"
    case great = "A"
    case perfect = "S"

    var displayName: String {
        switch self {
        case .poor: return "Poor"
        case .okay: return "Okay"
        case .good: return "Good"
        case .great: return "Great"
        case .perfect: return "Perfect"
        }
    }

    var colorRed: Double {
        switch self {
        case .poor: return 0.91
        case .okay: return 0.90
        case .good: return 0.20
        case .great: return 0.18
        case .perfect: return 0.95
        }
    }

    var colorGreen: Double {
        switch self {
        case .poor: return 0.30
        case .okay: return 0.49
        case .good: return 0.60
        case .great: return 0.80
        case .perfect: return 0.77
        }
    }

    var colorBlue: Double {
        switch self {
        case .poor: return 0.24
        case .okay: return 0.13
        case .good: return 0.74
        case .great: return 0.44
        case .perfect: return 0.06
        }
    }
}
