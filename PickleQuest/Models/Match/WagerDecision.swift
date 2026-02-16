import Foundation

enum WagerDecision {
    enum Result: Sendable {
        case accepted(amount: Int)
        case rejected(reason: String)
    }

    /// Determine if an NPC accepts a wager challenge.
    /// - Parameters:
    ///   - npc: The NPC being challenged
    ///   - wagerAmount: The proposed wager (0 = free match)
    ///   - playerSUPR: The player's current SUPR rating
    ///   - consecutivePlayerWins: How many times the player has beaten this NPC in a row
    /// - Returns: Whether the NPC accepts and the effective wager amount
    static func evaluate(
        npc: NPC,
        wagerAmount: Int,
        playerSUPR: Double,
        consecutivePlayerWins: Int
    ) -> Result {
        if npc.isHustler {
            return evaluateHustler(npc: npc, playerSUPR: playerSUPR)
        }
        return evaluateRegular(
            npc: npc,
            wagerAmount: wagerAmount,
            playerSUPR: playerSUPR,
            consecutivePlayerWins: consecutivePlayerWins
        )
    }

    // MARK: - Regular NPC

    private static func evaluateRegular(
        npc: NPC,
        wagerAmount: Int,
        playerSUPR: Double,
        consecutivePlayerWins: Int
    ) -> Result {
        // Free matches are always accepted
        if wagerAmount == 0 {
            return .accepted(amount: 0)
        }

        // Refuse if player has beaten them too many times
        if consecutivePlayerWins >= GameConstants.Wager.npcMaxConsecutiveLosses {
            return .rejected(reason: "\(npc.name) shakes their head. \"I've lost enough to you. Find someone else.\"")
        }

        // Refuse if NPC is significantly weaker
        if npc.duprRating < playerSUPR - 0.5 {
            return .rejected(reason: "\(npc.name) backs away. \"You're way out of my league for a money match.\"")
        }

        return .accepted(amount: wagerAmount)
    }

    // MARK: - Hustler NPC

    private static func evaluateHustler(
        npc: NPC,
        playerSUPR: Double
    ) -> Result {
        let suprGap = playerSUPR - npc.duprRating

        // Reject if player's SUPR exceeds hustler's by the threshold
        if suprGap >= GameConstants.Wager.hustlerMinSUPRRejectThreshold {
            return .rejected(reason: "\(npc.name) eyes you suspiciously. \"Nah, I know a ringer when I see one. I'm out.\"")
        }

        // Hustlers always force their own wager amount
        return .accepted(amount: npc.baseWagerAmount)
    }
}
