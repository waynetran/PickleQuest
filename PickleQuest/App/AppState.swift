import Foundation
import SwiftUI

@MainActor
@Observable
final class AppState {
    var player: Player
    var selectedTab: AppTab = .match

    init(player: Player = Player.newPlayer(name: "Rookie")) {
        self.player = player
    }
}

enum AppTab: String, CaseIterable {
    case match = "Match"
    case profile = "Profile"
    case inventory = "Inventory"
    case store = "Store"

    var iconName: String {
        switch self {
        case .match: return "sportscourt"
        case .profile: return "person.fill"
        case .inventory: return "bag.fill"
        case .store: return "cart.fill"
        }
    }
}
