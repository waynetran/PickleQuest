import Foundation
import SwiftData

@Model
final class SavedPlayer {
    #Unique<SavedPlayer>([\.playerID])
    #Index<SavedPlayer>([\.lastPlayedAt])

    var playerID: UUID
    var name: String
    var level: Int
    var duprRating: Double
    var createdAt: Date
    var lastPlayedAt: Date
    var appearanceJSON: Data
    var playerData: Data
    var inventoryData: Data
    var consumablesData: Data
    var fogCellsData: Data
    var tutorialCompleted: Bool
    var schemaVersion: Int

    init(
        playerID: UUID,
        name: String,
        level: Int,
        duprRating: Double,
        createdAt: Date,
        lastPlayedAt: Date,
        appearanceJSON: Data,
        playerData: Data,
        inventoryData: Data,
        consumablesData: Data,
        fogCellsData: Data,
        tutorialCompleted: Bool,
        schemaVersion: Int = 1
    ) {
        self.playerID = playerID
        self.name = name
        self.level = level
        self.duprRating = duprRating
        self.createdAt = createdAt
        self.lastPlayedAt = lastPlayedAt
        self.appearanceJSON = appearanceJSON
        self.playerData = playerData
        self.inventoryData = inventoryData
        self.consumablesData = consumablesData
        self.fogCellsData = fogCellsData
        self.tutorialCompleted = tutorialCompleted
        self.schemaVersion = schemaVersion
    }
}
