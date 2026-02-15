import SwiftUI
import SpriteKit

struct MatchSpriteView: View {
    let viewModel: MatchViewModel
    @State private var scene: MatchCourtScene?

    var body: some View {
        ZStack(alignment: .top) {
            if let scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
            }

            // Score overlay
            if let score = viewModel.currentScore {
                ScoreHeaderView(
                    playerScore: score.playerPoints,
                    opponentScore: score.opponentPoints,
                    playerGames: score.playerGames,
                    opponentGames: score.opponentGames,
                    opponentName: viewModel.selectedNPC?.name ?? "Opponent"
                )
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
