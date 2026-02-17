import SwiftUI
import SpriteKit

struct InteractiveMatchView: View {
    @Environment(\.dismiss) private var dismiss

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

    var body: some View {
        ZStack {
            // SpriteKit scene
            if let scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
            } else {
                Color(UIColor(hex: "#2C3E50"))
                    .ignoresSafeArea()
            }

            // Exit button (top right, during active match only)
            if matchResult == nil {
                VStack {
                    HStack {
                        Spacer()
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
                        .padding(.trailing, 12)
                        .padding(.top, 110)
                    }
                    Spacer()
                }
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
            let newScene = makeScene()
            scene = newScene
            // Auto-start the match immediately — instructions were already shown
            newScene.beginMatch()
        }
    }

    private func makeScene() -> InteractiveMatchScene {
        InteractiveMatchScene(
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
    }

    // MARK: - Result Overlay

    private func resultOverlay(result: MatchResult) -> some View {
        VStack(spacing: 16) {
            // Win/Loss banner
            Text(result.didPlayerWin ? "Victory!" : "Defeat")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(result.didPlayerWin ? .green : .red)

            // Score
            Text("\(result.finalScore.playerPoints) — \(result.finalScore.opponentPoints)")
                .font(.system(size: 36, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)

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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
    }
}
