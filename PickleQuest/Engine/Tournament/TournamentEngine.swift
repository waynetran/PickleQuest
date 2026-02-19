import Foundation

/// Events emitted during tournament progression.
enum TournamentEvent: Sendable {
    /// Bracket is ready and can be displayed.
    case bracketReady(Tournament)

    /// An NPC-vs-NPC match was auto-simulated.
    case npcMatchResult(match: TournamentMatch, winner: TournamentSeed, score: String)

    /// A player match is ready — ViewModel should drive the MatchEngine.
    case playerMatchReady(match: TournamentMatch, engine: MatchEngine)

    /// Player match completed with a result.
    case playerMatchComplete(match: TournamentMatch, result: MatchResult)

    /// All matches in the current round are done.
    case roundComplete(round: Int)

    /// Tournament is over — champion determined, loot generated.
    case tournamentComplete(champion: TournamentSeed, playerWon: Bool, loot: [Equipment])
}

/// Actor that orchestrates a full tournament bracket, simulating NPC matches
/// and handing off player matches to the ViewModel.
actor TournamentEngine {
    private var tournament: Tournament
    private let matchType: MatchType
    private let player: Player
    private let lootGenerator: LootGenerator

    init(tournament: Tournament, player: Player) {
        self.tournament = tournament
        self.matchType = tournament.matchType
        self.player = player
        self.lootGenerator = LootGenerator()
    }

    // MARK: - Public API

    /// Run the tournament, emitting events for each phase.
    /// The caller (ViewModel) must await playerMatchReady events and feed back
    /// the result via `reportPlayerMatchResult`.
    func simulate(
        matchService: MatchService,
        inventoryService: InventoryService
    ) -> AsyncStream<TournamentEvent> {
        AsyncStream { continuation in
            Task {
                await runTournament(
                    matchService: matchService,
                    inventoryService: inventoryService,
                    continuation: continuation
                )
                continuation.finish()
            }
        }
    }

    // MARK: - Player Match Result Callback

    /// The pending player match result, set by the ViewModel after match completes.
    private var pendingPlayerResult: MatchResult?
    private var playerResultContinuation: CheckedContinuation<MatchResult, Never>?

    /// Called by the ViewModel when a player match finishes.
    func reportPlayerMatchResult(_ result: MatchResult) {
        if let cont = playerResultContinuation {
            playerResultContinuation = nil
            cont.resume(returning: result)
        } else {
            pendingPlayerResult = result
        }
    }

    /// Wait for the player match result from the ViewModel.
    private func awaitPlayerResult() async -> MatchResult {
        if let pending = pendingPlayerResult {
            pendingPlayerResult = nil
            return pending
        }
        return await withCheckedContinuation { cont in
            playerResultContinuation = cont
        }
    }

    // MARK: - Tournament Loop

    private func runTournament(
        matchService: MatchService,
        inventoryService: InventoryService,
        continuation: AsyncStream<TournamentEvent>.Continuation
    ) async {
        tournament.status = .inProgress
        continuation.yield(.bracketReady(tournament))

        let totalRounds = tournament.bracket.rounds.count

        for roundIndex in 0..<totalRounds {
            let matches = tournament.bracket.rounds[roundIndex]

            for (matchIndex, match) in matches.enumerated() {
                if match.isPlayerMatch {
                    // Create the engine and hand it off to the ViewModel
                    let engine = await createMatchEngine(
                        for: match,
                        matchService: matchService,
                        inventoryService: inventoryService
                    )
                    continuation.yield(.playerMatchReady(match: match, engine: engine))

                    // Wait for the ViewModel to report the result
                    let result = await awaitPlayerResult()
                    let winner = result.didPlayerWin ? playerSeed(in: match) : opponentSeed(in: match)
                    let scoreString = result.formattedScore

                    // Update bracket
                    tournament.bracket.rounds[roundIndex][matchIndex].winner = winner
                    tournament.bracket.rounds[roundIndex][matchIndex].scoreString = scoreString

                    continuation.yield(.playerMatchComplete(match: match, result: result))
                } else {
                    // Auto-simulate NPC-vs-NPC match
                    let (winner, scoreString) = await simulateNPCMatch(
                        match: match,
                        matchService: matchService,
                        inventoryService: inventoryService
                    )

                    tournament.bracket.rounds[roundIndex][matchIndex].winner = winner
                    tournament.bracket.rounds[roundIndex][matchIndex].scoreString = scoreString

                    continuation.yield(.npcMatchResult(match: match, winner: winner, score: scoreString))
                }
            }

            // Advance winners to next round
            if roundIndex < totalRounds - 1 {
                advanceWinnersToNextRound(fromRound: roundIndex)
            }

            continuation.yield(.roundComplete(round: roundIndex))
        }

        // Tournament complete
        tournament.status = .completed
        let champion = tournament.bracket.champion

        let playerWon = champion?.isPlayer ?? false
        let loot = generateTournamentLoot(playerWon: playerWon)

        continuation.yield(.tournamentComplete(
            champion: champion ?? tournament.bracket.rounds[0][0].seed1,
            playerWon: playerWon,
            loot: loot
        ))
    }

    // MARK: - Match Simulation

    private func simulateNPCMatch(
        match: TournamentMatch,
        matchService: MatchService,
        inventoryService: InventoryService
    ) async -> (winner: TournamentSeed, scoreString: String) {
        let config: MatchConfig = matchType == .doubles ? .defaultDoubles : .defaultSingles

        let engine: MatchEngine
        if matchType == .doubles, let npc1Partner = match.seed1.npc2, let npc2Partner = match.seed2.npc2 {
            // Doubles NPC match: seed1 team vs seed2 team
            // Use npc1 as "player" side, npc2 team as opponents
            let teamSynergy = TeamSynergy.calculate(p1: match.seed1.npc1.playerType, p2: npc1Partner.playerType)
            let opponentSynergy = TeamSynergy.calculate(p1: match.seed2.npc1.playerType, p2: npc2Partner.playerType)

            engine = MatchEngine(
                playerStats: match.seed1.npc1.stats,
                opponentStats: match.seed2.npc1.stats,
                playerName: match.seed1.displayName,
                opponentName: match.seed2.displayName,
                config: config,
                opponentDifficulty: match.seed2.npc1.difficulty,
                partnerStats: npc1Partner.stats,
                partnerName: npc1Partner.name,
                opponent2Stats: npc2Partner.stats,
                opponent2Name: npc2Partner.name,
                teamSynergy: teamSynergy,
                opponentSynergy: opponentSynergy
            )
        } else {
            // Singles NPC match
            engine = MatchEngine(
                playerStats: match.seed1.npc1.stats,
                opponentStats: match.seed2.npc1.stats,
                playerName: match.seed1.displayName,
                opponentName: match.seed2.displayName,
                config: config,
                opponentDifficulty: match.seed2.npc1.difficulty
            )
        }

        let result = await engine.simulateToResult()

        let winner = result.didPlayerWin ? match.seed1 : match.seed2
        return (winner, result.formattedScore)
    }

    private func createMatchEngine(
        for match: TournamentMatch,
        matchService: MatchService,
        inventoryService: InventoryService
    ) async -> MatchEngine {
        let config: MatchConfig = matchType == .doubles ? .defaultDoubles : .defaultSingles
        let opponent = match.seed1.isPlayer ? match.seed2 : match.seed1

        if matchType == .doubles {
            // Find the player's partner
            let playerSeed = match.seed1.isPlayer ? match.seed1 : match.seed2
            if let partner = playerSeed.npc2,
               let opp2 = opponent.npc2 {
                return await matchService.createDoublesMatch(
                    player: player,
                    partner: partner,
                    opponent1: opponent.npc1,
                    opponent2: opp2,
                    config: config,
                    playerConsumables: player.consumables,
                    playerReputation: player.repProfile.reputation
                )
            }
        }

        // Singles or fallback
        return await matchService.createMatch(
            player: player,
            opponent: opponent.npc1,
            config: config,
            playerConsumables: player.consumables,
            playerReputation: player.repProfile.reputation
        )
    }

    // MARK: - Bracket Advancement

    private func advanceWinnersToNextRound(fromRound roundIndex: Int) {
        let winners = tournament.bracket.rounds[roundIndex].compactMap(\.winner)
        let nextRound = roundIndex + 1

        guard nextRound < tournament.bracket.rounds.count else { return }

        for (matchIndex, _) in tournament.bracket.rounds[nextRound].enumerated() {
            let seed1Index = matchIndex * 2
            let seed2Index = seed1Index + 1

            if seed1Index < winners.count {
                tournament.bracket.rounds[nextRound][matchIndex] = TournamentMatch(
                    id: tournament.bracket.rounds[nextRound][matchIndex].id,
                    seed1: winners[seed1Index],
                    seed2: seed2Index < winners.count ? winners[seed2Index] : winners[seed1Index]
                )
            }
        }
    }

    // MARK: - Loot Generation

    private func generateTournamentLoot(playerWon: Bool) -> [Equipment] {
        var loot: [Equipment] = []

        if playerWon {
            // Winner gets legendary + epic loot
            for _ in 0..<GameConstants.Tournament.winnerLegendaryCount {
                loot.append(lootGenerator.generateEquipment(rarity: .legendary))
            }
            for _ in 0..<GameConstants.Tournament.winnerEpicCount {
                loot.append(lootGenerator.generateEquipment(rarity: .epic))
            }
        } else {
            // Participation loot
            for _ in 0..<GameConstants.Tournament.participationLootCount {
                loot.append(lootGenerator.generateEquipment())
            }
        }

        return loot
    }

    // MARK: - Helpers

    /// Returns the player's seed from a match (whichever side isPlayer).
    private func playerSeed(in match: TournamentMatch) -> TournamentSeed {
        match.seed1.isPlayer ? match.seed1 : match.seed2
    }

    /// Returns the opponent's seed from a match.
    private func opponentSeed(in match: TournamentMatch) -> TournamentSeed {
        match.seed1.isPlayer ? match.seed2 : match.seed1
    }

    /// Current tournament state snapshot.
    func currentTournament() -> Tournament {
        tournament
    }
}
