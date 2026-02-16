import Foundation
import CoreLocation

struct GearDropSpawnEngine: Sendable {
    private let rng: RandomSource

    init(rng: RandomSource = SystemRandomSource()) {
        self.rng = rng
    }

    /// Generate a random coordinate within `radius` meters of `center`.
    func randomCoordinate(around center: CLLocationCoordinate2D, radius: Double) -> CLLocationCoordinate2D {
        let angle = Double(rng.nextInt(in: 0...359)) * .pi / 180.0
        let distance = Double(rng.nextInt(in: Int(radius * 0.3)...Int(radius))) // avoid spawning right on top of player
        let latOffset = distance / 111_000.0 * cos(angle)
        let lngOffset = distance / (111_000.0 * cos(center.latitude * .pi / 180)) * sin(angle)
        return CLLocationCoordinate2D(
            latitude: center.latitude + latOffset,
            longitude: center.longitude + lngOffset
        )
    }

    /// Generate trail waypoints in a rough loop around a starting point.
    func generateTrailWaypoints(
        from start: CLLocationCoordinate2D,
        count: Int,
        spacing: Double
    ) -> [CLLocationCoordinate2D] {
        var waypoints: [CLLocationCoordinate2D] = []
        var current = start

        // Walk in a rough circle with some randomness
        let angleStep = 360.0 / Double(count)
        for i in 0..<count {
            let baseAngle = angleStep * Double(i) + Double(rng.nextInt(in: -20...20))
            let angle = baseAngle * .pi / 180.0
            let distance = spacing + Double(rng.nextInt(in: -30...30))

            let latOffset = distance / 111_000.0 * cos(angle)
            let lngOffset = distance / (111_000.0 * cos(current.latitude * .pi / 180)) * sin(angle)

            let next = CLLocationCoordinate2D(
                latitude: start.latitude + latOffset,
                longitude: start.longitude + lngOffset
            )
            waypoints.append(next)
            current = next
        }

        return waypoints
    }

    /// Roll a rarity with optional boost and floor.
    func rollRarity(boost: Double = 0, floor: EquipmentRarity? = nil) -> EquipmentRarity {
        let weights: [(EquipmentRarity, Double)] = [
            (.common, 0.45),
            (.uncommon, 0.30),
            (.rare, 0.15),
            (.epic, 0.08),
            (.legendary, 0.02)
        ]

        // Apply boost: shift weight from common/uncommon toward rare+
        var adjusted = weights
        let boostAmount = min(boost, 0.30)
        if boostAmount > 0 {
            adjusted[0] = (.common, max(0.10, adjusted[0].1 - boostAmount * 0.5))
            adjusted[1] = (.uncommon, max(0.10, adjusted[1].1 - boostAmount * 0.3))
            adjusted[2] = (.rare, adjusted[2].1 + boostAmount * 0.4)
            adjusted[3] = (.epic, adjusted[3].1 + boostAmount * 0.25)
            adjusted[4] = (.legendary, adjusted[4].1 + boostAmount * 0.15)
        }

        // Normalize
        let total = adjusted.reduce(0) { $0 + $1.1 }
        let roll = Double(rng.nextInt(in: 0...999)) / 1000.0 * total
        var cumulative = 0.0
        var result: EquipmentRarity = .common
        for (rarity, weight) in adjusted {
            cumulative += weight
            if roll < cumulative {
                result = rarity
                break
            }
        }

        // Apply floor
        if let floor, result < floor {
            return floor
        }
        return result
    }

    /// Calculate remoteness bonus for fog stashes based on how isolated the cell is.
    func remotenessBoost(cell: FogCell, revealedCells: Set<FogCell>) -> Double {
        // Count revealed neighbors — fewer neighbors = more remote
        var neighborCount = 0
        for dr in -2...2 {
            for dc in -2...2 {
                if dr == 0 && dc == 0 { continue }
                if revealedCells.contains(FogCell(row: cell.row + dr, col: cell.col + dc)) {
                    neighborCount += 1
                }
            }
        }
        // Max 24 neighbors in 5x5 grid minus center
        let maxNeighbors = 24
        let isolation = Double(maxNeighbors - neighborCount) / Double(maxNeighbors)
        return isolation * GameConstants.GearDrop.remotenessRarityBoost
    }
}
