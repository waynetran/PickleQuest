import Foundation

struct SavedPlayerSummary: Identifiable, Sendable {
    let id: UUID
    let name: String
    let level: Int
    let duprRating: Double
    let appearance: CharacterAppearance
    let lastPlayedAt: Date
    let tutorialCompleted: Bool

    init(from saved: SavedPlayer) {
        self.id = saved.playerID
        self.name = saved.name
        self.level = saved.level
        self.duprRating = saved.duprRating
        self.appearance = (try? JSONDecoder().decode(CharacterAppearance.self, from: saved.appearanceJSON)) ?? .defaultPlayer
        self.lastPlayedAt = saved.lastPlayedAt
        self.tutorialCompleted = saved.tutorialCompleted
    }
}
