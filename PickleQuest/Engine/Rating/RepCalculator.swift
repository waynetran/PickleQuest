import Foundation

enum RepCalculator {
    /// Calculate reputation change from a match result.
    /// - Win: baseWinRep + bonus for beating stronger opponents (min 5)
    /// - Loss: -(baseLossRep + penalty for losing to weaker opponents) (max -30)
    static func calculateRepChange(
        didWin: Bool,
        playerSUPR: Double,
        opponentSUPR: Double,
        opponentDifficulty: NPCDifficulty
    ) -> Int {
        let suprGap = opponentSUPR - playerSUPR // positive = opponent stronger

        if didWin {
            let base = GameConstants.Reputation.baseWinRep
            // Beating stronger opponents = more rep
            let gapBonus = suprGap > 0
                ? Int(suprGap * GameConstants.Reputation.suprGapMultiplier)
                : 0
            return max(GameConstants.Reputation.minWinRep, base + gapBonus)
        } else {
            let base = GameConstants.Reputation.baseLossRep
            // Losing to weaker opponents = more rep loss
            let gapPenalty = suprGap < 0
                ? Int(abs(suprGap) * GameConstants.Reputation.suprGapMultiplier)
                : 0
            return -min(GameConstants.Reputation.maxLossRep, base + gapPenalty)
        }
    }
}
