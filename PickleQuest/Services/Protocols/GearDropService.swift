import Foundation
import CoreLocation

protocol GearDropService: Sendable {
    /// Spawn field drops around the player if enough time has passed.
    func checkAndSpawnFieldDrops(around coordinate: CLLocationCoordinate2D, state: GearDropState) async -> [GearDrop]

    /// Generate court caches at discovered courts that are off-cooldown.
    func generateCourtCaches(courts: [Court], state: GearDropState) async -> [GearDrop]

    /// Generate a walking trail route around the player, preferring scenic locations.
    func generateTrailRoute(around coordinate: CLLocationCoordinate2D, playerLevel: Int) async -> TrailRoute

    /// Spawn contested drops (rare beacons with NPC guards).
    func spawnContestedDrops(around coordinate: CLLocationCoordinate2D, state: GearDropState) async -> [GearDrop]

    /// Check newly revealed fog cells for hidden stashes.
    func checkFogStashes(newlyRevealed: Set<FogCell>, allRevealed: Set<FogCell>) async -> [GearDrop]

    /// Collect a drop and generate loot. Returns equipment and coin reward.
    func collectDrop(_ drop: GearDrop, playerLevel: Int) async -> (equipment: [Equipment], coins: Int)

    /// Get all currently active (non-expired) drops.
    func getActiveDrops() async -> [GearDrop]

    /// Remove all expired drops.
    func removeExpiredDrops() async

    /// Background-prefetch scenic POIs (parks, trails, gardens) near a coordinate.
    /// Results are cached internally for use in trail route generation.
    func prefetchScenicPoints(around coordinate: CLLocationCoordinate2D) async
}
