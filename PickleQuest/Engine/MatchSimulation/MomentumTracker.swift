import Foundation

/// Tracks consecutive point streaks and computes momentum modifiers.
struct MomentumTracker: Sendable {
    private(set) var playerStreak: Int = 0
    private(set) var opponentStreak: Int = 0
    private(set) var playerLongestStreak: Int = 0
    private(set) var opponentLongestStreak: Int = 0

    /// Record a point won by the given side. Returns streak count if threshold met.
    mutating func recordPoint(winner: MatchSide) -> Int? {
        switch winner {
        case .player:
            playerStreak += 1
            opponentStreak = 0
            playerLongestStreak = max(playerLongestStreak, playerStreak)
            return playerStreak >= 2 ? playerStreak : nil
        case .opponent:
            opponentStreak += 1
            playerStreak = 0
            opponentLongestStreak = max(opponentLongestStreak, opponentStreak)
            return opponentStreak >= 2 ? opponentStreak : nil
        }
    }

    /// Get the momentum modifier for a given side. Positive = bonus, negative = penalty.
    func modifier(for side: MatchSide) -> Double {
        let streak: Int
        let lossStreak: Int

        switch side {
        case .player:
            streak = playerStreak
            lossStreak = opponentStreak
        case .opponent:
            streak = opponentStreak
            lossStreak = playerStreak
        }

        // Positive momentum from own streak
        let bonus = momentumBonus(streak: streak)
        // Negative momentum from opponent's streak
        let penalty = momentumPenalty(opponentStreak: lossStreak)

        return bonus + penalty
    }

    /// Reset streaks between games.
    mutating func resetForNewGame() {
        playerStreak = 0
        opponentStreak = 0
    }

    // MARK: - Private

    private func momentumBonus(streak: Int) -> Double {
        guard streak >= 2 else { return 0 }
        let capped = min(streak, 6)
        return GameConstants.Momentum.streakThresholds[capped] ?? 0.07
    }

    private func momentumPenalty(opponentStreak: Int) -> Double {
        guard opponentStreak >= 2 else { return 0 }
        let capped = min(opponentStreak, 5)
        return GameConstants.Momentum.negativePenalties[capped] ?? -0.05
    }
}
