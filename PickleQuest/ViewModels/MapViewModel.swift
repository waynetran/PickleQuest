import Foundation
import CoreLocation
import MapKit
import SwiftUI

@MainActor
@Observable
final class MapViewModel {
    private let courtService: CourtService
    private let courtProgressionService: CourtProgressionService
    private let npcService: NPCService
    private let coachService: CoachService
    private let dailyChallengeService: DailyChallengeService
    let locationManager: LocationManager

    var courts: [Court] = []
    var selectedCourt: Court?
    var npcsAtSelectedCourt: [NPC] = []
    var hustlersAtSelectedCourt: [NPC] = []
    var npcPursesAtSelectedCourt: [UUID: Int] = [:]
    var showCourtDetail = false
    var courtsLoaded = false
    // Court ladder state
    var currentLadder: CourtLadder?
    var currentCourtPerk: CourtPerk?
    var alphaNPC: NPC?
    var ladderAdvanceResult: LadderAdvanceResult?

    // Coach state
    var coachAtSelectedCourt: Coach?
    var courtIDsWithCoaches: Set<UUID> = []
    var coachAppearances: [UUID: CharacterAppearance] = [:] // courtID → appearance for map sprites

    // Daily challenges
    var dailyChallengeState: DailyChallengeState?

    // Dev mode movement
    var isStickyMode = false
    var lastCameraRegion: MKCoordinateRegion?

    static let discoveryRadius: CLLocationDistance = 200
    private static let moveStepMeters: Double = 50

    init(
        courtService: CourtService,
        courtProgressionService: CourtProgressionService,
        npcService: NPCService,
        coachService: CoachService,
        dailyChallengeService: DailyChallengeService,
        locationManager: LocationManager
    ) {
        self.courtService = courtService
        self.courtProgressionService = courtProgressionService
        self.npcService = npcService
        self.coachService = coachService
        self.dailyChallengeService = dailyChallengeService
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

        // Assign coaches to ~50% of courts
        let courtDifficulties = Dictionary(uniqueKeysWithValues: courts.map { ($0.id, $0.primaryDifficulty) })
        await coachService.assignCoaches(to: courts.map(\.id), courtDifficulties: courtDifficulties)

        // Build set of court IDs that have coaches (for map display)
        var coachIDs = Set<UUID>()
        var appearances: [UUID: CharacterAppearance] = [:]
        let allCoaches = await coachService.getAllCoaches()
        for (courtID, coach) in allCoaches {
            coachIDs.insert(courtID)
            appearances[courtID] = coach.appearance
        }
        for court in courts {
            if await coachService.isAlphaCoachCourt(court.id) {
                coachIDs.insert(court.id)
                // Pre-compute appearance from the strongest NPC at this court
                if appearances[court.id] == nil {
                    let npcs = await courtService.getLadderNPCs(courtID: court.id)
                    if let strongest = npcs.max(by: { $0.duprRating < $1.duprRating }) {
                        appearances[court.id] = AppearanceGenerator.appearance(for: strongest)
                    }
                }
            }
        }
        courtIDsWithCoaches = coachIDs
        coachAppearances = appearances
    }

    func selectCourt(_ court: Court) async {
        selectedCourt = court
        npcsAtSelectedCourt = await courtService.getLadderNPCs(courtID: court.id)
        hustlersAtSelectedCourt = await courtService.getHustlersAtCourt(court.id)

        // Load purses for all NPCs at this court
        var purses: [UUID: Int] = [:]
        for npc in npcsAtSelectedCourt {
            purses[npc.id] = await npcService.getPurse(npcID: npc.id)
        }
        for hustler in hustlersAtSelectedCourt {
            purses[hustler.id] = await npcService.getPurse(npcID: hustler.id)
        }
        npcPursesAtSelectedCourt = purses

        // Initialize ladder if needed
        let npcIDs = npcsAtSelectedCourt.map(\.id)
        await courtProgressionService.initializeLadder(courtID: court.id, gameType: .singles, npcIDs: npcIDs)

        // Load ladder state
        currentLadder = await courtProgressionService.getLadder(courtID: court.id, gameType: .singles)
        currentCourtPerk = await courtProgressionService.getCourtPerk(courtID: court.id)
        alphaNPC = await courtProgressionService.getAlphaNPC(courtID: court.id, gameType: .singles)
        ladderAdvanceResult = nil

        // Load coach at this court
        if await coachService.isAlphaCoachCourt(court.id) {
            if let alpha = alphaNPC {
                // Alpha available — use as coach
                let defeated = currentLadder?.alphaDefeated ?? false
                let coach = Coach.fromAlphaNPC(alpha, alphaDefeated: defeated)
                await coachService.setAlphaCoach(coach, courtID: court.id)
                coachAtSelectedCourt = coach
                coachAppearances[court.id] = coach.appearance
            } else if let strongest = npcsAtSelectedCourt.max(by: { $0.duprRating < $1.duprRating }) {
                // Alpha not unlocked yet — strongest NPC coaches
                let coach = Coach.fromAlphaNPC(strongest, alphaDefeated: false)
                coachAtSelectedCourt = coach
                coachAppearances[court.id] = coach.appearance
            }
        } else {
            coachAtSelectedCourt = await coachService.getCoachAtCourt(court.id)
        }

        showCourtDetail = true
    }

    func dismissCourtDetail() {
        showCourtDetail = false
        selectedCourt = nil
        npcsAtSelectedCourt = []
        hustlersAtSelectedCourt = []
        npcPursesAtSelectedCourt = [:]
        currentLadder = nil
        currentCourtPerk = nil
        alphaNPC = nil
        ladderAdvanceResult = nil
        coachAtSelectedCourt = nil
    }

    func refreshPurses() async {
        var purses: [UUID: Int] = [:]
        for npc in npcsAtSelectedCourt {
            purses[npc.id] = await npcService.getPurse(npcID: npc.id)
        }
        for hustler in hustlersAtSelectedCourt {
            purses[hustler.id] = await npcService.getPurse(npcID: hustler.id)
        }
        npcPursesAtSelectedCourt = purses
    }

    // MARK: - Daily Challenges

    func loadDailyChallenges(playerState: DailyChallengeState?) async {
        if let existing = playerState {
            dailyChallengeState = await dailyChallengeService.checkAndResetIfNeeded(current: existing)
        } else {
            dailyChallengeState = await dailyChallengeService.getTodaysChallenges()
        }
    }

    /// Validate that an NPC can be challenged based on ladder position.
    func canChallengeNPC(_ npc: NPC) -> Bool {
        guard let ladder = currentLadder else { return true }
        return ladder.canChallenge(npcID: npc.id)
    }

    /// Record a match win against an NPC, advancing the ladder.
    func recordMatchResult(courtID: UUID, npcID: UUID, didWin: Bool) async {
        guard didWin else { return }
        guard let court = await courtService.getCourt(by: courtID) else { return }

        ladderAdvanceResult = await courtProgressionService.recordDefeat(
            courtID: courtID,
            gameType: .singles,
            npcID: npcID,
            court: court,
            npcService: npcService
        )

        // Refresh ladder state
        currentLadder = await courtProgressionService.getLadder(courtID: courtID, gameType: .singles)
        currentCourtPerk = await courtProgressionService.getCourtPerk(courtID: courtID)
        alphaNPC = await courtProgressionService.getAlphaNPC(courtID: courtID, gameType: .singles)
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
        var newlyDiscovered: [UUID] = []
        for court in courts where !discoveredIDs.contains(court.id) {
            let courtLocation = CLLocation(latitude: court.latitude, longitude: court.longitude)
            if playerLocation.distance(from: courtLocation) <= Self.discoveryRadius {
                newlyDiscovered.append(court.id)
            }
        }
        return newlyDiscovered
    }

    // MARK: - Dev Mode Movement

    enum MoveDirection {
        case north, south, east, west
    }

    /// Move the player ~50m in the given direction (dev mode only).
    func movePlayer(direction: MoveDirection, appState: AppState) {
        guard appState.isDevMode else { return }

        let current = appState.locationOverride
            ?? locationManager.currentLocation?.coordinate
        guard let coord = current else { return }

        let latStep = Self.moveStepMeters / 111_000.0
        let lngStep = Self.moveStepMeters / (111_000.0 * cos(coord.latitude * .pi / 180))

        var newLat = coord.latitude
        var newLng = coord.longitude

        switch direction {
        case .north: newLat += latStep
        case .south: newLat -= latStep
        case .east: newLng += lngStep
        case .west: newLng -= lngStep
        }

        appState.locationOverride = CLLocationCoordinate2D(latitude: newLat, longitude: newLng)
    }

    /// In sticky mode, update the player location to the map camera center.
    func updateStickyLocation(center: CLLocationCoordinate2D, appState: AppState) {
        guard appState.isDevMode, isStickyMode else { return }
        appState.locationOverride = center
    }
}
