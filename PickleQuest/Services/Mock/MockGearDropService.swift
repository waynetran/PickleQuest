import Foundation
import CoreLocation
import MapKit

/// A cached scenic point of interest (park, trail, garden, etc.)
struct ScenicPOI: Sendable {
    let name: String
    let coordinate: CLLocationCoordinate2D
    let category: ScenicCategory

    enum ScenicCategory: Sendable, Equatable {
        case hikingTrail, park, garden, natureReserve, beach, waterfront
    }
}

actor MockGearDropService: GearDropService {
    private var activeDrops: [GearDrop] = []
    private let spawnEngine = GearDropSpawnEngine()
    private let lootGenerator = LootGenerator()

    // MARK: - Scenic POI Cache
    // Grid key = (latBucket, lngBucket) at ~500m resolution.
    // Each bucket stores discovered POIs + a timestamp to avoid re-fetching.
    private var scenicCache: [ScenicGridKey: ScenicCacheEntry] = [:]
    private var pendingSearchKeys: Set<ScenicGridKey> = []
    private static let gridResolution: Double = 0.005 // ~500m in degrees
    private static let cacheExpiry: TimeInterval = 3600 // 1 hour

    private struct ScenicGridKey: Hashable, Sendable {
        let latBucket: Int
        let lngBucket: Int
    }

    private struct ScenicCacheEntry: Sendable {
        let pois: [ScenicPOI]
        let fetchedAt: Date
        var isExpired: Bool { Date().timeIntervalSince(fetchedAt) > MockGearDropService.cacheExpiry }
    }

    private func gridKey(for coordinate: CLLocationCoordinate2D) -> ScenicGridKey {
        ScenicGridKey(
            latBucket: Int(coordinate.latitude / Self.gridResolution),
            lngBucket: Int(coordinate.longitude / Self.gridResolution)
        )
    }

    /// Surrounding grid keys (3x3 area) for a coordinate.
    private func surroundingKeys(for coordinate: CLLocationCoordinate2D) -> [ScenicGridKey] {
        let center = gridKey(for: coordinate)
        var keys: [ScenicGridKey] = []
        for dr in -1...1 {
            for dc in -1...1 {
                keys.append(ScenicGridKey(latBucket: center.latBucket + dr, lngBucket: center.lngBucket + dc))
            }
        }
        return keys
    }

    // MARK: - Field Drops

    func checkAndSpawnFieldDrops(around coordinate: CLLocationCoordinate2D, state: GearDropState) async -> [GearDrop] {
        // Check if enough time has passed since last spawn
        if let lastSpawn = state.lastFieldSpawnTime {
            let elapsed = Date().timeIntervalSince(lastSpawn)
            if elapsed < GameConstants.GearDrop.fieldSpawnIntervalMin {
                return []
            }
        }

        // Don't exceed max active field drops
        let currentFieldDrops = activeDrops.filter { $0.type == .field && !$0.isExpired }
        if currentFieldDrops.count >= GameConstants.GearDrop.maxActiveFieldDrops {
            return []
        }

        // Spawn 1-2 field drops
        let count = Int.random(in: 1...2)
        var newDrops: [GearDrop] = []

        for _ in 0..<count {
            let coord = spawnEngine.randomCoordinate(
                around: coordinate,
                radius: GameConstants.GearDrop.spawnRadius
            )
            let rarity = spawnEngine.rollRarity()
            let drop = GearDrop(
                type: .field,
                latitude: coord.latitude,
                longitude: coord.longitude,
                rarity: rarity,
                expiresAt: Date().addingTimeInterval(GameConstants.GearDrop.fieldDespawnTime)
            )
            newDrops.append(drop)
            activeDrops.append(drop)
        }

        return newDrops
    }

    // MARK: - Court Caches

    func generateCourtCaches(courts: [Court], state: GearDropState) async -> [GearDrop] {
        var newDrops: [GearDrop] = []

        for court in courts {
            // Skip if already has an active cache
            if activeDrops.contains(where: { $0.type == .courtCache && $0.courtID == court.id && !$0.isExpired }) {
                continue
            }

            // Skip if on cooldown
            guard state.isCourtCacheAvailable(courtID: court.id) else { continue }

            // Skip if already collected this session
            guard !state.collectedDropIDs.contains(where: { _ in false }) else { continue }

            let rarityBoost = GameConstants.GearDrop.courtDifficultyRarityBoost[court.primaryDifficulty] ?? 0
            let rarity = spawnEngine.rollRarity(boost: rarityBoost)

            // Offset slightly from court coordinate
            let drop = GearDrop(
                type: .courtCache,
                latitude: court.latitude + 0.00012,
                longitude: court.longitude - 0.00012,
                rarity: rarity,
                expiresAt: Date().addingTimeInterval(GameConstants.GearDrop.courtCacheCooldown),
                courtID: court.id,
                requiresMatch: true,
                isUnlocked: false
            )
            newDrops.append(drop)
            activeDrops.append(drop)
        }

        return newDrops
    }

    // MARK: - Scenic POI Prefetch

    func prefetchScenicPoints(around coordinate: CLLocationCoordinate2D) async {
        let keys = surroundingKeys(for: coordinate)
        for key in keys {
            // Skip if already cached and not expired, or already in-flight
            if let entry = scenicCache[key], !entry.isExpired { continue }
            if pendingSearchKeys.contains(key) { continue }
            pendingSearchKeys.insert(key)

            let centerLat = (Double(key.latBucket) + 0.5) * Self.gridResolution
            let centerLng = (Double(key.lngBucket) + 0.5) * Self.gridResolution
            let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng)

            let pois = await searchScenicPOIs(around: center)
            scenicCache[key] = ScenicCacheEntry(pois: pois, fetchedAt: Date())
            pendingSearchKeys.remove(key)
        }
    }

    /// Search MapKit for parks, trails, gardens, and nature areas near a coordinate.
    private func searchScenicPOIs(around center: CLLocationCoordinate2D) async -> [ScenicPOI] {
        let searchRadius: CLLocationDistance = 800 // meters
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: searchRadius * 2,
            longitudinalMeters: searchRadius * 2
        )

        // Search categories in priority order
        let queries: [(String, ScenicPOI.ScenicCategory)] = [
            ("hiking trail", .hikingTrail),
            ("park", .park),
            ("nature reserve", .natureReserve),
            ("botanical garden", .garden),
            ("beach", .beach),
            ("waterfront", .waterfront),
        ]

        var allPOIs: [ScenicPOI] = []

        for (query, category) in queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region
            request.resultTypes = .pointOfInterest

            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                for item in response.mapItems {
                    let poi = ScenicPOI(
                        name: item.name ?? query,
                        coordinate: item.placemark.coordinate,
                        category: category
                    )
                    allPOIs.append(poi)
                }
            } catch {
                // Search failed for this category — continue with others
                continue
            }
        }

        return allPOIs
    }

    /// Get cached scenic POIs near a coordinate, sorted by priority.
    private func nearbyScenicPOIs(around coordinate: CLLocationCoordinate2D) -> [ScenicPOI] {
        let keys = surroundingKeys(for: coordinate)
        var pois: [ScenicPOI] = []
        for key in keys {
            if let entry = scenicCache[key], !entry.isExpired {
                pois.append(contentsOf: entry.pois)
            }
        }

        // Sort by category priority (hiking trails first) then by distance
        let priorityOrder: [ScenicPOI.ScenicCategory] = [
            .hikingTrail, .park, .garden, .natureReserve, .beach, .waterfront
        ]
        let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return pois.sorted { a, b in
            let aPriority = priorityOrder.firstIndex(of: a.category) ?? 99
            let bPriority = priorityOrder.firstIndex(of: b.category) ?? 99
            if aPriority != bPriority { return aPriority < bPriority }
            let aDist = CLLocation(latitude: a.coordinate.latitude, longitude: a.coordinate.longitude).distance(from: loc)
            let bDist = CLLocation(latitude: b.coordinate.latitude, longitude: b.coordinate.longitude).distance(from: loc)
            return aDist < bDist
        }
    }

    // MARK: - Trail Route

    func generateTrailRoute(around coordinate: CLLocationCoordinate2D, playerLevel: Int) async -> TrailRoute {
        let waypointCount = Int.random(in: GameConstants.GearDrop.trailWaypointCountRange)

        // Build waypoint targets: prefer scenic POIs, pad with random coordinates
        let targets = buildScenicWaypoints(
            around: coordinate,
            count: waypointCount,
            spacing: GameConstants.GearDrop.trailSpacing
        )

        // Snap to walking paths (public streets/trails — avoids private land)
        let snappedCoordinates = await snapToWalkingPaths(from: coordinate, targets: targets)

        let trailID = UUID()
        let brandFamilies = ["ProKennex", "Selkirk", "JOOLA", "Engage", "Paddletek", "Franklin"]
        let brandID = brandFamilies.randomElement()

        let trailNames = [
            "The Third Shot Tour", "Erne's Revenge", "Kitchen Confidential",
            "The Dink Dynasty", "No Man's Land Dash", "Stacking Spree",
            "Lob City Limits", "Drop Shot Derby"
        ]
        let trailName = trailNames.randomElement() ?? "Trail"

        var waypoints: [GearDrop] = []
        for (i, coord) in snappedCoordinates.enumerated() {
            let isLast = i == snappedCoordinates.count - 1
            let isFinalStretch = Double(i) >= Double(snappedCoordinates.count) * 0.6

            let rarity: EquipmentRarity
            if isLast {
                rarity = spawnEngine.rollRarity(boost: 0.25, floor: .epic)
            } else if isFinalStretch {
                rarity = spawnEngine.rollRarity(boost: 0.15, floor: .rare)
            } else {
                rarity = spawnEngine.rollRarity()
            }

            let drop = GearDrop(
                type: .trail,
                latitude: coord.latitude,
                longitude: coord.longitude,
                rarity: rarity,
                expiresAt: Date().addingTimeInterval(GameConstants.GearDrop.trailTimeLimit),
                trailID: trailID,
                trailOrder: i
            )
            waypoints.append(drop)
        }

        // Add trail waypoints to active drops
        activeDrops.append(contentsOf: waypoints)

        return TrailRoute(
            id: trailID,
            name: trailName,
            brandID: brandID,
            waypoints: waypoints,
            expiresAt: Date().addingTimeInterval(GameConstants.GearDrop.trailTimeLimit)
        )
    }

    /// Build waypoint targets prioritizing cached scenic POIs.
    /// Falls back to random circular waypoints for any gaps.
    private func buildScenicWaypoints(
        around coordinate: CLLocationCoordinate2D,
        count: Int,
        spacing: Double
    ) -> [CLLocationCoordinate2D] {
        let scenicPOIs = nearbyScenicPOIs(around: coordinate)
        var targets: [CLLocationCoordinate2D] = []
        var usedIndices: Set<Int> = []

        // Try to fill waypoints with scenic POIs within reasonable range
        let maxRange = spacing * Double(count) * 0.6
        let playerLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        for (index, poi) in scenicPOIs.enumerated() {
            if targets.count >= count { break }
            let dist = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
                .distance(from: playerLoc)
            if dist < maxRange && dist > spacing * 0.3 {
                // Ensure minimum spacing between selected POIs
                let tooClose = targets.contains { existing in
                    CLLocation(latitude: existing.latitude, longitude: existing.longitude)
                        .distance(from: CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)) < spacing * 0.5
                }
                if !tooClose {
                    targets.append(poi.coordinate)
                    usedIndices.insert(index)
                }
            }
        }

        // Fill remaining slots with random circular waypoints
        if targets.count < count {
            let remaining = count - targets.count
            let fallbacks = spawnEngine.generateTrailWaypoints(
                from: coordinate,
                count: remaining,
                spacing: spacing
            )
            targets.append(contentsOf: fallbacks)
        }

        // Sort by angle from player to form a walkable loop
        targets.sort { a, b in
            let angleA = atan2(a.longitude - coordinate.longitude, a.latitude - coordinate.latitude)
            let angleB = atan2(b.longitude - coordinate.longitude, b.latitude - coordinate.latitude)
            return angleA < angleB
        }

        return targets
    }

    /// Snap waypoint targets to real walking paths using MapKit directions.
    /// Walking transport type ensures routes follow public streets/trails.
    private func snapToWalkingPaths(
        from start: CLLocationCoordinate2D,
        targets: [CLLocationCoordinate2D]
    ) async -> [CLLocationCoordinate2D] {
        var snappedPoints: [CLLocationCoordinate2D] = []
        var current = start

        for target in targets {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: current))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: target))
            request.transportType = .walking

            do {
                let directions = MKDirections(request: request)
                let response = try await directions.calculate()

                if let route = response.routes.first {
                    let pointCount = route.polyline.pointCount
                    if pointCount > 1 {
                        let pickIndex = Int(Double(pointCount) * 0.8)
                        let points = route.polyline.points()
                        let snapped = points[min(pickIndex, pointCount - 1)]
                        let coord = snapped.coordinate
                        snappedPoints.append(coord)
                        current = coord
                    } else {
                        snappedPoints.append(target)
                        current = target
                    }
                } else {
                    snappedPoints.append(target)
                    current = target
                }
            } catch {
                snappedPoints.append(target)
                current = target
            }
        }

        return snappedPoints
    }

    // MARK: - Contested Drops

    func spawnContestedDrops(around coordinate: CLLocationCoordinate2D, state: GearDropState) async -> [GearDrop] {
        guard state.contestedDropsClaimed < GameConstants.GearDrop.contestedMaxPerDay else { return [] }

        // Don't spawn if already have active contested drops
        let activeContested = activeDrops.filter { $0.type == .contested && !$0.isExpired }
        if !activeContested.isEmpty { return [] }

        let count = Int.random(in: 1...2)
        var newDrops: [GearDrop] = []

        for _ in 0..<count {
            let distance = Double.random(in: 500...GameConstants.GearDrop.contestedVisibilityRadius)
            let coord = spawnEngine.randomCoordinate(around: coordinate, radius: distance)
            let rarity = spawnEngine.rollRarity(boost: 0.20, floor: .rare)
            let difficulties: [NPCDifficulty] = [.advanced, .expert, .master]
            let guardianDifficulty = difficulties.randomElement() ?? .advanced

            let drop = GearDrop(
                type: .contested,
                latitude: coord.latitude,
                longitude: coord.longitude,
                rarity: rarity,
                expiresAt: Date().addingTimeInterval(GameConstants.GearDrop.fieldDespawnTime * 2),
                guardianDifficulty: guardianDifficulty
            )
            newDrops.append(drop)
            activeDrops.append(drop)
        }

        return newDrops
    }

    // MARK: - Fog Stashes

    func checkFogStashes(newlyRevealed: Set<FogCell>, allRevealed: Set<FogCell>) async -> [GearDrop] {
        var stashes: [GearDrop] = []

        for cell in newlyRevealed {
            let roll = Double.random(in: 0...1)
            guard roll < GameConstants.GearDrop.fogStashChancePerCell else { continue }

            let remoteness = spawnEngine.remotenessBoost(cell: cell, revealedCells: allRevealed)
            let rarity = spawnEngine.rollRarity(boost: remoteness)

            let cellCenter = FogOfWar.coordinate(for: cell)

            let drop = GearDrop(
                type: .fogStash,
                latitude: cellCenter.latitude,
                longitude: cellCenter.longitude,
                rarity: rarity,
                expiresAt: Date().addingTimeInterval(GameConstants.GearDrop.fieldDespawnTime),
                fogCell: cell
            )
            stashes.append(drop)
            activeDrops.append(drop)
        }

        return stashes
    }

    // MARK: - Collection

    func collectDrop(_ drop: GearDrop, playerLevel: Int) async -> (equipment: [Equipment], coins: Int) {
        // Remove from active drops
        activeDrops.removeAll { $0.id == drop.id }

        let itemCount: Int
        let coins: Int

        switch drop.type {
        case .field:
            itemCount = Int.random(in: 1...2)
            coins = Int.random(in: 5...25)
        case .courtCache:
            itemCount = 2
            coins = Int.random(in: 20...50)
        case .trail:
            let isLast = drop.trailOrder == nil ? false :
                activeDrops.filter({ $0.trailID == drop.trailID }).isEmpty
            itemCount = isLast ? Int.random(in: 2...3) : 1
            coins = isLast ? Int.random(in: 50...100) : Int.random(in: 10...30)
        case .contested:
            itemCount = 3
            coins = Int.random(in: 50...150)
        case .fogStash:
            itemCount = 1
            coins = Int.random(in: 10...40)
        }

        var equipment: [Equipment] = []
        for _ in 0..<itemCount {
            let item = lootGenerator.generateEquipment(rarity: drop.rarity)
            equipment.append(item)
        }

        return (equipment: equipment, coins: coins)
    }

    // MARK: - Active Drops

    func getActiveDrops() async -> [GearDrop] {
        activeDrops.filter { !$0.isExpired }
    }

    func removeExpiredDrops() async {
        activeDrops.removeAll { $0.isExpired }
    }

    // MARK: - Internal helpers

    /// Unlock a court cache after winning a match at that court.
    func unlockCourtCache(courtID: UUID) async -> GearDrop? {
        guard let index = activeDrops.firstIndex(where: {
            $0.type == .courtCache && $0.courtID == courtID && !$0.isUnlocked
        }) else { return nil }

        activeDrops[index].isUnlocked = true
        activeDrops[index].requiresMatch = false
        return activeDrops[index]
    }
}
