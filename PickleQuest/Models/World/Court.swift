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

    var primaryDifficulty: NPCDifficulty {
        difficultyTiers.max() ?? .beginner
    }
}

extension Court: MapItem {
    var mapIconName: String { "sportscourt.fill" }
}
