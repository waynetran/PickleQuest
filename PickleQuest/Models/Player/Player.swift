import Foundation

struct Player: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var stats: PlayerStats
    var progression: PlayerProgression
    var equippedItems: [EquipmentSlot: UUID] // slot → equipment ID
    var wallet: Wallet
    var duprProfile: DUPRProfile

    var duprRating: Double {
        duprProfile.rating
    }

    static func newPlayer(name: String) -> Player {
        Player(
            id: UUID(),
            name: name,
            stats: .starter,
            progression: .starter,
            equippedItems: [:],
            wallet: Wallet(coins: GameConstants.Economy.startingCoins),
            duprProfile: .starter
        )
    }
}
