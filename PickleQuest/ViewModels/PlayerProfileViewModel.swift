import Foundation
import SwiftUI

@MainActor
@Observable
final class PlayerProfileViewModel {
    private let playerService: PlayerService

    var player: Player?
    var isLoading = false

    init(playerService: PlayerService) {
        self.playerService = playerService
    }

    func loadPlayer() async {
        isLoading = true
        player = await playerService.getPlayer()
        isLoading = false
    }
}
