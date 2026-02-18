import AVFoundation
import SpriteKit

@MainActor
final class SoundManager {
    static let shared = SoundManager()

    enum SoundID: String, CaseIterable {
        case paddleHit = "paddle_hit"
        case paddleHitSmash = "paddle_hit_smash"
        case paddleHitDistant = "paddle_hit_distant"
        case ballBounce = "ball_bounce"
        case netThud = "net_thud"
        case whistle = "whistle"
        case pointChime = "point_chime"
        case matchWin = "match_win"
        case matchLose = "match_lose"
        case serveWhoosh = "serve_whoosh"
        case buttonClick = "button_click"
        case lootReveal = "loot_reveal"
    }

    var isMuted: Bool = false

    private var skActions: [SoundID: SKAction] = [:]
    private var uiPlayers: [SoundID: AVAudioPlayer] = [:]

    private init() {
        preloadAll()
    }

    // SpriteKit: returns cached SKAction (zero-alloc after first call)
    func skAction(for id: SoundID) -> SKAction {
        guard !isMuted else { return SKAction.run {} }
        return skActions[id] ?? SKAction.run {}
    }

    // SwiftUI: plays via pre-warmed AVAudioPlayer
    func playUI(_ id: SoundID) {
        guard !isMuted else { return }
        guard let player = uiPlayers[id] else { return }
        player.currentTime = 0
        player.play()
    }

    private func preloadAll() {
        for id in SoundID.allCases {
            if let url = Bundle.main.url(forResource: id.rawValue, withExtension: "caf") {
                skActions[id] = SKAction.playSoundFileNamed(url.lastPathComponent, waitForCompletion: false)

                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.prepareToPlay()
                    player.volume = volumeFor(id)
                    uiPlayers[id] = player
                }
            }
        }
    }

    private func volumeFor(_ id: SoundID) -> Float {
        switch id {
        case .paddleHit: return 0.6
        case .paddleHitSmash: return 0.8
        case .paddleHitDistant: return 0.3
        case .ballBounce: return 0.5
        case .netThud: return 0.4
        case .whistle: return 0.5
        case .pointChime: return 0.6
        case .matchWin: return 0.7
        case .matchLose: return 0.5
        case .serveWhoosh: return 0.4
        case .buttonClick: return 0.3
        case .lootReveal: return 0.6
        }
    }
}
