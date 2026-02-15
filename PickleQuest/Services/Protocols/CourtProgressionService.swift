import Foundation

enum LadderAdvanceResult: Sendable {
    case nextUnlocked(nextNPC: NPC)        // beat a regular, next one unlocked
    case alphaUnlocked(alphaNPC: NPC)      // beat last regular, alpha spawns
    case alphaDefeated(loot: [Equipment])  // beat the alpha, king of the court
    case alreadyDefeated                   // NPC was already beaten
}

protocol CourtProgressionService: Sendable {
    func getLadder(courtID: UUID, gameType: MatchType) async -> CourtLadder?
    func initializeLadder(courtID: UUID, gameType: MatchType, npcIDs: [UUID]) async
    func recordDefeat(courtID: UUID, gameType: MatchType, npcID: UUID, court: Court, npcService: NPCService) async -> LadderAdvanceResult
    func getCourtPerk(courtID: UUID) async -> CourtPerk?
    func getAllLadders() async -> [CourtLadder]
    func getAlphaNPC(courtID: UUID, gameType: MatchType) async -> NPC?
}
