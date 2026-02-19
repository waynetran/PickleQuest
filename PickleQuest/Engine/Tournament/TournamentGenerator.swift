import Foundation

/// Static generator that creates a Tournament bracket with seeded matchups.
/// 4-player brackets: 2 rounds (semifinal + final).
/// Seeds by DUPR rating: player seeded relative to field, faces weakest first.
/// For doubles: pairs NPC teams by complementary synergy.
enum TournamentGenerator {

    // MARK: - Public API

    static func generate(
        court: Court,
        matchType: MatchType,
        player: Player,
        availableNPCs: [NPC]
    ) -> Tournament {
        let name = generateName(courtName: court.name)
        let seeds: [TournamentSeed]

        switch matchType {
        case .singles:
            seeds = generateSinglesSeeds(player: player, npcs: availableNPCs)
        case .doubles:
            seeds = generateDoublesSeeds(player: player, npcs: availableNPCs)
        }

        let bracket = buildBracket(seeds: seeds)

        return Tournament(
            name: name,
            courtID: court.id,
            matchType: matchType,
            bracket: bracket
        )
    }

    // MARK: - Name Generation

    private static func generateName(courtName: String) -> String {
        let suffixes = [
            "Open",
            "Classic",
            "Championship",
            "Invitational",
            "Showdown",
            "Cup",
            "Challenge"
        ]
        let suffix = suffixes.randomElement() ?? "Open"
        return "\(courtName) \(suffix)"
    }

    // MARK: - Singles Seeds

    /// Picks 3 NPCs to fill a 4-player bracket alongside the player.
    /// Seeds by DUPR so the player faces the weakest seed first (1 vs 4, 2 vs 3).
    private static func generateSinglesSeeds(
        player: Player,
        npcs: [NPC]
    ) -> [TournamentSeed] {
        let bracketSize = GameConstants.Tournament.bracketSize
        let opponentCount = bracketSize - 1

        // Pick NPCs nearest to the player's DUPR for competitive matches
        let sorted = npcs.sorted { abs($0.duprRating - player.duprRating) < abs($1.duprRating - player.duprRating) }
        let chosen = Array(sorted.prefix(opponentCount))

        // Create a "player NPC" representation for seeding purposes
        let playerNPC = NPC(
            id: player.id,
            name: player.name,
            title: "Player",
            difficulty: .beginner, // not used for seeding
            stats: player.stats,
            playerType: player.playerType,
            dialogue: NPCDialogue(greeting: "", onWin: "", onLose: "", taunt: ""),
            portraitName: "player",
            rewardMultiplier: 1.0,
            duprRating: player.duprRating
        )

        // Combine and sort by DUPR descending for seed assignment
        var allParticipants: [(npc: NPC, isPlayer: Bool)] = [(playerNPC, true)]
        for npc in chosen {
            allParticipants.append((npc, false))
        }
        allParticipants.sort { $0.npc.duprRating > $1.npc.duprRating }

        // Assign seed numbers (1 = highest rated)
        var seeds: [TournamentSeed] = []
        for (index, participant) in allParticipants.enumerated() {
            seeds.append(TournamentSeed(
                id: UUID(),
                seedNumber: index + 1,
                npc1: participant.npc,
                npc2: nil,
                isPlayer: participant.isPlayer
            ))
        }

        return seeds
    }

    // MARK: - Doubles Seeds

    /// Pairs NPCs by complementary synergy for doubles brackets.
    /// The player is paired with the NPC that gives the best synergy, then
    /// remaining NPCs are paired optimally.
    private static func generateDoublesSeeds(
        player: Player,
        npcs: [NPC]
    ) -> [TournamentSeed] {
        let bracketSize = GameConstants.Tournament.bracketSize
        let totalNPCsNeeded = bracketSize * 2 - 1 // player + 7 NPCs for 4 doubles teams

        // Pick closest NPCs by DUPR
        let sorted = npcs.sorted { abs($0.duprRating - player.duprRating) < abs($1.duprRating - player.duprRating) }
        let pool = Array(sorted.prefix(totalNPCsNeeded))

        // Find the best partner for the player (highest synergy)
        var bestPartner: NPC?
        var bestSynergy = -Double.infinity
        for npc in pool {
            let synergy = TeamSynergy.calculate(p1: player.playerType, p2: npc.playerType)
            if synergy.multiplier > bestSynergy {
                bestSynergy = synergy.multiplier
                bestPartner = npc
            }
        }

        guard let partner = bestPartner else {
            // Fallback: not enough NPCs, generate singles-style
            return generateSinglesSeeds(player: player, npcs: npcs)
        }

        // Remaining NPCs for opponent teams
        var remaining = pool.filter { $0.id != partner.id }

        // Pair remaining NPCs by best synergy (greedy)
        var opponentTeams: [(NPC, NPC)] = []
        while remaining.count >= 2 && opponentTeams.count < bracketSize - 1 {
            let anchor = remaining.removeFirst()
            var bestIdx = 0
            var bestTeamSynergy = -Double.infinity
            for (idx, candidate) in remaining.enumerated() {
                let syn = TeamSynergy.calculate(p1: anchor.playerType, p2: candidate.playerType)
                if syn.multiplier > bestTeamSynergy {
                    bestTeamSynergy = syn.multiplier
                    bestIdx = idx
                }
            }
            let paired = remaining.remove(at: bestIdx)
            opponentTeams.append((anchor, paired))
        }

        // Create player team seed placeholder NPC
        let playerNPC = NPC(
            id: player.id,
            name: player.name,
            title: "Player",
            difficulty: .beginner,
            stats: player.stats,
            playerType: player.playerType,
            dialogue: NPCDialogue(greeting: "", onWin: "", onLose: "", taunt: ""),
            portraitName: "player",
            rewardMultiplier: 1.0,
            duprRating: player.duprRating
        )

        // Build seed list: player team + opponent teams, sorted by average DUPR
        var teamEntries: [(npc1: NPC, npc2: NPC?, isPlayer: Bool, avgDUPR: Double)] = []

        let playerAvgDUPR = (player.duprRating + partner.duprRating) / 2.0
        teamEntries.append((playerNPC, partner, true, playerAvgDUPR))

        for (npc1, npc2) in opponentTeams {
            let avg = (npc1.duprRating + npc2.duprRating) / 2.0
            teamEntries.append((npc1, npc2, false, avg))
        }

        // Sort by average DUPR descending for seed assignment
        teamEntries.sort { $0.avgDUPR > $1.avgDUPR }

        var seeds: [TournamentSeed] = []
        for (index, entry) in teamEntries.enumerated() {
            seeds.append(TournamentSeed(
                id: UUID(),
                seedNumber: index + 1,
                npc1: entry.npc1,
                npc2: entry.npc2,
                isPlayer: entry.isPlayer
            ))
        }

        return seeds
    }

    // MARK: - Bracket Construction

    /// Builds a 4-seed bracket: Seed 1 vs Seed 4, Seed 2 vs Seed 3.
    /// Player faces the weakest opponent first since higher seeds play lower seeds.
    private static func buildBracket(seeds: [TournamentSeed]) -> TournamentBracket {
        guard seeds.count == GameConstants.Tournament.bracketSize else {
            // Fallback: pair sequentially
            let semis = stride(from: 0, to: seeds.count, by: 2).map { i in
                TournamentMatch(
                    seed1: seeds[i],
                    seed2: seeds[min(i + 1, seeds.count - 1)]
                )
            }
            let placeholder1 = seeds[0] // will be replaced
            let placeholder2 = seeds[1]
            let final = TournamentMatch(seed1: placeholder1, seed2: placeholder2)
            return TournamentBracket(rounds: [semis, [final]])
        }

        // Standard 4-seed bracket: 1 vs 4, 2 vs 3
        let semi1 = TournamentMatch(seed1: seeds[0], seed2: seeds[3])
        let semi2 = TournamentMatch(seed1: seeds[1], seed2: seeds[2])

        // Final placeholder — seeds filled after semis complete
        let finalMatch = TournamentMatch(seed1: seeds[0], seed2: seeds[1])

        return TournamentBracket(rounds: [[semi1, semi2], [finalMatch]])
    }
}
