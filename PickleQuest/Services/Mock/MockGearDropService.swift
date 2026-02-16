import Foundation
import CoreLocation

actor MockGearDropService: GearDropService {
    private var activeDrops: [GearDrop] = []
    private let spawnEngine = GearDropSpawnEngine()
    private let lootGenerator = LootGenerator()

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

    // MARK: - Trail Route

    func generateTrailRoute(around coordinate: CLLocationCoordinate2D, playerLevel: Int) async -> TrailRoute {
        let waypointCount = Int.random(in: GameConstants.GearDrop.trailWaypointCountRange)
        let coordinates = spawnEngine.generateTrailWaypoints(
            from: coordinate,
            count: waypointCount,
            spacing: GameConstants.GearDrop.trailSpacing
        )

        let trailID = UUID()
        let brandFamilies = ["ProKennex", "Selkirk", "JOOLA", "Engage", "Paddletek", "Franklin"]
        let brandID = brandFamilies.randomElement()

        let trailNames = [
            "Morning Hustle", "Dink Run", "Kitchen Walk",
            "Baseline Blitz", "Court Circuit", "Rally Route",
            "Power Path", "Spin Trail"
        ]
        let trailName = trailNames.randomElement() ?? "Trail"

        var waypoints: [GearDrop] = []
        for (i, coord) in coordinates.enumerated() {
            let isLast = i == coordinates.count - 1
            let isFinalStretch = Double(i) >= Double(coordinates.count) * 0.6

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
