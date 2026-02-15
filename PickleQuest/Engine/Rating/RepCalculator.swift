import Foundation

enum RepCalculator {
    /// Calculate reputation change from a match result.
    ///
    /// **Win:**
    /// - Upset (opponent stronger): baseWinRep + suprGap * upsetWinBonus
    /// - Expected (opponent weaker): baseWinRep - abs(suprGap) * expectedWinReduction (min 3)
    ///
    /// **Loss:**
    /// - To much stronger (gap >= 0.5): small respect gain (+1 to +3)
    /// - To slightly stronger or equal (0 <= gap < 0.5): 0
    /// - To weaker (gap < 0): rep loss capped at -30
    static func calculateRepChange(
        didWin: Bool,
        playerSUPR: Double,
        opponentSUPR: Double
    ) -> Int {
        let suprGap = opponentSUPR - playerSUPR // positive = opponent stronger

        if didWin {
            let base = GameConstants.Reputation.baseWinRep
            if suprGap > 0 {
                // Upset win: big rep for beating someone above you
                return base + Int(suprGap * GameConstants.Reputation.upsetWinBonus)
            } else {
                // Expected win: diminished but not zero
                let reduction = Int(abs(suprGap) * GameConstants.Reputation.expectedWinReduction)
                return max(GameConstants.Reputation.minWinRep, base - reduction)
            }
        } else {
            if suprGap >= GameConstants.Reputation.respectThreshold {
                // Lost to much stronger: small respect gain
                let respect = Int(suprGap * GameConstants.Reputation.respectGainRate)
                return min(GameConstants.Reputation.maxRespectGain, max(1, respect))
            } else if suprGap >= 0 {
                // Lost to slightly stronger or equal: no change
                return 0
            } else {
                // Lost to weaker: rep loss
                let penalty = GameConstants.Reputation.baseLossRep + Int(abs(suprGap) * GameConstants.Reputation.upsetLossMultiplier)
                return -min(GameConstants.Reputation.maxLossRep, penalty)
            }
        }
    }
}
