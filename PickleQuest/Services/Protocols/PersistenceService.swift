import Foundation

protocol PersistenceService: Sendable {
    func listSavedPlayers() async throws -> [SavedPlayerSummary]
    func loadPlayer(id: UUID) async throws -> SavedPlayerBundle
    func savePlayer(_ bundle: SavedPlayerBundle) async throws
    func createPlayer(_ bundle: SavedPlayerBundle) async throws
    func deletePlayer(id: UUID) async throws
}
