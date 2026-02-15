import Foundation
import CoreLocation

struct Court: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let latitude: Double
    let longitude: Double
    let difficultyTiers: Set<NPCDifficulty>
    let courtCount: Int

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Coordinate slightly offset from court for coach sprite placement
    var coachCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude - 0.00015, longitude: longitude + 0.00015)
    }

    var primaryDifficulty: NPCDifficulty {
        difficultyTiers.max() ?? .beginner
    }
}

extension Court: MapItem {
    var mapIconName: String { "sportscourt.fill" }
}
