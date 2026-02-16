import Foundation
import SwiftUI
import CoreLocation

@MainActor
@Observable
final class AppState {
    var player: Player
    var selectedTab: AppTab = .match
    var appPhase: AppPhase = .loading
    var activePlayerID: UUID?
    var tutorialCompleted: Bool = false

    // Dev mode
    var isDevMode: Bool = true
    var devModeSnapshot: Player?
    var locationOverride: CLLocationCoordinate2D?
    var devTrainingEnabled: Bool = true  // TODO: Remove — controls dev drill shortcut

    // Fog of war
    var fogOfWarEnabled: Bool = true
    var revealedFogCells: Set<FogCell> = []

    init(player: Player? = nil) {
        self.player = player ?? Player.newPlayer(name: "Rookie")
        self.devModeSnapshot = self.player
    }

    func revealFog(around coordinate: CLLocationCoordinate2D) {
        let newCells = FogOfWar.cellsToReveal(around: coordinate)
        revealedFogCells.formUnion(newCells)
    }

    func enableDevMode() {
        devModeSnapshot = player
        isDevMode = true
    }

    func disableDevMode() {
        isDevMode = false
    }

    func resetToTrueValues() {
        guard let snapshot = devModeSnapshot else { return }
        player = snapshot
        locationOverride = nil
    }

    func saveCurrentPlayer(
        using persistenceService: PersistenceService,
        inventory: [Equipment],
        consumables: [Consumable]
    ) async {
        let bundle = SavedPlayerBundle(
            player: player,
            inventory: inventory,
            consumables: consumables,
            fogCells: revealedFogCells,
            tutorialCompleted: tutorialCompleted
        )
        try? await persistenceService.savePlayer(bundle)
    }

    func loadFromBundle(_ bundle: SavedPlayerBundle) {
        player = bundle.player
        activePlayerID = bundle.player.id
        tutorialCompleted = bundle.tutorialCompleted
        revealedFogCells = bundle.fogCells
        devModeSnapshot = bundle.player
    }
}

enum AppPhase: Equatable {
    case loading
    case playerChooser
    case characterCreation
    case tutorialMatch
    case tutorialPostMatch
    case playing
    case devTraining // TODO: Remove — temporary dev shortcut to test interactive drills
}

enum AppTab: String, CaseIterable {
    case match = "Map"
    case performance = "Performance"
    case profile = "Profile"
    case inventory = "Inventory"
    case store = "Store"

    var iconName: String {
        switch self {
        case .match: return "map.fill"
        case .performance: return "chart.line.uptrend.xyaxis"
        case .profile: return "person.fill"
        case .inventory: return "bag.fill"
        case .store: return "cart.fill"
        }
    }
}
