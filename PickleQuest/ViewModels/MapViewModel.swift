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
    private let gearDropService: GearDropService
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

    // Gear drop state
    var activeGearDrops: [GearDrop] = []
    var selectedGearDrop: GearDrop?
    var gearDropLoot: [Equipment] = []
    var gearDropCoins: Int = 0
    var showGearDropReveal = false
    var gearDropLootDecisions: [UUID: LootDecision] = [:]
    var gearDropToast: String?
    var pendingCourtCacheDrop: GearDrop?
    var showContestedSheet = false
    var selectedContestedDrop: GearDrop?

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
        gearDropService: GearDropService,
        locationManager: LocationManager
    ) {
        self.courtService = courtService
        self.courtProgressionService = courtProgressionService
        self.npcService = npcService
        self.coachService = coachService
        self.dailyChallengeService = dailyChallengeService
        self.gearDropService = gearDropService
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

    // MARK: - Gear Drops

    /// Refresh all gear drops — called on location change.
    func refreshGearDrops(
        around coordinate: CLLocationCoordinate2D,
        state: inout GearDropState,
        discoveredCourts: [Court]
    ) async {
        // Daily reset
        state.resetDailyIfNeeded()

        // Remove expired
        await gearDropService.removeExpiredDrops()

        // Spawn field drops
        let fieldDrops = await gearDropService.checkAndSpawnFieldDrops(around: coordinate, state: state)
        if !fieldDrops.isEmpty {
            state.lastFieldSpawnTime = Date()
        }

        // Generate court caches at discovered courts
        let _ = await gearDropService.generateCourtCaches(courts: discoveredCourts, state: state)

        // Spawn contested drops
        let _ = await gearDropService.spawnContestedDrops(around: coordinate, state: state)

        // Refresh active drops list
        activeGearDrops = await gearDropService.getActiveDrops()
    }

    /// Check fog stashes for newly revealed cells.
    func checkFogStashes(newlyRevealed: Set<FogCell>, allRevealed: Set<FogCell>) async {
        let stashes = await gearDropService.checkFogStashes(
            newlyRevealed: newlyRevealed,
            allRevealed: allRevealed
        )
        if !stashes.isEmpty {
            activeGearDrops.append(contentsOf: stashes)
            gearDropToast = "Hidden stash found!"
        }
    }

    /// Check if a drop is within pickup range.
    func isDropInRange(_ drop: GearDrop, playerLocation: CLLocation) -> Bool {
        let dropLocation = CLLocation(latitude: drop.latitude, longitude: drop.longitude)
        return playerLocation.distance(from: dropLocation) <= GameConstants.GearDrop.pickupRadius
    }

    /// Handle tapping a gear drop on the map.
    func handleGearDropTap(_ drop: GearDrop, playerLocation: CLLocation?) {
        guard let playerLocation else { return }

        // Check range
        guard isDropInRange(drop, playerLocation: playerLocation) else {
            gearDropToast = "Walk closer to pick up!"
            return
        }

        // Court cache: must be unlocked
        if drop.type == .courtCache && !drop.isUnlocked {
            gearDropToast = "Win a match at this court to unlock!"
            return
        }

        // Contested: show challenge sheet
        if drop.type == .contested {
            selectedContestedDrop = drop
            showContestedSheet = true
            return
        }

        // Collect the drop
        Task {
            await collectGearDrop(drop, playerLevel: 1) // playerLevel passed from caller
        }
    }

    /// Collect a gear drop and show the reveal sheet.
    func collectGearDrop(_ drop: GearDrop, playerLevel: Int) async {
        let result = await gearDropService.collectDrop(drop, playerLevel: playerLevel)
        gearDropLoot = result.equipment
        gearDropCoins = result.coins
        gearDropLootDecisions = [:]
        selectedGearDrop = drop
        showGearDropReveal = true

        // Remove from active list
        activeGearDrops.removeAll { $0.id == drop.id }
    }

    /// Unlock court cache after winning a match at a court.
    func unlockCourtCacheIfNeeded(courtID: UUID) async -> GearDrop? {
        guard let mockService = gearDropService as? MockGearDropService else { return nil }
        guard let unlockedDrop = await mockService.unlockCourtCache(courtID: courtID) else { return nil }

        // Update active drops
        if let index = activeGearDrops.firstIndex(where: { $0.id == unlockedDrop.id }) {
            activeGearDrops[index] = unlockedDrop
        }

        return unlockedDrop
    }

    /// Start a trail route.
    func startTrailRoute(around coordinate: CLLocationCoordinate2D, playerLevel: Int) async -> TrailRoute {
        let route = await gearDropService.generateTrailRoute(around: coordinate, playerLevel: playerLevel)
        activeGearDrops = await gearDropService.getActiveDrops()
        return route
    }
}
