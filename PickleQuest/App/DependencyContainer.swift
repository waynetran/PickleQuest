import Foundation

/// Protocol-based dependency container. Swap mock implementations for real ones later.
@MainActor
final class DependencyContainer: ObservableObject {
    let playerService: PlayerService
    let matchService: MatchService
    let npcService: NPCService
    let inventoryService: InventoryService
    let storeService: StoreService

    init(
        playerService: PlayerService? = nil,
        matchService: MatchService? = nil,
        npcService: NPCService? = nil,
        inventoryService: InventoryService? = nil,
        storeService: StoreService? = nil
    ) {
        let inventory = inventoryService ?? MockInventoryService()
        self.playerService = playerService ?? MockPlayerService()
        self.inventoryService = inventory
        self.matchService = matchService ?? MockMatchService(inventoryService: inventory)
        self.npcService = npcService ?? MockNPCService()
        self.storeService = storeService ?? MockStoreService()
    }

    static let shared = DependencyContainer()
}
