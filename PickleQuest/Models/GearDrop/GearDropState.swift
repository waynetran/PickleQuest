import Foundation

struct GearDropState: Codable, Equatable, Sendable {
    var collectedDropIDs: Set<UUID> = []
    var courtCacheCooldowns: [UUID: Date] = [:] // courtID → next available time
    var activeTrail: TrailRoute? = nil
    var contestedDropsClaimed: Int = 0
    var fieldDropsCollectedToday: Int = 0
    var lastDailyReset: Date = Date()
    var lastFieldSpawnTime: Date? = nil

    init(
        collectedDropIDs: Set<UUID> = [],
        courtCacheCooldowns: [UUID: Date] = [:],
        activeTrail: TrailRoute? = nil,
        contestedDropsClaimed: Int = 0,
        fieldDropsCollectedToday: Int = 0,
        lastDailyReset: Date = Date(),
        lastFieldSpawnTime: Date? = nil
    ) {
        self.collectedDropIDs = collectedDropIDs
        self.courtCacheCooldowns = courtCacheCooldowns
        self.activeTrail = activeTrail
        self.contestedDropsClaimed = contestedDropsClaimed
        self.fieldDropsCollectedToday = fieldDropsCollectedToday
        self.lastDailyReset = lastDailyReset
        self.lastFieldSpawnTime = lastFieldSpawnTime
    }

    /// Reset daily counters if a new calendar day has started.
    mutating func resetDailyIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastDailyReset) {
            contestedDropsClaimed = 0
            fieldDropsCollectedToday = 0
            lastDailyReset = Date()
            // Clear expired trail
            if let trail = activeTrail, trail.isExpired {
                activeTrail = nil
            }
        }
    }

    /// Check if a court cache is off cooldown.
    func isCourtCacheAvailable(courtID: UUID) -> Bool {
        guard let cooldownEnd = courtCacheCooldowns[courtID] else { return true }
        return Date() >= cooldownEnd
    }

    // MARK: - Codable (backwards-compatible)

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        collectedDropIDs = try c.decodeIfPresent(Set<UUID>.self, forKey: .collectedDropIDs) ?? []
        courtCacheCooldowns = try c.decodeIfPresent([UUID: Date].self, forKey: .courtCacheCooldowns) ?? [:]
        activeTrail = try c.decodeIfPresent(TrailRoute.self, forKey: .activeTrail)
        contestedDropsClaimed = try c.decodeIfPresent(Int.self, forKey: .contestedDropsClaimed) ?? 0
        fieldDropsCollectedToday = try c.decodeIfPresent(Int.self, forKey: .fieldDropsCollectedToday) ?? 0
        lastDailyReset = try c.decodeIfPresent(Date.self, forKey: .lastDailyReset) ?? Date()
        lastFieldSpawnTime = try c.decodeIfPresent(Date.self, forKey: .lastFieldSpawnTime)
    }
}

struct TrailRoute: Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let brandID: String?
    let waypoints: [GearDrop]
    let expiresAt: Date

    var isExpired: Bool {
        Date() >= expiresAt
    }

    var collectedCount: Int {
        // Waypoints that have been unlocked (collected)
        waypoints.filter { !$0.isUnlocked }.count
    }

    var totalCount: Int {
        waypoints.count
    }

    init(
        id: UUID = UUID(),
        name: String,
        brandID: String? = nil,
        waypoints: [GearDrop],
        expiresAt: Date
    ) {
        self.id = id
        self.name = name
        self.brandID = brandID
        self.waypoints = waypoints
        self.expiresAt = expiresAt
    }
}
