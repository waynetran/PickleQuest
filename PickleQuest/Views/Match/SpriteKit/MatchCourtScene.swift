import SpriteKit

@MainActor
final class MatchCourtScene: SKScene {
    private typealias AC = MatchAnimationConstants
    private typealias Pos = MatchAnimationConstants.Positions

    // Nodes
    private(set) var courtNode: SKNode!
    private(set) var nearPlayer: SKSpriteNode!
    private(set) var farPlayer: SKSpriteNode!
    private(set) var nearPartner: SKSpriteNode?
    private(set) var farPartner: SKSpriteNode?
    private(set) var ball: SKSpriteNode!
    private(set) var ballShadow: SKShapeNode!
    private(set) var announcementLabel: SKLabelNode!

    // Animators
    private(set) var nearAnimator: SpriteSheetAnimator?
    private(set) var farAnimator: SpriteSheetAnimator?
    private(set) var nearPartnerAnimator: SpriteSheetAnimator?
    private(set) var farPartnerAnimator: SpriteSheetAnimator?

    // Ball textures for future animation
    private(set) var ballTextures: [SKTexture] = []

    // Animator
    private var animator: MatchAnimator!

    // Appearances
    private let playerAppearance: CharacterAppearance
    private let opponentAppearance: CharacterAppearance
    private let partnerAppearance: CharacterAppearance?
    private let opponent2Appearance: CharacterAppearance?

    /// Whether this is a doubles match (4 players).
    var isDoubles: Bool { partnerAppearance != nil }

    init(
        size: CGSize,
        playerAppearance: CharacterAppearance = .defaultPlayer,
        opponentAppearance: CharacterAppearance = .defaultOpponent,
        partnerAppearance: CharacterAppearance? = nil,
        opponent2Appearance: CharacterAppearance? = nil
    ) {
        self.playerAppearance = playerAppearance
        self.opponentAppearance = opponentAppearance
        self.partnerAppearance = partnerAppearance
        self.opponent2Appearance = opponent2Appearance
        super.init(size: size)
        backgroundColor = UIColor(hex: "#1A1A2E")
        setupCourt()
        setupPlayers()
        if partnerAppearance != nil {
            setupDoublesPartners()
        }
        setupBall()
        setupAnnouncementLabel()
        animator = MatchAnimator(scene: self)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
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
        let (nearNode, nearTextures) = SpriteFactory.makeCharacterNode(
            appearance: playerAppearance,
            isNearPlayer: true
        )
        nearPlayer = nearNode
        nearPlayer.name = "nearPlayer"
        nearPlayer.setScale(AC.Sprites.nearPlayerScale * CourtRenderer.perspectiveScale(ny: Pos.nearPlayerNY))
        nearPlayer.zPosition = AC.ZPositions.nearPlayer
        let nearPos = CourtRenderer.courtPoint(nx: Pos.playerCenterNX, ny: Pos.nearPlayerNY)
        nearPlayer.position = nearPos
        addChild(nearPlayer)

        nearAnimator = SpriteSheetAnimator(node: nearPlayer, textures: nearTextures, isNear: true)

        // Far player (opponent, top of court, front view)
        let (farNode, farTextures) = SpriteFactory.makeCharacterNode(
            appearance: opponentAppearance,
            isNearPlayer: false
        )
        farPlayer = farNode
        farPlayer.name = "farPlayer"
        let farScale = CourtRenderer.perspectiveScale(ny: Pos.farPlayerNY)
        farPlayer.setScale(AC.Sprites.farPlayerScale * farScale)
        farPlayer.zPosition = AC.ZPositions.farPlayer
        let farPos = CourtRenderer.courtPoint(nx: Pos.playerCenterNX, ny: Pos.farPlayerNY)
        farPlayer.position = farPos
        addChild(farPlayer)

        farAnimator = SpriteSheetAnimator(node: farPlayer, textures: farTextures, isNear: false)

        // Hide players initially — match start animation will bring them in
        nearPlayer.alpha = 0
        farPlayer.alpha = 0
    }

    private func setupDoublesPartners() {
        guard let partnerApp = partnerAppearance,
              let opp2App = opponent2Appearance else { return }

        // Near partner (player's teammate, bottom-right of court)
        let (npNode, npTextures) = SpriteFactory.makeCharacterNode(
            appearance: partnerApp,
            isNearPlayer: true
        )
        nearPartner = npNode
        nearPartner?.name = "nearPartner"
        nearPartner?.setScale(AC.Sprites.nearPlayerScale * CourtRenderer.perspectiveScale(ny: Pos.nearPlayerNY))
        nearPartner?.zPosition = AC.ZPositions.nearPlayer
        let nearPartnerPos = CourtRenderer.courtPoint(nx: Pos.doublesRightNX, ny: Pos.nearPlayerNY)
        nearPartner?.position = nearPartnerPos
        if let np = nearPartner { addChild(np) }
        nearPartnerAnimator = SpriteSheetAnimator(node: npNode, textures: npTextures, isNear: true)

        // Far partner (opponent's teammate, top-right of court)
        let (fpNode, fpTextures) = SpriteFactory.makeCharacterNode(
            appearance: opp2App,
            isNearPlayer: false
        )
        farPartner = fpNode
        farPartner?.name = "farPartner"
        let farScale = CourtRenderer.perspectiveScale(ny: Pos.farPlayerNY)
        farPartner?.setScale(AC.Sprites.farPlayerScale * farScale)
        farPartner?.zPosition = AC.ZPositions.farPlayer
        let farPartnerPos = CourtRenderer.courtPoint(nx: Pos.doublesRightNX, ny: Pos.farPlayerNY)
        farPartner?.position = farPartnerPos
        if let fp = farPartner { addChild(fp) }
        farPartnerAnimator = SpriteSheetAnimator(node: fpNode, textures: fpTextures, isNear: false)

        // Hide doubles partners initially
        nearPartner?.alpha = 0
        farPartner?.alpha = 0

        // Move main players to left positions for doubles
        let nearLeftPos = CourtRenderer.courtPoint(nx: Pos.doublesLeftNX, ny: Pos.nearPlayerNY)
        nearPlayer.position = nearLeftPos
        let farLeftPos = CourtRenderer.courtPoint(nx: Pos.doublesLeftNX, ny: Pos.farPlayerNY)
        farPlayer.position = farLeftPos
    }

    private func setupBall() {
        ballTextures = SpriteFactory.makeBallTextures()
        let firstBallTexture = ballTextures.first ?? SpriteFactory.makeBall()

        ball = SKSpriteNode(texture: firstBallTexture)
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
        let nearScale = AC.Sprites.nearPlayerScale * CourtRenderer.perspectiveScale(ny: Pos.nearPlayerNY)
        let farScale = AC.Sprites.farPlayerScale * CourtRenderer.perspectiveScale(ny: Pos.farPlayerNY)

        if isDoubles {
            // Doubles: side-by-side positions
            nearPlayer.position = CourtRenderer.courtPoint(nx: Pos.doublesLeftNX, ny: Pos.nearPlayerNY)
            farPlayer.position = CourtRenderer.courtPoint(nx: Pos.doublesLeftNX, ny: Pos.farPlayerNY)
            nearPartner?.position = CourtRenderer.courtPoint(nx: Pos.doublesRightNX, ny: Pos.nearPlayerNY)
            farPartner?.position = CourtRenderer.courtPoint(nx: Pos.doublesRightNX, ny: Pos.farPlayerNY)
            nearPartner?.setScale(nearScale)
            farPartner?.setScale(farScale)
        } else {
            nearPlayer.position = CourtRenderer.courtPoint(nx: Pos.playerCenterNX, ny: Pos.nearPlayerNY)
            farPlayer.position = CourtRenderer.courtPoint(nx: Pos.playerCenterNX, ny: Pos.farPlayerNY)
        }

        nearPlayer.setScale(nearScale)
        farPlayer.setScale(farScale)
    }
}
