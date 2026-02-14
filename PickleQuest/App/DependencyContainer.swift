import Foundation

/// Protocol-based dependency container. Swap mock implementations for real ones later.
@MainActor
final class DependencyContainer: ObservableObject {
    let playerService: PlayerService
    let matchService: MatchService
    let npcService: NPCService
    let inventoryService: InventoryService

    init(
        playerService: PlayerService? = nil,
        matchService: MatchService? = nil,
        npcService: NPCService? = nil,
        inventoryService: InventoryService? = nil
    ) {
        self.playerService = playerService ?? MockPlayerService()
        self.matchService = matchService ?? MockMatchService()
        self.npcService = npcService ?? MockNPCService()
        self.inventoryService = inventoryService ?? MockInventoryService()
    }

    static let shared = DependencyContainer()
}
