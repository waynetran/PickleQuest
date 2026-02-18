import Foundation
import SwiftData

actor SwiftDataPersistenceService: PersistenceService {
    private static let schemaVersion = 1
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private func migrateIfNeeded() {
        // Migration scaffold — add versioned migration blocks here as needed.
        // Example for future use:
        // if currentSchemaVersion < 2 { migrateV1toV2() }
        let _ = Self.schemaVersion
    }

    private func makeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    func listSavedPlayers() async throws -> [SavedPlayerSummary] {
        let context = makeContext()
        var descriptor = FetchDescriptor<SavedPlayer>(
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        descriptor.propertiesToFetch = [\.playerID, \.name, \.level, \.duprRating, \.appearanceJSON, \.lastPlayedAt, \.tutorialCompleted]
        let saved = try context.fetch(descriptor)
        return saved.map { SavedPlayerSummary(from: $0) }
    }

    func loadPlayer(id: UUID) async throws -> SavedPlayerBundle {
        migrateIfNeeded()
        let context = makeContext()
        var descriptor = FetchDescriptor<SavedPlayer>(
            predicate: #Predicate { $0.playerID == id }
        )
        descriptor.fetchLimit = 1
        guard let saved = try context.fetch(descriptor).first else {
            throw PersistenceError.playerNotFound
        }

        let decoder = JSONDecoder()
        let player: Player
        let inventory: [Equipment]
        let consumables: [Consumable]
        let fogCells: Set<FogCell>

        do { player = try decoder.decode(Player.self, from: saved.playerData) }
        catch { throw PersistenceError.decodeFailed(model: "Player", detail: "\(error)") }
        do { inventory = try decoder.decode([Equipment].self, from: saved.inventoryData) }
        catch { throw PersistenceError.decodeFailed(model: "Equipment", detail: "\(error)") }
        do { consumables = try decoder.decode([Consumable].self, from: saved.consumablesData) }
        catch { throw PersistenceError.decodeFailed(model: "Consumable", detail: "\(error)") }
        do { fogCells = try decoder.decode(Set<FogCell>.self, from: saved.fogCellsData) }
        catch { throw PersistenceError.decodeFailed(model: "FogCell", detail: "\(error)") }

        return SavedPlayerBundle(
            player: player,
            inventory: inventory,
            consumables: consumables,
            fogCells: fogCells,
            tutorialCompleted: saved.tutorialCompleted
        )
    }

    func savePlayer(_ bundle: SavedPlayerBundle) async throws {
        let context = makeContext()
        let id = bundle.player.id
        var descriptor = FetchDescriptor<SavedPlayer>(
            predicate: #Predicate { $0.playerID == id }
        )
        descriptor.fetchLimit = 1

        let encoder = JSONEncoder()
        let playerData = try encoder.encode(bundle.player)
        let inventoryData = try encoder.encode(bundle.inventory)
        let consumablesData = try encoder.encode(bundle.consumables)
        let fogCellsData = try encoder.encode(bundle.fogCells)
        let appearanceJSON = try encoder.encode(bundle.player.appearance)

        if let existing = try context.fetch(descriptor).first {
            existing.name = bundle.player.name
            existing.level = bundle.player.progression.level
            existing.duprRating = bundle.player.duprRating
            existing.lastPlayedAt = Date()
            existing.appearanceJSON = appearanceJSON
            existing.playerData = playerData
            existing.inventoryData = inventoryData
            existing.consumablesData = consumablesData
            existing.fogCellsData = fogCellsData
            existing.tutorialCompleted = bundle.tutorialCompleted
        } else {
            let saved = SavedPlayer(
                playerID: bundle.player.id,
                name: bundle.player.name,
                level: bundle.player.progression.level,
                duprRating: bundle.player.duprRating,
                createdAt: Date(),
                lastPlayedAt: Date(),
                appearanceJSON: appearanceJSON,
                playerData: playerData,
                inventoryData: inventoryData,
                consumablesData: consumablesData,
                fogCellsData: fogCellsData,
                tutorialCompleted: bundle.tutorialCompleted
            )
            context.insert(saved)
        }

        try context.save()
    }

    func createPlayer(_ bundle: SavedPlayerBundle) async throws {
        let context = makeContext()
        let encoder = JSONEncoder()

        let saved = SavedPlayer(
            playerID: bundle.player.id,
            name: bundle.player.name,
            level: bundle.player.progression.level,
            duprRating: bundle.player.duprRating,
            createdAt: Date(),
            lastPlayedAt: Date(),
            appearanceJSON: try encoder.encode(bundle.player.appearance),
            playerData: try encoder.encode(bundle.player),
            inventoryData: try encoder.encode(bundle.inventory),
            consumablesData: try encoder.encode(bundle.consumables),
            fogCellsData: try encoder.encode(bundle.fogCells),
            tutorialCompleted: bundle.tutorialCompleted
        )
        context.insert(saved)
        try context.save()
    }

    func deletePlayer(id: UUID) async throws {
        let context = makeContext()
        var descriptor = FetchDescriptor<SavedPlayer>(
            predicate: #Predicate { $0.playerID == id }
        )
        descriptor.fetchLimit = 1

        if let saved = try context.fetch(descriptor).first {
            context.delete(saved)
            try context.save()
        }
    }
}

enum PersistenceError: Error, LocalizedError {
    case playerNotFound
    case decodeFailed(model: String, detail: String)

    var errorDescription: String? {
        switch self {
        case .playerNotFound: return "Saved player not found."
        case .decodeFailed(let model, let detail): return "Failed to decode \(model): \(detail)"
        }
    }
}
