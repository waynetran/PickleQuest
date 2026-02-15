import Foundation
import CoreLocation

protocol CourtService: Sendable {
    func generateCourts(around center: CLLocationCoordinate2D) async
    func getAllCourts() async -> [Court]
    func getCourt(by id: UUID) async -> Court?
    func getNPCsAtCourt(_ courtID: UUID) async -> [NPC]
    func getLadderNPCs(courtID: UUID) async -> [NPC]  // sorted weakest → strongest
    var hasGenerated: Bool { get async }
}
