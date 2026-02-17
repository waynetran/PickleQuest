import SwiftUI
import SpriteKit

struct InteractiveMatchView: View {
    @Environment(\.dismiss) private var dismiss

    let player: Player
    let npc: NPC
    let npcAppearance: CharacterAppearance
    let isRated: Bool
    let wagerAmount: Int
    let onComplete: (MatchResult) -> Void

    @State private var matchResult: MatchResult?
    @State private var showInstructions = true
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

            // Instruction overlay (before match starts)
            if showInstructions {
                VStack {
                    Spacer()
                    instructionOverlay
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Exit button (top right, during active match only)
            if !showInstructions && matchResult == nil {
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
        .animation(.easeInOut(duration: 0.3), value: showInstructions)
        .animation(.easeInOut(duration: 0.3), value: matchResult != nil)
        .navigationBarBackButtonHidden(true)
        .task {
            scene = makeScene()
        }
    }

    private func makeScene() -> InteractiveMatchScene {
        InteractiveMatchScene(
            player: player,
            npc: npc,
            npcAppearance: npcAppearance,
            isRated: isRated,
            wagerAmount: wagerAmount,
            onComplete: { result in
                matchResult = result
            }
        )
    }

    // MARK: - Instruction Overlay

    private var instructionOverlay: some View {
        VStack(spacing: 16) {
            // NPC info
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(npc.name)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("DUPR \(String(format: "%.1f", npc.duprRating))")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    DifficultyBadge(difficulty: npc.difficulty)
                }
                Spacer()
            }

            Divider()

            Text("Interactive Match — Singles to 11")
                .font(.headline)
                .foregroundStyle(.green)

            VStack(spacing: 4) {
                Label("Joystick to move, push further to sprint", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                Label("Buttons to select shot modes", systemImage: "hand.tap")
                Label("Swipe up to serve", systemImage: "hand.draw")
                Label("Side-out scoring, win by 2", systemImage: "sportscourt")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            Button {
                showInstructions = false
                scene?.beginMatch()
            } label: {
                Text("Start Match")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
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
