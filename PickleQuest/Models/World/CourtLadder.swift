import Foundation

struct CourtLadder: Codable, Equatable, Sendable {
    let courtID: UUID
    let gameType: MatchType
    var rankedNPCIDs: [UUID]       // ordered weakest → strongest
    var defeatedNPCIDs: Set<UUID>  // NPCs beaten (they "go home")
    var alphaUnlocked: Bool        // true after all regulars beaten
    var alphaNPCID: UUID?          // deterministic ID for alpha boss
    var alphaDefeated: Bool        // "King of the Court" achieved

    /// The next NPC the player must defeat, or nil if all regulars are beaten.
    var nextChallengerID: UUID? {
        rankedNPCIDs.first { !defeatedNPCIDs.contains($0) }
    }

    /// Whether the given NPC is challengeable (is the current next in line, or is the alpha).
    func canChallenge(npcID: UUID) -> Bool {
        if npcID == alphaNPCID && alphaUnlocked {
            return true // alpha is always re-challengeable
        }
        return npcID == nextChallengerID
    }

    /// Position on the ladder (0-based index in rankedNPCIDs), nil if not on ladder.
    func ladderPosition(of npcID: UUID) -> Int? {
        rankedNPCIDs.firstIndex { $0 == npcID }
    }
}

struct CourtPerk: Codable, Equatable, Sendable {
    let courtID: UUID
    var singlesAlphaDefeated: Bool = false
    var doublesAlphaDefeated: Bool = false

    /// Full domination requires both alphas beaten.
    var isFullyDominated: Bool {
        singlesAlphaDefeated && doublesAlphaDefeated
    }
}
