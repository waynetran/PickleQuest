import Foundation

actor MockCourtProgressionService: CourtProgressionService {
    private var ladders: [String: CourtLadder] = [:]
    private var perks: [UUID: CourtPerk] = [:]
    private var alphaNPCs: [String: NPC] = [:]

    private func key(courtID: UUID, gameType: GameType) -> String {
        "\(courtID.uuidString)-\(gameType.rawValue)"
    }

    func getLadder(courtID: UUID, gameType: GameType) async -> CourtLadder? {
        ladders[key(courtID: courtID, gameType: gameType)]
    }

    func initializeLadder(courtID: UUID, gameType: GameType, npcIDs: [UUID]) async {
        let k = key(courtID: courtID, gameType: gameType)
        guard ladders[k] == nil else { return }
        ladders[k] = CourtLadder(
            courtID: courtID,
            gameType: gameType,
            rankedNPCIDs: npcIDs,
            defeatedNPCIDs: [],
            alphaUnlocked: false,
            alphaNPCID: nil,
            alphaDefeated: false
        )
    }

    func recordDefeat(
        courtID: UUID,
        gameType: GameType,
        npcID: UUID,
        court: Court,
        npcService: NPCService
    ) async -> LadderAdvanceResult {
        let k = key(courtID: courtID, gameType: gameType)
        guard var ladder = ladders[k] else { return .alreadyDefeated }

        // Check if this is the alpha
        if npcID == ladder.alphaNPCID {
            if !ladder.alphaDefeated {
                ladder.alphaDefeated = true
                ladders[k] = ladder

                // Update court perks
                var perk = perks[courtID] ?? CourtPerk(courtID: courtID)
                if gameType == .singles {
                    perk.singlesAlphaDefeated = true
                } else {
                    perk.doublesAlphaDefeated = true
                }
                perks[courtID] = perk
            }

            // Always drop alpha loot (farmable)
            let loot = AlphaLootGenerator.generateAlphaLoot()
            return .alphaDefeated(loot: loot)
        }

        // Check if already defeated
        guard !ladder.defeatedNPCIDs.contains(npcID) else {
            return .alreadyDefeated
        }

        // Record the defeat
        ladder.defeatedNPCIDs.insert(npcID)

        // Check if all regulars are now beaten
        let allDefeated = ladder.rankedNPCIDs.allSatisfy { ladder.defeatedNPCIDs.contains($0) }

        if allDefeated && !ladder.alphaUnlocked {
            // Unlock alpha
            ladder.alphaUnlocked = true

            // Generate the alpha NPC
            let strongestNPC = await findStrongestNPC(npcIDs: ladder.rankedNPCIDs, npcService: npcService)
            if let strongest = strongestNPC {
                let alpha = AlphaNPCGenerator.generateAlpha(for: court, strongestNPC: strongest)
                ladder.alphaNPCID = alpha.id
                alphaNPCs[k] = alpha
                ladders[k] = ladder
                return .alphaUnlocked(alphaNPC: alpha)
            }
        }

        ladders[k] = ladder

        // Find the next unlocked NPC
        if let nextID = ladder.nextChallengerID,
           let nextNPC = await npcService.getNPC(by: nextID) {
            return .nextUnlocked(nextNPC: nextNPC)
        }

        return .alreadyDefeated
    }

    func getCourtPerk(courtID: UUID) async -> CourtPerk? {
        perks[courtID]
    }

    func getAllLadders() async -> [CourtLadder] {
        Array(ladders.values)
    }

    func getAlphaNPC(courtID: UUID, gameType: GameType) async -> NPC? {
        alphaNPCs[key(courtID: courtID, gameType: gameType)]
    }

    // MARK: - Private

    private func findStrongestNPC(npcIDs: [UUID], npcService: NPCService) async -> NPC? {
        var strongest: NPC?
        for id in npcIDs {
            if let npc = await npcService.getNPC(by: id) {
                if strongest == nil || npc.duprRating > strongest!.duprRating {
                    strongest = npc
                }
            }
        }
        return strongest
    }
}
