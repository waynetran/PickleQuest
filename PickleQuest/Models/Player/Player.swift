import Foundation

struct Player: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var stats: PlayerStats
    var progression: PlayerProgression
    var equippedItems: [EquipmentSlot: UUID] // slot → equipment ID
    var wallet: Wallet
    var duprProfile: DUPRProfile
    var matchHistory: [MatchHistoryEntry] = []
    var appearance: CharacterAppearance = .defaultPlayer
    var repProfile: RepProfile = .starter
    var energy: Double = GameConstants.PersistentEnergy.maxEnergy
    var lastMatchDate: Date? = nil
    var discoveredCourtIDs: Set<UUID> = []

    var duprRating: Double {
        duprProfile.rating
    }

    /// Current energy accounting for real-time recovery since last match
    var currentEnergy: Double {
        guard let lastMatch = lastMatchDate else { return energy }
        let minutesElapsed = Date().timeIntervalSince(lastMatch) / 60.0
        let recovered = minutesElapsed * GameConstants.PersistentEnergy.recoveryPerMinute
        return min(GameConstants.PersistentEnergy.maxEnergy, energy + recovered)
    }

    /// Sum of SUPR changes in the current calendar month
    var monthlyDUPRDelta: Double {
        let calendar = Calendar.current
        let now = Date()
        return matchHistory
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .compactMap(\.duprChange)
            .reduce(0, +)
    }

    var hasPaddleEquipped: Bool {
        equippedItems[.paddle] != nil
    }

    static func newPlayer(name: String) -> Player {
        Player(
            id: UUID(),
            name: name,
            stats: .starter,
            progression: .starter,
            equippedItems: [
                .paddle: UUID(uuidString: "10000001-0000-0000-0000-000000000001")!,
                .shoes: UUID(uuidString: "10000002-0000-0000-0000-000000000002")!,
                .shirt: UUID(uuidString: "10000003-0000-0000-0000-000000000003")!
            ],
            wallet: Wallet(coins: GameConstants.Economy.startingCoins),
            duprProfile: .starter
        )
    }
}
