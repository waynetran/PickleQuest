import SpriteKit

@MainActor
final class MatchCourtScene: SKScene {
    private typealias AC = MatchAnimationConstants
    private typealias Pos = MatchAnimationConstants.Positions

    // Nodes
    private(set) var courtNode: SKNode!
    private(set) var nearPlayer: SKSpriteNode!
    private(set) var farPlayer: SKSpriteNode!
    private(set) var ball: SKSpriteNode!
    private(set) var ballShadow: SKShapeNode!
    private(set) var announcementLabel: SKLabelNode!

    // Animator
    private var animator: MatchAnimator!

    // Track serving side for animations
    private var lastServingSide: MatchSide = .player

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(hex: "#1A1A2E") // dark bg behind court
        setupCourt()
        setupPlayers()
        setupBall()
        setupAnnouncementLabel()

        animator = MatchAnimator(scene: self)
    }

    // MARK: - Public API

    func animate(event: MatchEvent) async {
        await animator.animate(event: event)
    }

    // MARK: - Setup

    private func setupCourt() {
        courtNode = CourtRenderer.buildCourt()
        addChild(courtNode)
    }

    private func setupPlayers() {
        // Near player (us, bottom of court, back view)
        let nearTexture = SpriteFactory.makeNearPlayer()
        nearPlayer = SKSpriteNode(texture: nearTexture)
        nearPlayer.name = "nearPlayer"
        nearPlayer.setScale(AC.Sprites.nearPlayerScale)
        nearPlayer.zPosition = AC.ZPositions.nearPlayer
        let nearPos = CourtRenderer.courtPoint(nx: Pos.playerCenterNX, ny: Pos.nearPlayerNY)
        nearPlayer.position = nearPos
        addChild(nearPlayer)

        // Far player (opponent, top of court, front view)
        let farTexture = SpriteFactory.makeFarPlayer()
        farPlayer = SKSpriteNode(texture: farTexture)
        farPlayer.name = "farPlayer"
        farPlayer.setScale(AC.Sprites.farPlayerScale)
        farPlayer.zPosition = AC.ZPositions.farPlayer
        let farScale = CourtRenderer.perspectiveScale(ny: Pos.farPlayerNY)
        farPlayer.setScale(AC.Sprites.farPlayerScale * farScale)
        let farPos = CourtRenderer.courtPoint(nx: Pos.playerCenterNX, ny: Pos.farPlayerNY)
        farPlayer.position = farPos
        addChild(farPlayer)

        // Hide players initially — match start animation will bring them in
        nearPlayer.alpha = 0
        farPlayer.alpha = 0
    }

    private func setupBall() {
        let ballTexture = SpriteFactory.makeBall()
        ball = SKSpriteNode(texture: ballTexture)
        ball.name = "ball"
        ball.setScale(AC.Sprites.ballScale)
        ball.zPosition = AC.ZPositions.ball
        ball.alpha = 0
        let center = CourtRenderer.courtPoint(nx: 0.5, ny: 0.5)
        ball.position = center
        addChild(ball)

        // Ball shadow
        ballShadow = SKShapeNode(ellipseOf: CGSize(width: AC.Sprites.ballSize * 0.8, height: AC.Sprites.ballSize * 0.3))
        ballShadow.name = "ballShadow"
        ballShadow.fillColor = UIColor.black.withAlphaComponent(0.3)
        ballShadow.strokeColor = .clear
        ballShadow.zPosition = AC.ZPositions.ballShadow
        ballShadow.alpha = 0
        ballShadow.position = center
        addChild(ballShadow)
    }

    private func setupAnnouncementLabel() {
        announcementLabel = SKLabelNode(fontNamed: AC.Text.fontName)
        announcementLabel.name = "announcement"
        announcementLabel.fontSize = AC.Text.announcementFontSize
        announcementLabel.fontColor = .white
        announcementLabel.zPosition = AC.ZPositions.text
        announcementLabel.alpha = 0
        announcementLabel.position = CGPoint(
            x: AC.sceneWidth / 2,
            y: AC.Court.courtBottomY + AC.Court.courtHeight / 2
        )
        announcementLabel.verticalAlignmentMode = .center
        announcementLabel.horizontalAlignmentMode = .center
        addChild(announcementLabel)
    }

    // MARK: - Convenience for animator

    func showAnnouncement(_ text: String, fontSize: CGFloat? = nil) async {
        announcementLabel.text = text
        if let fontSize {
            announcementLabel.fontSize = fontSize
        } else {
            announcementLabel.fontSize = AC.Text.announcementFontSize
        }
        await announcementLabel.runAsync(
            .sequence([
                .fadeIn(withDuration: AC.Timing.textFadeInDuration),
                .wait(forDuration: AC.Timing.textHoldDuration),
                .fadeOut(withDuration: AC.Timing.textFadeOutDuration)
            ])
        )
    }

    func showCallout(_ text: String, at position: CGPoint, color: UIColor = .white) async {
        let label = SKLabelNode(fontNamed: AC.Text.fontName)
        label.text = text
        label.fontSize = AC.Text.calloutFontSize
        label.fontColor = color
        label.position = position
        label.zPosition = AC.ZPositions.text
        label.alpha = 0
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(label)

        await label.runAsync(
            .sequence([
                .group([
                    .fadeIn(withDuration: 0.15),
                    .moveBy(x: 0, y: 30, duration: 0.6)
                ]),
                .fadeOut(withDuration: 0.2)
            ])
        )
        label.removeFromParent()
    }

    func resetPlayerPositions() {
        let nearPos = CourtRenderer.courtPoint(nx: Pos.playerCenterNX, ny: Pos.nearPlayerNY)
        let farPos = CourtRenderer.courtPoint(nx: Pos.playerCenterNX, ny: Pos.farPlayerNY)
        nearPlayer.position = nearPos
        farPlayer.position = farPos
    }
}
