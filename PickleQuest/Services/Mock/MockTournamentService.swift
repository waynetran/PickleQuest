import Foundation

/// Actor-based mock implementation of TournamentService.
/// Stores tournaments in memory for local-only gameplay.
actor MockTournamentService: TournamentService {
    private var tournaments: [UUID: Tournament] = [:]

    // MARK: - TournamentService

    func getAvailableTournaments(courtID: UUID) async -> [Tournament] {
        tournaments.values
            .filter { $0.courtID == courtID && $0.status == .notStarted }
            .sorted { $0.name < $1.name }
    }

    func generateTournament(
        court: Court,
        matchType: MatchType,
        player: Player,
        npcs: [NPC]
    ) async -> Tournament {
        let tournament = TournamentGenerator.generate(
            court: court,
            matchType: matchType,
            player: player,
            availableNPCs: npcs
        )
        tournaments[tournament.id] = tournament
        return tournament
    }

    func saveTournamentResult(_ tournament: Tournament) async {
        tournaments[tournament.id] = tournament
    }

    func getCompletedTournaments() async -> [Tournament] {
        tournaments.values
            .filter { $0.status == .completed }
            .sorted { $0.name < $1.name }
    }
}
