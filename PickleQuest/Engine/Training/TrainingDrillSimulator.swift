import Foundation

struct TrainingDrillSimulator: Sendable {
    func simulate(drill: TrainingDrill, effectiveStats: PlayerStats) -> TrainingResult {
        // Calculate average normalized score for target stats
        let targetStats = drill.type.targetStats
        var statScores: [StatType: Double] = [:]
        var totalNormalized = 0.0

        for stat in targetStats {
            let value = Double(effectiveStats.stat(stat))
            let normalized = value / Double(GameConstants.Stats.maxValue)
            statScores[stat] = normalized
            totalNormalized += normalized
        }

        let avgNormalized = totalNormalized / Double(targetStats.count)

        // Add random variance (±5%)
        let variance = GameConstants.Training.gradeVariance
        let randomOffset = Double.random(in: -variance...variance)
        let finalScore = max(0, min(1, avgNormalized + randomOffset))

        // Map to grade via thresholds
        let grade = gradeFromScore(finalScore)

        // Calculate XP: baseXP[difficulty] × gradeMultiplier[grade]
        let baseXP = GameConstants.Training.drillBaseXP[drill.difficulty] ?? 40
        let multiplier = GameConstants.Training.gradeXPMultiplier[grade] ?? 1.0
        let xpEarned = Int(Double(baseXP) * multiplier)

        return TrainingResult(
            drill: drill,
            grade: grade,
            xpEarned: xpEarned,
            targetStatScores: statScores
        )
    }

    private func gradeFromScore(_ score: Double) -> DrillGrade {
        for (threshold, grade) in GameConstants.Training.gradeThresholds {
            if score >= threshold { return grade }
        }
        return .D
    }
}
