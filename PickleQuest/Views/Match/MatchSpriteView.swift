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

            // Broadcast score overlay (top-left, PPA style)
            if let score = viewModel.currentScore {
                BroadcastScoreOverlay(
                    playerName: "You",
                    opponentName: viewModel.selectedNPC?.name ?? "Opponent",
                    playerScore: score.playerPoints,
                    opponentScore: score.opponentPoints,
                    playerGames: score.playerGames,
                    opponentGames: score.opponentGames,
                    servingSide: viewModel.currentServingSide,
                    courtName: viewModel.courtName
                )
                .padding(.leading, 12)
                .padding(.top, 8)
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
                opponentAppearance: viewModel.opponentAppearance
            )
            newScene.scaleMode = .aspectFill
            newScene.anchorPoint = CGPoint(x: 0, y: 0)
            scene = newScene
            viewModel.courtScene = newScene
        }
    }
}
