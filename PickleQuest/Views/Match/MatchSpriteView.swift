import SwiftUI
import SpriteKit

struct MatchSpriteView: View {
    let viewModel: MatchViewModel
    @Environment(AppState.self) private var appState
    @State private var scene: MatchCourtScene?
    @State private var showPreMatchOverlay = true
    @State private var selectedPlayMode: MatchPlayMode = .simulated

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
            }

            VStack(spacing: 0) {
                // Broadcast score overlay (top-left, PPA style)
                if !showPreMatchOverlay, let score = viewModel.currentScore {
                    BroadcastScoreOverlay(
                        playerName: viewModel.isDoublesMode ? "\(viewModel.playerName)'s Team" : viewModel.playerName,
                        opponentName: viewModel.selectedNPC?.name ?? "Opponent",
                        playerScore: score.playerPoints,
                        opponentScore: score.opponentPoints,
                        playerGames: score.playerGames,
                        opponentGames: score.opponentGames,
                        servingSide: viewModel.currentServingSide,
                        courtName: viewModel.courtName,
                        isDoubles: viewModel.isDoublesMode,
                        doublesScoreDisplay: viewModel.doublesScoreDisplay
                    )
                    .padding(.leading, 12)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                // Play-by-play event log at bottom
                if !showPreMatchOverlay {
                    EventLogOverlay(events: viewModel.eventLog)
                }
            }

            // Action buttons overlay
            if !showPreMatchOverlay && viewModel.matchState == .simulating {
                MatchActionButtons(viewModel: viewModel)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                    .padding(.top, 60)

                // Skip button pinned to very bottom right
                if !viewModel.isSkipping {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                Task { await viewModel.skipMatch() }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 16))
                                    Text("Skip")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                                .background(.black.opacity(0.6))
                                .clipShape(Capsule())
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 8)
                        }
                    }
                }
            }

            // Pre-match instruction overlay
            if showPreMatchOverlay {
                VStack {
                    Spacer()
                    preMatchOverlay
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showPreMatchOverlay)
        .task {
            guard scene == nil else { return }
            let newScene = MatchCourtScene(
                size: CGSize(
                    width: MatchAnimationConstants.sceneWidth,
                    height: MatchAnimationConstants.sceneHeight
                ),
                playerAppearance: viewModel.playerAppearance,
                opponentAppearance: viewModel.opponentAppearance,
                partnerAppearance: viewModel.partnerAppearance,
                opponent2Appearance: viewModel.opponent2Appearance
            )
            newScene.scaleMode = .aspectFill
            newScene.anchorPoint = CGPoint(x: 0, y: 0)
            scene = newScene
            viewModel.courtScene = newScene
        }
    }

    // MARK: - Pre-Match Overlay

    private var preMatchOverlay: some View {
        let opponentName = viewModel.selectedNPC?.name ?? "Opponent"
        let matchType = viewModel.isDoublesMode ? "Doubles" : "Singles"

        return VStack(spacing: 16) {
            // Opponent info
            Text("vs \(opponentName)")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.green)

            if let npc = viewModel.selectedNPC {
                HStack(spacing: 8) {
                    Text("DUPR \(String(format: "%.1f", npc.duprRating))")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    DifficultyBadge(difficulty: npc.difficulty)
                    Text(matchType)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Watch / Play mode picker (singles only)
            if !viewModel.isDoublesMode {
                Picker("Match Mode", selection: $selectedPlayMode) {
                    Text("Watch Match").tag(MatchPlayMode.simulated)
                    Text("Play Match").tag(MatchPlayMode.interactive)
                }
                .pickerStyle(.segmented)
            }

            // Mode-specific content
            if selectedPlayMode == .interactive && !viewModel.isDoublesMode {
                interactiveInstructions
            } else {
                simulatedInstructions
            }

            Divider()

            // Start button
            Button {
                if selectedPlayMode == .interactive && !viewModel.isDoublesMode {
                    Task { await viewModel.switchToInteractive(player: appState.player) }
                } else {
                    showPreMatchOverlay = false
                }
            } label: {
                Text(selectedPlayMode == .interactive && !viewModel.isDoublesMode
                     ? "Start Match"
                     : "Let's Play Pickleball!")
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

    // MARK: - Interactive Instructions

    private var interactiveInstructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            actionRow(icon: "arrow.up.and.down.and.arrow.left.and.right",
                      title: "Move",
                      desc: "Joystick to move. Push further to sprint.")
            actionRow(icon: "hand.draw",
                      title: "Serve",
                      desc: "Swipe up to serve. Angle and distance control aim and power.")
            actionRow(icon: "hand.tap",
                      title: "Shot Modes",
                      desc: "Toggle Power, Slice, Topspin, Angled, Reset, or Focus before hitting.")
            actionRow(icon: "bolt.fill",
                      title: "Stamina",
                      desc: "Sprinting and Power/Focus modes drain stamina. Stop moving to recover. Low stamina weakens your shots!")
            actionRow(icon: "sportscourt",
                      title: "Scoring",
                      desc: "Side-out singles to 11, win by 2. Only the server can score.")
        }
    }

    // MARK: - Simulated Instructions

    private var simulatedInstructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            actionRow(icon: "pause.circle", title: "Timeout", desc: "Call a timeout to pause play and regroup")
            actionRow(icon: "sparkles", title: "Item", desc: "Use a consumable item for a temporary boost")
            actionRow(icon: "exclamationmark.triangle", title: "Hook", desc: "Challenge a close line call")
            actionRow(icon: "flag", title: "Resign", desc: "Forfeit the match")
            actionRow(icon: "forward.fill", title: "Skip", desc: "Fast-forward to the end")
        }
    }

    private func actionRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.green)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Scrolling Event Log

private struct EventLogOverlay: View {
    let events: [MatchEventEntry]

    // Show only the last few events
    private var recentEvents: [MatchEventEntry] {
        Array(events.suffix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(recentEvents.enumerated()), id: \.element.id) { index, entry in
                Text(entry.narration)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .opacity(entryOpacity(index: index))
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 120) // leave room for Skip button
        .padding(.top, 6)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.3),
                    .black.opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .animation(.easeOut(duration: 0.2), value: events.count)
    }

    private func entryOpacity(index: Int) -> Double {
        let count = recentEvents.count
        if count <= 1 { return 1.0 }
        // Oldest entry is most faded, newest is full opacity
        let position = Double(index) / Double(count - 1)
        return 0.3 + 0.7 * position
    }
}
