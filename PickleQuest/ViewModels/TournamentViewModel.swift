import Foundation
import SwiftUI

@MainActor
@Observable
final class TournamentViewModel {
    // MARK: - Dependencies

    private let tournamentService: TournamentService
    private let matchService: MatchService
    private let inventoryService: InventoryService
    private let npcService: NPCService

    // MARK: - State Machine

    enum TournamentState: Equatable {
        case idle
        case bracketPreview
        case roundInProgress(round: Int)
        case playerMatch
        case roundResults(round: Int)
        case finished
    }

    var state: TournamentState = .idle

    // MARK: - Tournament Data

    var tournament: Tournament?
    var currentRound: Int = 0
    var npcMatchResults: [UUID: (winner: TournamentSeed, score: String)] = [:]
    var champion: TournamentSeed?
    var playerWon: Bool = false
    var tournamentLoot: [Equipment] = []

    // MARK: - Player Match Integration

    /// The MatchViewModel used for the current player match.
    var matchViewModel: MatchViewModel?

    /// The MatchEngine for the current player match (handed off from TournamentEngine).
    private var currentPlayerEngine: MatchEngine?
    private var currentPlayerMatch: TournamentMatch?

    // MARK: - Engine

    private var tournamentEngine: TournamentEngine?
    private var eventStreamTask: Task<Void, Never>?

    // MARK: - Error / Status

    var errorMessage: String?
    var isSimulatingNPCMatches: Bool = false

    // MARK: - Init

    init(
        tournamentService: TournamentService,
        matchService: MatchService,
        inventoryService: InventoryService,
        npcService: NPCService
    ) {
        self.tournamentService = tournamentService
        self.matchService = matchService
        self.inventoryService = inventoryService
        self.npcService = npcService
    }

    // MARK: - Tournament Generation

    func generateTournament(court: Court, matchType: MatchType, player: Player) async {
        let npcs = await npcService.getAllNPCs()
        let generated = await tournamentService.generateTournament(
            court: court,
            matchType: matchType,
            player: player,
            npcs: npcs
        )
        tournament = generated
        state = .bracketPreview
    }

    // MARK: - Start Tournament

    func startTournament(player: Player) {
        guard let tournament else { return }

        let engine = TournamentEngine(tournament: tournament, player: player)
        self.tournamentEngine = engine

        npcMatchResults = [:]
        currentRound = 0
        champion = nil
        playerWon = false
        tournamentLoot = []
        errorMessage = nil

        eventStreamTask = Task {
            let stream = await engine.simulate(
                matchService: matchService,
                inventoryService: inventoryService
            )

            for await event in stream {
                await handleTournamentEvent(event)
            }
        }
    }

    // MARK: - Event Handling

    private func handleTournamentEvent(_ event: TournamentEvent) async {
        switch event {
        case .bracketReady(let updatedTournament):
            tournament = updatedTournament
            state = .roundInProgress(round: 0)
            isSimulatingNPCMatches = true

        case .npcMatchResult(let match, let winner, let score):
            npcMatchResults[match.id] = (winner, score)
            // Refresh bracket snapshot
            if let engine = tournamentEngine {
                tournament = await engine.currentTournament()
            }

        case .playerMatchReady(let match, let engine):
            isSimulatingNPCMatches = false
            currentPlayerMatch = match
            currentPlayerEngine = engine
            state = .playerMatch

            // Create a MatchViewModel for the player to use
            let vm = MatchViewModel(matchService: matchService, npcService: npcService)
            self.matchViewModel = vm

        case .playerMatchComplete(_, let result):
            // Refresh bracket snapshot
            if let engine = tournamentEngine {
                tournament = await engine.currentTournament()
            }
            _ = result // result already tracked by MatchViewModel

        case .roundComplete(let round):
            currentRound = round
            isSimulatingNPCMatches = false
            // Refresh bracket snapshot
            if let engine = tournamentEngine {
                tournament = await engine.currentTournament()
            }

            if state != .finished {
                state = .roundResults(round: round)
            }

        case .tournamentComplete(let champ, let won, let loot):
            champion = champ
            playerWon = won
            tournamentLoot = loot

            // Refresh final bracket state
            if let engine = tournamentEngine {
                tournament = await engine.currentTournament()
            }

            // Persist
            if let tournament {
                await tournamentService.saveTournamentResult(tournament)
            }

            state = .finished
        }
    }

    // MARK: - Player Match Flow

    /// Called by the view when the player starts their tournament match.
    /// Runs the MatchEngine through the MatchViewModel and reports the result back.
    func runPlayerMatch(player: Player) async {
        guard let engine = currentPlayerEngine,
              let match = currentPlayerMatch,
              let matchVM = matchViewModel else { return }

        let opponent = match.seed1.isPlayer ? match.seed2 : match.seed1

        // Drive the match through the MatchViewModel's event loop
        matchVM.matchState = .simulating
        matchVM.selectedNPC = opponent.npc1
        matchVM.eventLog = []
        matchVM.matchResult = nil
        matchVM.currentScore = nil
        matchVM.isSkipping = false
        matchVM.playerAppearance = player.appearance

        let stream = await engine.simulate()
        for await event in stream {
            let entry = MatchEventEntry(event: event)
            matchVM.eventLog.append(entry)

            if case .pointPlayed(let point) = event {
                matchVM.currentScore = point.scoreAfter
            }
            if case .matchEnd(let result) = event {
                matchVM.matchResult = result
                matchVM.lootDrops = result.loot
            }

            // Small delay for visual feedback unless skipping
            if !matchVM.isSkipping {
                try? await Task.sleep(for: .milliseconds(150))
            }

            if case .matchEnd = event {
                matchVM.matchState = .finished
            }
        }

        // Report result back to tournament engine
        if let result = matchVM.matchResult, let tournamentEngine {
            await tournamentEngine.reportPlayerMatchResult(result)
        }

        // Transition back to round in progress (engine will send roundComplete next)
        currentPlayerEngine = nil
        currentPlayerMatch = nil
        isSimulatingNPCMatches = true
        state = .roundInProgress(round: currentRound + 1)
    }

    // MARK: - Advance Round

    /// Called by the view to proceed from round results to the next round.
    func advanceToNextRound() {
        let nextRound = currentRound + 1
        if nextRound < (tournament?.bracket.rounds.count ?? 0) {
            state = .roundInProgress(round: nextRound)
            isSimulatingNPCMatches = true
        }
    }

    // MARK: - Reset

    func reset() {
        eventStreamTask?.cancel()
        eventStreamTask = nil
        tournamentEngine = nil
        tournament = nil
        state = .idle
        currentRound = 0
        npcMatchResults = [:]
        champion = nil
        playerWon = false
        tournamentLoot = []
        matchViewModel = nil
        currentPlayerEngine = nil
        currentPlayerMatch = nil
        errorMessage = nil
        isSimulatingNPCMatches = false
    }

    // MARK: - Display Helpers

    var roundName: String {
        guard let tournament else { return "" }
        let totalRounds = tournament.bracket.rounds.count
        switch currentRound {
        case totalRounds - 1:
            return "Final"
        case totalRounds - 2:
            return "Semifinal"
        default:
            return "Round \(currentRound + 1)"
        }
    }

    var statusText: String {
        switch state {
        case .idle:
            return "Select a tournament"
        case .bracketPreview:
            return "Review the bracket"
        case .roundInProgress(let round):
            let name = roundDisplayName(round)
            return isSimulatingNPCMatches ? "Simulating \(name) matches..." : "\(name) in progress"
        case .playerMatch:
            return "Your match!"
        case .roundResults(let round):
            return "\(roundDisplayName(round)) complete"
        case .finished:
            return playerWon ? "Tournament Champion!" : "Tournament Over"
        }
    }

    private func roundDisplayName(_ round: Int) -> String {
        guard let tournament else { return "Round \(round + 1)" }
        let totalRounds = tournament.bracket.rounds.count
        switch round {
        case totalRounds - 1:
            return "Final"
        case totalRounds - 2:
            return "Semifinal"
        default:
            return "Round \(round + 1)"
        }
    }
}
