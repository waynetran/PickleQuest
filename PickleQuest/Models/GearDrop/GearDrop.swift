import Foundation
import CoreLocation

enum GearDropType: String, Codable, CaseIterable, Sendable {
    case field
    case courtCache
    case trail
    case contested
    case fogStash

    var displayName: String {
        switch self {
        case .field: return "Field Drop"
        case .courtCache: return "Court Cache"
        case .trail: return "Trail Drop"
        case .contested: return "Contested Drop"
        case .fogStash: return "Fog Stash"
        }
    }

    var icon: String {
        switch self {
        case .field: return "bag.fill"
        case .courtCache: return "lock.fill"
        case .trail: return "figure.walk"
        case .contested: return "flame.fill"
        case .fogStash: return "eye.slash.fill"
        }
    }
}

struct GearDrop: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let type: GearDropType
    let latitude: Double
    let longitude: Double
    let rarity: EquipmentRarity
    let spawnedAt: Date
    let expiresAt: Date

    // Court cache fields
    let courtID: UUID?
    var requiresMatch: Bool

    // Trail fields
    let trailID: UUID?
    let trailOrder: Int?

    // Contested fields
    let guardianDifficulty: NPCDifficulty?

    // Fog stash fields
    let fogCell: FogCell?

    var isUnlocked: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isExpired: Bool {
        Date() >= expiresAt
    }

    init(
        id: UUID = UUID(),
        type: GearDropType,
        latitude: Double,
        longitude: Double,
        rarity: EquipmentRarity,
        spawnedAt: Date = Date(),
        expiresAt: Date,
        courtID: UUID? = nil,
        requiresMatch: Bool = false,
        trailID: UUID? = nil,
        trailOrder: Int? = nil,
        guardianDifficulty: NPCDifficulty? = nil,
        fogCell: FogCell? = nil,
        isUnlocked: Bool = true
    ) {
        self.id = id
        self.type = type
        self.latitude = latitude
        self.longitude = longitude
        self.rarity = rarity
        self.spawnedAt = spawnedAt
        self.expiresAt = expiresAt
        self.courtID = courtID
        self.requiresMatch = requiresMatch
        self.trailID = trailID
        self.trailOrder = trailOrder
        self.guardianDifficulty = guardianDifficulty
        self.fogCell = fogCell
        self.isUnlocked = isUnlocked
    }
}
