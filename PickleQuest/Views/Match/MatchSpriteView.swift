import SwiftUI
import SpriteKit

struct MatchSpriteView: View {
    let viewModel: MatchViewModel
    @State private var scene: MatchCourtScene?

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
                if let score = viewModel.currentScore {
                    BroadcastScoreOverlay(
                        playerName: viewModel.isDoublesMode ? "Your Team" : "You",
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

                // Scrolling event log with gradient fade
                EventLogOverlay(events: viewModel.eventLog)

                Spacer()
            }

            // Action buttons overlay
            if viewModel.matchState == .simulating {
                MatchActionButtons(viewModel: viewModel)
                    .padding(.top, 60)
            }
        }
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
}

// MARK: - Scrolling Event Log

private struct EventLogOverlay: View {
    let events: [MatchEventEntry]

    // Show only the last few events
    private var recentEvents: [MatchEventEntry] {
        Array(events.suffix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(recentEvents.enumerated()), id: \.element.id) { index, entry in
                Text(entry.narration)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .opacity(entryOpacity(index: index))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    .black.opacity(0.5),
                    .black.opacity(0.3),
                    .clear
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
