import Foundation

/// Protocol-based dependency container. Swap mock implementations for real ones later.
@MainActor
final class DependencyContainer: ObservableObject {
    let playerService: PlayerService
    let matchService: MatchService
    let npcService: NPCService
    let inventoryService: InventoryService
    let storeService: StoreService
    let courtService: CourtService
    let courtProgressionService: CourtProgressionService
    let tournamentService: TournamentService
    let trainingService: TrainingService
    let coachService: CoachService
    let dailyChallengeService: DailyChallengeService
    let locationManager: LocationManager

    init(
        playerService: PlayerService? = nil,
        matchService: MatchService? = nil,
        npcService: NPCService? = nil,
        inventoryService: InventoryService? = nil,
        storeService: StoreService? = nil,
        courtService: CourtService? = nil,
        courtProgressionService: CourtProgressionService? = nil,
        tournamentService: TournamentService? = nil,
        trainingService: TrainingService? = nil,
        coachService: CoachService? = nil,
        dailyChallengeService: DailyChallengeService? = nil,
        locationManager: LocationManager? = nil
    ) {
        let inventory = inventoryService ?? MockInventoryService()
        let npcs = npcService ?? MockNPCService()
        self.playerService = playerService ?? MockPlayerService()
        self.inventoryService = inventory
        self.matchService = matchService ?? MockMatchService(inventoryService: inventory)
        self.npcService = npcs
        self.storeService = storeService ?? MockStoreService()
        self.courtService = courtService ?? MockCourtService(npcService: npcs)
        self.courtProgressionService = courtProgressionService ?? MockCourtProgressionService()
        self.tournamentService = tournamentService ?? MockTournamentService()
        self.trainingService = trainingService ?? MockTrainingService()
        self.coachService = coachService ?? MockCoachService()
        self.dailyChallengeService = dailyChallengeService ?? MockDailyChallengeService()
        self.locationManager = locationManager ?? LocationManager()
    }

    static let shared = DependencyContainer()
}
