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
        case footstep = "footstep"
        case footstepSprint = "footstep_sprint"
        case lootReveal = "loot_reveal"
    }

    var isMuted: Bool = false
    private(set) var isReady: Bool = false

    private var uiPlayers: [SoundID: AVAudioPlayer] = [:]

    private init() {
        Task.detached(priority: .userInitiated) {
            // Configure audio session off main thread — avoids stalling init
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                #if DEBUG
                print("[SoundManager] Audio session setup failed: \(error)")
                #endif
            }

            // Preload all sound files off main thread
            var players: [SoundID: AVAudioPlayer] = [:]

            for id in SoundID.allCases {
                if let url = Bundle.main.url(forResource: id.rawValue, withExtension: "caf") {
                    do {
                        let player = try AVAudioPlayer(contentsOf: url)
                        player.prepareToPlay()
                        player.volume = Self.volumeFor(id)
                        players[id] = player
                    } catch {
                        #if DEBUG
                        print("[SoundManager] Failed to create player for \(id.rawValue): \(error)")
                        #endif
                    }
                } else {
                    #if DEBUG
                    print("[SoundManager] Missing sound file: \(id.rawValue).caf")
                    #endif
                }
            }

            #if DEBUG
            print("[SoundManager] Loaded \(players.count)/\(SoundID.allCases.count) sounds")
            #endif

            // Publish results back to main actor
            await MainActor.run {
                self.uiPlayers = players
                self.isReady = true
            }
        }
    }

    // SpriteKit: returns SKAction that plays via pre-warmed AVAudioPlayer
    // (avoids SKAction.playSoundFileNamed which lazily decodes audio on first play)
    func skAction(for id: SoundID) -> SKAction {
        guard !isMuted else { return SKAction.run {} }
        return SKAction.run {
            MainActor.assumeIsolated {
                SoundManager.shared.playUI(id)
            }
        }
    }

    // SwiftUI: plays via pre-warmed AVAudioPlayer
    func playUI(_ id: SoundID) {
        guard !isMuted, let player = uiPlayers[id] else { return }
        player.currentTime = 0
        player.play()
    }

    private nonisolated static func volumeFor(_ id: SoundID) -> Float {
        switch id {
        case .paddleHit: return 0.05
        case .paddleHitSmash: return 0.05
        case .paddleHitDistant: return 0.03
        case .ballBounce: return 0.01
        case .netThud: return 0.4
        case .whistle: return 0.5
        case .pointChime: return 0.6
        case .matchWin: return 0.7
        case .matchLose: return 0.5
        case .serveWhoosh: return 0.05
        case .buttonClick: return 0.3
        case .footstep: return 0.01
        case .footstepSprint: return 0.01
        case .lootReveal: return 0.6
        }
    }
}
