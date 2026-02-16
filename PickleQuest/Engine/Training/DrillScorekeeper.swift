import Foundation

enum ScoringMode: Sendable {
    case rallyStreak    // baseline rally, dinking drill
    case serveAccuracy  // serve practice
    case returnTarget   // return of serve
}

@MainActor
final class DrillScorekeeper {
    var successfulReturns: Int = 0
    var totalBalls: Int = 0
    var longestRally: Int = 0
    var currentRallyLength: Int = 0
    var ralliesCompleted: Int = 0
    var currentConsecutiveReturns: Int = 0
    var coneHits: Int = 0
    var totalRoundsAttempted: Int = 0

    let totalRounds: Int
    let rallyShotsRequired: Int
    let scoringMode: ScoringMode

    private let drill: TrainingDrill
    private let statGained: StatType
    private let coachLevel: Int
    private let playerEnergy: Double
    private let coachEnergy: Double

    init(drill: TrainingDrill, statGained: StatType,
         coachLevel: Int, playerEnergy: Double, coachEnergy: Double) {
        self.drill = drill
        self.statGained = statGained
        self.coachLevel = coachLevel
        self.playerEnergy = playerEnergy
        self.coachEnergy = coachEnergy

        let config = DrillConfig.config(for: drill.type)
        self.totalRounds = config.totalRounds
        self.rallyShotsRequired = config.rallyShotsRequired

        switch drill.type {
        case .baselineRally, .dinkingDrill:
            self.scoringMode = .rallyStreak
        case .servePractice:
            self.scoringMode = .serveAccuracy
        case .returnOfServe:
            self.scoringMode = .returnTarget
        }
    }

    func onSuccessfulReturn() {
        successfulReturns += 1
        currentRallyLength += 1
        longestRally = max(longestRally, currentRallyLength)

        if scoringMode == .rallyStreak {
            currentConsecutiveReturns += 1
        }
    }

    /// Called when the player completes 5 consecutive returns in rally mode.
    func onRallyCompleted() {
        ralliesCompleted += 1
        currentConsecutiveReturns = 0
    }

    func onBallFed() {
        totalBalls += 1
    }

    func onRoundAttempted() {
        totalRoundsAttempted += 1
    }

    func onRallyEnd() {
        currentRallyLength = 0
        if scoringMode == .rallyStreak {
            currentConsecutiveReturns = 0
        }
    }

    func onConeHit() {
        coneHits += 1
    }

    var isAllRoundsComplete: Bool {
        totalRoundsAttempted >= totalRounds
    }

    var successRate: Double {
        switch scoringMode {
        case .rallyStreak:
            guard totalRounds > 0 else { return 0 }
            return Double(ralliesCompleted) / Double(totalRounds)
        case .serveAccuracy:
            guard totalRoundsAttempted > 0 else { return 0 }
            return Double(successfulReturns) / Double(totalRoundsAttempted)
        case .returnTarget:
            guard totalRoundsAttempted > 0 else { return 0 }
            let returnRate = Double(successfulReturns) / Double(totalRoundsAttempted)
            let coneRate = totalRoundsAttempted > 0 ? Double(coneHits) / Double(totalRoundsAttempted) : 0
            return returnRate * 0.7 + coneRate * 0.3
        }
    }

    var performanceGrade: PerformanceGrade {
        let rate = successRate
        if rate >= 0.90 { return .perfect }
        if rate >= 0.80 { return .great }
        if rate >= 0.60 { return .good }
        if rate >= 0.30 { return .okay }
        return .poor
    }

    /// Performance multiplier applied to base stat gain.
    var performanceMultiplier: Double {
        switch performanceGrade {
        case .poor:    return 0.5
        case .okay:    return 0.75
        case .good:    return 1.0
        case .great:   return 1.15
        case .perfect: return 1.3
        }
    }

    func calculateResult() -> InteractiveDrillResult {
        // Base stat gain from coach level + energy (same formula as TrainingDrillSimulator)
        let coachLevelGains: [Int: Int] = [1: 2, 2: 3, 3: 4, 4: 6, 5: 8]
        let baseGain = coachLevelGains[coachLevel] ?? coachLevel
        let energyScaledGain = max(1, Int(round(Double(baseGain) * (playerEnergy / 100.0) * (coachEnergy / 100.0))))

        // Apply performance multiplier
        let finalGain = max(1, Int(round(Double(energyScaledGain) * performanceMultiplier)))

        // XP: base training XP scaled by performance
        let baseXP = GameConstants.Training.baseTrainingXP
        let xpEarned = max(10, Int(round(Double(baseXP) * performanceMultiplier)))

        return InteractiveDrillResult(
            drill: drill,
            statGained: statGained,
            statGainAmount: finalGain,
            xpEarned: xpEarned,
            successfulReturns: successfulReturns,
            totalBalls: totalBalls,
            longestRally: longestRally,
            performanceGrade: performanceGrade,
            ralliesCompleted: ralliesCompleted,
            coneHits: coneHits
        )
    }
}
