import Foundation
import SwiftUI
import CoreLocation

@MainActor
@Observable
final class AppState {
    var player: Player
    var selectedTab: AppTab = .match

    // Dev mode
    var isDevMode: Bool = true
    var devModeSnapshot: Player?
    var locationOverride: CLLocationCoordinate2D?

    // Fog of war
    var fogOfWarEnabled: Bool = true
    var revealedFogCells: Set<FogCell> = []

    init(player: Player = Player.newPlayer(name: "Rookie")) {
        self.player = player
        self.devModeSnapshot = player
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
