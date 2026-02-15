import Foundation
import CoreLocation
import SwiftUI

@MainActor
@Observable
final class MapViewModel {
    private let courtService: CourtService
    let locationManager: LocationManager

    var courts: [Court] = []
    var selectedCourt: Court?
    var npcsAtSelectedCourt: [NPC] = []
    var showCourtDetail = false
    var courtsLoaded = false
    var pendingChallenge: NPC?

    static let discoveryRadius: CLLocationDistance = 200

    init(courtService: CourtService, locationManager: LocationManager) {
        self.courtService = courtService
        self.locationManager = locationManager
    }

    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    func requestLocationPermission() {
        locationManager.requestAuthorization()
    }

    func startLocationUpdates() {
        locationManager.startUpdates()
    }

    func generateCourtsIfNeeded(around coordinate: CLLocationCoordinate2D) async {
        guard !courtsLoaded else { return }
        if !(await courtService.hasGenerated) {
            await courtService.generateCourts(around: coordinate)
        }
        courts = await courtService.getAllCourts()
        courtsLoaded = true
    }

    func selectCourt(_ court: Court) async {
        selectedCourt = court
        npcsAtSelectedCourt = await courtService.getNPCsAtCourt(court.id)
        showCourtDetail = true
    }

    func dismissCourtDetail() {
        showCourtDetail = false
        selectedCourt = nil
        npcsAtSelectedCourt = []
    }

    func effectiveLocation(devOverride: CLLocationCoordinate2D?) -> CLLocation? {
        if let override = devOverride {
            return CLLocation(latitude: override.latitude, longitude: override.longitude)
        }
        return locationManager.currentLocation
    }

    /// Check if any undiscovered courts are within discovery radius.
    /// Returns IDs of newly discovered courts.
    func checkDiscovery(
        playerLocation: CLLocation,
        discoveredIDs: Set<UUID>,
        isDevMode: Bool
    ) -> [UUID] {
        if isDevMode {
            return courts.map(\.id).filter { !discoveredIDs.contains($0) }
        }
        var newlyDiscovered: [UUID] = []
        for court in courts where !discoveredIDs.contains(court.id) {
            let courtLocation = CLLocation(latitude: court.latitude, longitude: court.longitude)
            if playerLocation.distance(from: courtLocation) <= Self.discoveryRadius {
                newlyDiscovered.append(court.id)
            }
        }
        return newlyDiscovered
    }
}
