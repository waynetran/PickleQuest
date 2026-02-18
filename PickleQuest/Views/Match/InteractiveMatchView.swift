import SwiftUI
import SpriteKit

struct InteractiveMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let player: Player
    let npc: NPC
    let npcAppearance: CharacterAppearance
    let isRated: Bool
    let wagerAmount: Int
    var contestedDropRarity: EquipmentRarity?
    var contestedDropItemCount: Int = 0
    let onComplete: (MatchResult) -> Void

    @State private var matchResult: MatchResult?
    @State private var scene: InteractiveMatchScene?
    @State private var playerScore: Int = 0
    @State private var npcScore: Int = 0
    @State private var servingSide: MatchSide = .player
    @State private var showControlHint: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // SpriteKit scene
            if let scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
            } else {
                Color(UIColor(hex: "#2C3E50"))
                    .ignoresSafeArea()
            }

            // Scoreboard + exit button (during active match)
            if matchResult == nil {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 8) {
                        BroadcastScoreOverlay(
                            playerName: player.name,
                            opponentName: npc.name,
                            playerScore: playerScore,
                            opponentScore: npcScore,
                            playerGames: 0,
                            opponentGames: 0,
                            servingSide: servingSide,
                            courtName: ""
                        )

                        Button {
                            scene?.resignMatch()
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                    Spacer()
                }
            }

            // First-match control hint overlay
            if showControlHint {
                controlHintOverlay
            }

            // Result overlay (after match ends)
            if let result = matchResult {
                VStack {
                    Spacer()
                    resultOverlay(result: result)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: matchResult != nil)
        .navigationBarBackButtonHidden(true)
        .task {
            guard scene == nil else { return }

            // Show control hint for first non-tutorial match
            if player.matchHistory.isEmpty {
                showControlHint = true
            } else {
                let newScene = makeScene()
                scene = newScene
                newScene.beginMatch()
            }
        }
    }

    private func makeScene() -> InteractiveMatchScene {
        let scene = InteractiveMatchScene(
            player: player,
            npc: npc,
            npcAppearance: npcAppearance,
            isRated: isRated,
            wagerAmount: wagerAmount,
            contestedDropRarity: contestedDropRarity,
            contestedDropItemCount: contestedDropItemCount,
            onComplete: { result in
                matchResult = result
            }
        )
        scene.isDevMode = appState.isDevMode
        scene.onScoreUpdate = { pScore, oScore, server in
            playerScore = pScore
            npcScore = oScore
            servingSide = server
        }
        return scene
    }

    // MARK: - Control Hint

    private var controlHintOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                Text("Quick Controls")
                    .font(.title3.bold())

                VStack(alignment: .leading, spacing: 10) {
                    controlRow(icon: "arrow.up.and.down.and.arrow.left.and.right", label: "Left side", detail: "Joystick to move")
                    controlRow(icon: "hand.draw.fill", label: "Right side", detail: "Swipe up to serve")
                    controlRow(icon: "slider.horizontal.3", label: "Bottom buttons", detail: "Toggle shot modes")
                    controlRow(icon: "bolt.fill", label: "Stamina bar", detail: "Above your player")
                }

                Button {
                    showControlHint = false
                    let newScene = makeScene()
                    scene = newScene
                    newScene.beginMatch()
                } label: {
                    Text("Got it!")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding()
        }
    }

    private func controlRow(icon: String, label: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Result Overlay

    private func resultOverlay(result: MatchResult) -> some View {
        VStack(spacing: 16) {
            // Win/Loss icon + banner (matches MatchResultView style)
            Image(systemName: result.didPlayerWin ? "trophy.fill" : "xmark.circle")
                .font(.system(size: 44))
                .foregroundStyle(result.didPlayerWin ? .yellow : .red)

            Text(result.didPlayerWin ? "Victory!" : "Defeat")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(result.didPlayerWin ? .green : .red)

            // Score
            Text("\(result.finalScore.playerPoints) — \(result.finalScore.opponentPoints)")
                .font(.system(size: 28, weight: .bold).monospacedDigit())
                .foregroundStyle(.primary)

            Divider()

            // Match stats
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(result.playerStats.aces)")
                        .font(.title2.bold().monospacedDigit())
                    Text("Aces")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(result.playerStats.winners)")
                        .font(.title2.bold().monospacedDigit())
                    Text("Winners")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(result.playerStats.unforcedErrors)")
                        .font(.title2.bold().monospacedDigit())
                    Text("Errors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(result.playerStats.longestRally)")
                        .font(.title2.bold().monospacedDigit())
                    Text("Best Rally")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // DUPR change preview
            if let duprChange = result.duprChange {
                let sign = duprChange >= 0 ? "+" : ""
                Label("\(sign)\(String(format: "%.2f", duprChange)) DUPR", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                    .foregroundStyle(duprChange >= 0 ? .green : .red)
            }

            // XP
            Label("+\(result.xpEarned) XP", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(.yellow)

            Divider()

            Button {
                onComplete(result)
                dismiss()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.sheetRadius))
        .padding()
    }
}
