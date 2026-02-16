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
    ///   - npcPurse: How many coins the NPC currently carries
    /// - Returns: Whether the NPC accepts and the effective wager amount
    static func evaluate(
        npc: NPC,
        wagerAmount: Int,
        playerSUPR: Double,
        consecutivePlayerWins: Int,
        npcPurse: Int = Int.max
    ) -> Result {
        if npc.isHustler {
            return evaluateHustler(npc: npc, playerSUPR: playerSUPR, npcPurse: npcPurse)
        }
        return evaluateRegular(
            npc: npc,
            wagerAmount: wagerAmount,
            playerSUPR: playerSUPR,
            consecutivePlayerWins: consecutivePlayerWins,
            npcPurse: npcPurse
        )
    }

    // MARK: - Regular NPC

    private static func evaluateRegular(
        npc: NPC,
        wagerAmount: Int,
        playerSUPR: Double,
        consecutivePlayerWins: Int,
        npcPurse: Int
    ) -> Result {
        // Free matches are always accepted
        if wagerAmount == 0 {
            return .accepted(amount: 0)
        }

        // Refuse if NPC can't afford the wager
        if wagerAmount > npcPurse {
            return .rejected(reason: "\(npc.name) pats their pockets. \"I don't have that much on me.\"")
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
        playerSUPR: Double,
        npcPurse: Int
    ) -> Result {
        let suprGap = playerSUPR - npc.duprRating

        // Reject if player's SUPR exceeds hustler's by the threshold
        if suprGap >= GameConstants.Wager.hustlerMinSUPRRejectThreshold {
            return .rejected(reason: "\(npc.name) eyes you suspiciously. \"Nah, I know a ringer when I see one. I'm out.\"")
        }

        // Reject if hustler is tapped out
        if npcPurse == 0 {
            return .rejected(reason: "\(npc.name) shrugs. \"I'm tapped out. Come back later.\"")
        }

        // Cap effective wager at what the hustler can afford
        let effectiveWager = min(npc.baseWagerAmount, npcPurse)
        return .accepted(amount: effectiveWager)
    }
}
