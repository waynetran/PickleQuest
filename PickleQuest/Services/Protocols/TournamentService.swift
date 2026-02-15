import Foundation

protocol TournamentService: Sendable {
    /// Retrieve available (not-yet-started) tournaments for a specific court.
    func getAvailableTournaments(courtID: UUID) async -> [Tournament]

    /// Generate a new tournament bracket for the given court and match type.
    func generateTournament(
        court: Court,
        matchType: MatchType,
        player: Player,
        npcs: [NPC]
    ) async -> Tournament

    /// Persist a completed tournament result.
    func saveTournamentResult(_ tournament: Tournament) async

    /// Retrieve all completed tournaments.
    func getCompletedTournaments() async -> [Tournament]
}
