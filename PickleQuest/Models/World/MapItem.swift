import Foundation
import CoreLocation

protocol MapItem: Identifiable, Sendable {
    var id: UUID { get }
    var name: String { get }
    var coordinate: CLLocationCoordinate2D { get }
    var mapIconName: String { get }
}
