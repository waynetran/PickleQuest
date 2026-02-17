import SpriteKit
import UIKit

@MainActor
final class InteractiveMatchScene: SKScene {
    private typealias AC = MatchAnimationConstants
    private typealias P = GameConstants.DrillPhysics
    private typealias IM = GameConstants.InteractiveMatch

    // MARK: - Sprites

    private var playerNode: SKSpriteNode!
    private var npcNode: SKSpriteNode!
    private var ballNode: SKSpriteNode!
    private var ballShadow: SKShapeNode!
    private var playerAnimator: SpriteSheetAnimator!
    private var npcAnimator: SpriteSheetAnimator!

    // NPC boss bar
    private var npcBossBar: SKNode!
    private var npcNameLabel: SKLabelNode!
    private var npcStaminaBarBg: SKShapeNode!
    private var npcStaminaBarFill: SKShapeNode!

    // Player floating stamina bar
    private var playerStaminaBar: SKNode!
    private var playerStaminaBarBg: SKShapeNode!
    private var playerStaminaBarFill: SKShapeNode!

    // Shot mode dots (floating near player)
    private var shotModeDots: SKNode!
    private var shotModeDotNodes: [SKShapeNode] = []

    // Debug panel for point-over info
    private var debugPanel: SKNode!
    private var debugTextLabel: SKLabelNode!
    private var debugDoneButton: SKLabelNode!

    // Joystick
    private var joystickBase: SKShapeNode!
    private var joystickKnob: SKShapeNode!
    private var joystickTouch: UITouch?
    private var joystickOrigin: CGPoint = .zero
    private var joystickDirection: CGVector = .zero
    private var joystickMagnitude: CGFloat = 0
    private let joystickBaseRadius: CGFloat = 60
    private let joystickKnobRadius: CGFloat = 25

    // Swipe-to-serve state
    private var swipeTouchStart: CGPoint?
    private var swipeHintNode: SKSpriteNode?

    // Shot mode buttons
    private var activeShotModes: DrillShotCalculator.ShotMode = []
    private var shotModeButtons: [SKNode] = []
    private var shotModeBgs: [SKShapeNode] = []
    private var shotModeTouch: UITouch?

    // Stamina
    private var stamina: CGFloat = P.maxStamina
    private var timeSinceLastSprint: CGFloat = 10

    // Score callback (SwiftUI scoreboard replaces SpriteKit HUD)
    var onScoreUpdate: ((Int, Int, MatchSide) -> Void)?
    var isDevMode: Bool = true

    // In-game feedback labels (not part of HUD)
    private var staminaWarningLabel: SKLabelNode!
    private var outcomeLabel: SKLabelNode!

    // First-bounce tracking for kitchen fault / debug
    private var firstBounceCourtX: CGFloat = 0.5
    private var firstBounceCourtY: CGFloat = 0.5
    private var checkedFirstBounce: Bool = false
    private var sceneReady = false

    // MARK: - Game State

    private let ballSim = DrillBallSimulation()
    private var npcAI: MatchAI!
    private let playerStats: PlayerStats

    // Player position in court space
    private var playerNX: CGFloat = 0.5
    private var playerNY: CGFloat = 0.08
    private var playerMoveSpeed: CGFloat = 0.6
    private var lastUpdateTime: TimeInterval = 0
    private var previousBallNY: CGFloat = 0.5

    // Match scoring (side-out singles)
    private var playerScore: Int = 0
    private var npcScore: Int = 0
    private var servingSide: MatchSide = .player
    private var totalPointsPlayed: Int = 0
    private var rallyLength: Int = 0

    // Match stats tracking
    private var playerAces: Int = 0
    private var playerWinners: Int = 0
    private var playerErrors: Int = 0
    private var npcAces: Int = 0
    private var npcWinners: Int = 0
    private var npcErrors: Int = 0
    private var longestRally: Int = 0
    private var playerLongestStreak: Int = 0
    private var playerCurrentStreak: Int = 0
    private var totalRallyShots: Int = 0

    // Phases
    enum Phase {
        case waitingToStart
        case serving
        case playing
        case pointOver
        case matchOver
    }
    private(set) var phase: Phase = .waitingToStart
    private var pointOverTimer: CGFloat = 0
    private var servePauseTimer: CGFloat = 0
    private var matchStartTime: Date?

    // Configuration
    private let player: Player
    private let npc: NPC
    private let npcAppearance: CharacterAppearance
    private let isRated: Bool
    private let wagerAmount: Int
    private let contestedDropRarity: EquipmentRarity?
    private let contestedDropItemCount: Int
    private let onComplete: (MatchResult) -> Void

    // MARK: - Init

    init(
        player: Player,
        npc: NPC,
        npcAppearance: CharacterAppearance,
        isRated: Bool,
        wagerAmount: Int,
        contestedDropRarity: EquipmentRarity? = nil,
        contestedDropItemCount: Int = 0,
        onComplete: @escaping (MatchResult) -> Void
    ) {
        self.player = player
        self.npc = npc
        self.npcAppearance = npcAppearance
        self.isRated = isRated
        self.wagerAmount = wagerAmount
        self.contestedDropRarity = contestedDropRarity
        self.contestedDropItemCount = contestedDropItemCount
        self.onComplete = onComplete
        self.playerStats = player.stats

        super.init(size: CGSize(width: AC.sceneWidth, height: AC.sceneHeight))
        self.scaleMode = .aspectFill
        self.anchorPoint = CGPoint(x: 0, y: 0)
        self.backgroundColor = UIColor(hex: "#2C3E50")

        let speedStat = CGFloat(playerStats.stat(.speed))
        playerMoveSpeed = P.baseMoveSpeed + (speedStat / 99.0) * P.maxMoveSpeedBonus
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private var pendingStart = false

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        buildScene()
        sceneReady = true
        if pendingStart {
            pendingStart = false
            beginMatch()
        }
    }

    // MARK: - Public API

    func beginMatch() {
        guard phase == .waitingToStart else { return }
        // If scene hasn't been mounted yet, defer until didMove
        guard sceneReady else {
            pendingStart = true
            return
        }
        matchStartTime = Date()
        npcBossBar.alpha = 1
        onScoreUpdate?(playerScore, npcScore, servingSide)
        startNextPoint()
    }

    func resignMatch() {
        guard phase != .matchOver else { return }
        endMatch(wasResigned: true)
    }

    // MARK: - Scene Setup

    private func buildScene() {
        // Court
        let court = CourtRenderer.buildCourt()
        addChild(court)

        // Player sprite (near side)
        let (pNode, pTextures) = SpriteFactory.makeCharacterNode(appearance: player.appearance, isNearPlayer: true)
        playerNode = pNode
        playerNode.setScale(AC.Sprites.nearPlayerScale)
        playerNode.zPosition = AC.ZPositions.nearPlayer
        addChild(playerNode)
        playerAnimator = SpriteSheetAnimator(node: playerNode, textures: pTextures, isNear: true)

        // NPC sprite (far side)
        let (nNode, nTextures) = SpriteFactory.makeCharacterNode(appearance: npcAppearance, isNearPlayer: false)
        npcNode = nNode
        let npcNY: CGFloat = 0.92
        let farScale = AC.Sprites.farPlayerScale * CourtRenderer.perspectiveScale(ny: npcNY)
        npcNode.setScale(farScale)
        npcNode.zPosition = AC.ZPositions.farPlayer
        addChild(npcNode)
        npcAnimator = SpriteSheetAnimator(node: npcNode, textures: nTextures, isNear: false)

        // Ball
        let ballTextures = SpriteFactory.makeBallTextures()
        ballNode = SKSpriteNode(texture: ballTextures.first)
        ballNode.setScale(AC.Sprites.ballScale)
        ballNode.zPosition = AC.ZPositions.ball
        ballNode.alpha = 0
        addChild(ballNode)

        // Ball shadow
        ballShadow = SKShapeNode(ellipseOf: CGSize(
            width: AC.Sprites.ballSize * 0.8,
            height: AC.Sprites.ballSize * 0.3
        ))
        ballShadow.fillColor = UIColor.black.withAlphaComponent(0.4)
        ballShadow.strokeColor = .clear
        ballShadow.zPosition = AC.ZPositions.ballShadow
        ballShadow.alpha = 0
        addChild(ballShadow)

        // Joystick
        joystickBase = SKShapeNode(circleOfRadius: joystickBaseRadius)
        joystickBase.fillColor = UIColor(white: 0.15, alpha: 0.5)
        joystickBase.strokeColor = UIColor(white: 0.6, alpha: 0.3)
        joystickBase.lineWidth = 2
        joystickBase.zPosition = 15
        joystickBase.position = joystickDefaultPosition
        joystickBase.alpha = 0.4
        addChild(joystickBase)

        joystickKnob = SKShapeNode(circleOfRadius: joystickKnobRadius)
        joystickKnob.fillColor = UIColor(white: 0.8, alpha: 0.6)
        joystickKnob.strokeColor = UIColor(white: 1.0, alpha: 0.4)
        joystickKnob.lineWidth = 1.5
        joystickKnob.zPosition = 16
        joystickKnob.position = joystickDefaultPosition
        joystickKnob.alpha = 0.4
        addChild(joystickKnob)

        // Shot mode buttons
        buildShotButtons()

        // NPC boss bar
        buildNPCBossBar()

        // Player floating stamina bar
        buildPlayerStaminaBar()

        // Shot mode dots
        buildShotModeDots()

        // Debug panel
        buildDebugPanel()

        // Swipe hint
        buildSwipeHint()

        // In-game feedback labels
        buildFeedbackLabels()

        // Initialize AI
        npcAI = MatchAI(npc: npc)

        // Set positions
        playerNX = 0.5
        playerNY = 0.08
        syncAllPositions()
    }

    private func buildShotButtons() {
        typealias SM = DrillShotCalculator.ShotMode

        let buttonWidth: CGFloat = 70
        let buttonHeight: CGFloat = 36
        let cornerRadius: CGFloat = 10
        let gap: CGFloat = 8
        let buttonX = AC.sceneWidth - 51

        let defs: [(name: String, color: UIColor, mode: SM)] = [
            ("Power", .systemRed, .power),
            ("Reset", .systemTeal, .reset),
            ("Slice", .systemPurple, .slice),
            ("Topspin", .systemGreen, .topspin),
            ("Angled", .systemOrange, .angled),
            ("Focus", .systemYellow, .focus),
        ]

        let totalHeight = CGFloat(defs.count) * buttonHeight + CGFloat(defs.count - 1) * gap
        let startY = 350 - totalHeight / 2 + buttonHeight / 2

        for (i, def) in defs.enumerated() {
            let btn = SKNode()
            let y = startY + CGFloat(i) * (buttonHeight + gap)
            btn.position = CGPoint(x: buttonX, y: y)
            btn.zPosition = 20
            btn.name = "shotMode_\(i)"

            let bg = SKShapeNode(rect: CGRect(
                x: -buttonWidth / 2, y: -buttonHeight / 2,
                width: buttonWidth, height: buttonHeight
            ), cornerRadius: cornerRadius)
            bg.fillColor = def.color.withAlphaComponent(0.35)
            bg.strokeColor = def.color.withAlphaComponent(0.6)
            bg.lineWidth = 1.5
            btn.addChild(bg)

            let label = SKLabelNode(text: def.name)
            label.fontName = "AvenirNext-Bold"
            label.fontSize = def.name.count > 6 ? 12 : 14
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            btn.addChild(label)

            addChild(btn)
            shotModeButtons.append(btn)
            shotModeBgs.append(bg)
        }
    }

    private func buildNPCBossBar() {
        npcBossBar = SKNode()
        npcBossBar.zPosition = AC.ZPositions.text + 1

        let duprText = String(format: "%.1f", npc.duprRating)
        npcNameLabel = SKLabelNode(text: "\(npc.name) DUPR \(duprText)")
        npcNameLabel.fontName = "AvenirNext-Bold"
        npcNameLabel.fontSize = 9
        npcNameLabel.fontColor = .white
        npcNameLabel.verticalAlignmentMode = .bottom
        npcNameLabel.horizontalAlignmentMode = .center
        npcNameLabel.position = CGPoint(x: 0, y: 8)
        npcBossBar.addChild(npcNameLabel)

        let barWidth: CGFloat = 60
        let barHeight: CGFloat = 6
        npcStaminaBarBg = SKShapeNode(rect: CGRect(x: -barWidth / 2, y: 0, width: barWidth, height: barHeight), cornerRadius: 3)
        npcStaminaBarBg.fillColor = UIColor(white: 0.2, alpha: 0.8)
        npcStaminaBarBg.strokeColor = UIColor.black
        npcStaminaBarBg.lineWidth = 1
        npcBossBar.addChild(npcStaminaBarBg)

        npcStaminaBarFill = SKShapeNode(rect: CGRect(x: -barWidth / 2, y: 0, width: barWidth, height: barHeight), cornerRadius: 3)
        npcStaminaBarFill.fillColor = .systemGreen
        npcStaminaBarFill.strokeColor = .clear
        npcStaminaBarFill.zPosition = 1
        npcBossBar.addChild(npcStaminaBarFill)

        addChild(npcBossBar)
    }

    private func buildPlayerStaminaBar() {
        playerStaminaBar = SKNode()
        playerStaminaBar.zPosition = AC.ZPositions.text + 1

        let barWidth: CGFloat = 50
        let barHeight: CGFloat = 5
        playerStaminaBarBg = SKShapeNode(rect: CGRect(x: -barWidth / 2, y: 0, width: barWidth, height: barHeight), cornerRadius: 2.5)
        playerStaminaBarBg.fillColor = UIColor(white: 0.2, alpha: 0.8)
        playerStaminaBarBg.strokeColor = UIColor.black
        playerStaminaBarBg.lineWidth = 1
        playerStaminaBar.addChild(playerStaminaBarBg)

        playerStaminaBarFill = SKShapeNode(rect: CGRect(x: -barWidth / 2, y: 0, width: barWidth, height: barHeight), cornerRadius: 2.5)
        playerStaminaBarFill.fillColor = .systemGreen
        playerStaminaBarFill.strokeColor = .clear
        playerStaminaBarFill.zPosition = 1
        playerStaminaBar.addChild(playerStaminaBarFill)

        addChild(playerStaminaBar)
    }

    private func buildShotModeDots() {
        shotModeDots = SKNode()
        shotModeDots.zPosition = AC.ZPositions.text

        let colors: [UIColor] = [.systemRed, .systemTeal, .systemPurple, .systemGreen, .systemOrange, .systemYellow]
        let dotRadius: CGFloat = 3.5
        let spacing: CGFloat = 11
        let totalWidth = CGFloat(colors.count - 1) * spacing

        for (i, color) in colors.enumerated() {
            let dot = SKShapeNode(circleOfRadius: dotRadius)
            dot.fillColor = color.withAlphaComponent(0.15)
            dot.strokeColor = color.withAlphaComponent(0.3)
            dot.lineWidth = 1
            dot.position = CGPoint(x: CGFloat(i) * spacing - totalWidth / 2, y: 0)
            shotModeDots.addChild(dot)
            shotModeDotNodes.append(dot)
        }

        addChild(shotModeDots)
    }

    private func buildDebugPanel() {
        debugPanel = SKNode()
        debugPanel.zPosition = AC.ZPositions.text + 10
        debugPanel.alpha = 0
        debugPanel.position = CGPoint(x: AC.sceneWidth / 2, y: AC.sceneHeight * 0.35)

        let bg = SKShapeNode(rect: CGRect(x: -150, y: -90, width: 300, height: 180), cornerRadius: 10)
        bg.fillColor = UIColor(white: 0, alpha: 0.88)
        bg.strokeColor = UIColor(white: 1, alpha: 0.25)
        bg.lineWidth = 1
        debugPanel.addChild(bg)

        debugTextLabel = SKLabelNode(text: "")
        debugTextLabel.fontName = "Menlo"
        debugTextLabel.fontSize = 10
        debugTextLabel.fontColor = .white
        debugTextLabel.numberOfLines = 0
        debugTextLabel.preferredMaxLayoutWidth = 280
        debugTextLabel.verticalAlignmentMode = .center
        debugTextLabel.horizontalAlignmentMode = .center
        debugTextLabel.position = CGPoint(x: 0, y: 12)
        debugPanel.addChild(debugTextLabel)

        // Done button
        debugDoneButton = SKLabelNode(text: "[ Done ]")
        debugDoneButton.fontName = "AvenirNext-Bold"
        debugDoneButton.fontSize = 16
        debugDoneButton.fontColor = .systemBlue
        debugDoneButton.verticalAlignmentMode = .center
        debugDoneButton.horizontalAlignmentMode = .center
        debugDoneButton.position = CGPoint(x: 0, y: -72)
        debugPanel.addChild(debugDoneButton)

        addChild(debugPanel)
    }

    private func showDebugPanel(_ text: String) {
        debugTextLabel.text = text
        debugPanel.alpha = 1
    }

    private func hideDebugPanel() {
        debugPanel.alpha = 0
    }

    /// Returns a human-readable zone label for where the first bounce landed.
    private func firstBounceZoneLabel() -> String {
        let ny = firstBounceCourtY
        let nearKitchenMin: CGFloat = 0.318
        let farKitchenMax: CGFloat = 0.682
        if ny < -0.10 || ny > 1.10 || firstBounceCourtX < -0.05 || firstBounceCourtX > 1.05 {
            return "Out"
        } else if ny >= nearKitchenMin && ny < 0.5 {
            return "Kitchen (Near)"
        } else if ny >= 0.5 && ny <= farKitchenMax {
            return "Kitchen (Far)"
        } else {
            return "In"
        }
    }

    // MARK: - Feedback Labels

    private func buildFeedbackLabels() {
        let fontName = AC.Text.fontName

        // Stamina warning (top area, below SwiftUI scoreboard)
        staminaWarningLabel = SKLabelNode(text: "")
        staminaWarningLabel.fontName = fontName
        staminaWarningLabel.fontSize = 9
        staminaWarningLabel.fontColor = .systemYellow
        staminaWarningLabel.horizontalAlignmentMode = .left
        staminaWarningLabel.verticalAlignmentMode = .top
        staminaWarningLabel.position = CGPoint(x: 18, y: AC.sceneHeight - 120)
        staminaWarningLabel.zPosition = AC.ZPositions.text
        staminaWarningLabel.alpha = 0
        addChild(staminaWarningLabel)

        // Outcome label (center of court — "Winner!", "Out!", "Net!")
        outcomeLabel = SKLabelNode(text: "")
        outcomeLabel.fontName = fontName
        outcomeLabel.fontSize = 36
        outcomeLabel.fontColor = .white
        outcomeLabel.position = CGPoint(x: AC.sceneWidth / 2, y: AC.sceneHeight * 0.45)
        outcomeLabel.zPosition = AC.ZPositions.text + 1
        outcomeLabel.alpha = 0
        addChild(outcomeLabel)
    }

    // MARK: - Swipe Hint

    private func buildSwipeHint() {
        let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)
        guard let baseImage = UIImage(systemName: "hand.point.up.left.fill", withConfiguration: config) else { return }
        // Bake white color into pixels (withTintColor alone doesn't work for SpriteKit textures)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: baseImage.size, format: format)
        let whiteImage = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: baseImage.size)
            baseImage.draw(in: rect)
            ctx.cgContext.setBlendMode(.sourceIn)
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fill(rect)
        }
        let texture = SKTexture(image: whiteImage)
        let node = SKSpriteNode(texture: texture)
        node.alpha = 0
        node.zPosition = AC.ZPositions.text + 3
        addChild(node)
        swipeHintNode = node
    }

    private func showSwipeHint() {
        guard let hint = swipeHintNode else { return }
        hint.removeAllActions()

        let playerScreenPos = CourtRenderer.courtPoint(nx: playerNX, ny: max(0, playerNY))
        // Crosscourt direction: if player is on right (nx > 0.5), swipe toward left and vice versa
        let crosscourtDX: CGFloat = playerNX > 0.5 ? -60 : 60
        let startX = playerScreenPos.x
        let startY = playerScreenPos.y + 30
        let endX = startX + crosscourtDX
        let endY = startY + 90

        hint.position = CGPoint(x: startX, y: startY)
        hint.alpha = 0.85
        hint.colorBlendFactor = 0
        hint.color = .white

        let animation = SKAction.repeatForever(.sequence([
            .group([
                .move(to: CGPoint(x: endX, y: endY), duration: 0.6),
                .sequence([
                    .fadeAlpha(to: 0.85, duration: 0.05),
                    .wait(forDuration: 0.2),
                    .fadeAlpha(to: 0.0, duration: 0.35)
                ])
            ]),
            .run { [weak hint, weak self] in
                guard let hint, let self else { return }
                let pos = CourtRenderer.courtPoint(nx: self.playerNX, ny: max(0, self.playerNY))
                let dx: CGFloat = self.playerNX > 0.5 ? -60 : 60
                hint.position = CGPoint(x: pos.x, y: pos.y + 30)
                // Recompute end for next cycle (stored via closure)
                _ = dx  // suppress unused warning
            },
            .wait(forDuration: 0.15)
        ]))
        hint.run(animation, withKey: "swipeHint")
    }

    private func hideSwipeHint() {
        swipeHintNode?.removeAction(forKey: "swipeHint")
        swipeHintNode?.run(.fadeOut(withDuration: 0.2))
    }

    // MARK: - Match Flow

    private func startNextPoint() {
        rallyLength = 0
        ballSim.reset()
        ballNode.alpha = 0
        ballShadow.alpha = 0
        checkedFirstBounce = false
        hideDebugPanel()

        // Recover stamina between points
        stamina = min(P.maxStamina, stamina + 10)
        npcAI.recoverBetweenPoints()

        // Position players for serve
        if servingSide == .player {
            let evenScore = playerScore % 2 == 0
            playerNX = evenScore ? 0.75 : 0.25
            playerNY = 0.08
            npcAI.positionForReceive(playerScore: playerScore)
            phase = .serving
            showSwipeHint()
        } else {
            let evenScore = npcScore % 2 == 0
            npcAI.positionForServe(npcScore: npcScore)
            // Receiver cross-court from server
            let serverRight = evenScore
            playerNX = serverRight ? 0.25 : 0.75
            playerNY = 0.08
            phase = .serving
            servePauseTimer = IM.servePauseDuration
        }

        syncAllPositions()
        onScoreUpdate?(playerScore, npcScore, servingSide)
    }

    private func playerServe(from startPos: CGPoint, to endPos: CGPoint) {
        let dx = endPos.x - startPos.x
        let dy = endPos.y - startPos.y
        let distance = sqrt(dx * dx + dy * dy)

        guard dy > 0, distance >= P.serveSwipeMinDistance else { return }

        hideSwipeHint()

        let swipeAngle = atan2(dx, dy)
        let angleDeviation = max(-P.serveSwipeAngleRange, min(P.serveSwipeAngleRange, swipeAngle))
        let rawPowerFactor = distance / P.serveSwipeMaxPower

        let accuracyStat = CGFloat(playerStats.stat(.accuracy))
        let focusStat = CGFloat(playerStats.stat(.focus))
        let scatterReduction = ((accuracyStat + focusStat) / 2.0) / 99.0
        var scatter = (1.0 - scatterReduction * 0.7) * 0.15
        // Focus mode reduces scatter further
        if activeShotModes.contains(.focus) { scatter *= 0.5 }
        let scatterX = CGFloat.random(in: -scatter...scatter)
        let scatterY = CGFloat.random(in: -scatter...scatter)

        // Target must clear the kitchen line (0.682) — minimum 0.73 with margin
        let baseTargetNY: CGFloat = 0.73 + rawPowerFactor * 0.25
        let targetNX = max(0.15, min(0.85, 0.5 + angleDeviation + scatterX))
        let targetNY = max(0.73, min(1.05, baseTargetNY + scatterY))

        // Power mode boosts serve speed
        let powerMultiplier: CGFloat = activeShotModes.contains(.power) ? 1.2 : 1.0
        let servePower = (0.10 + min(rawPowerFactor, 1.3) * 0.75) * powerMultiplier

        // Physics-based arc: compute exact arc to land at target distance
        let serveDistNY = abs(targetNY - max(0, playerNY))
        let serveArc = DrillShotCalculator.arcToLandAt(
            distanceNY: serveDistNY,
            power: servePower,
            arcMargin: 1.30 // extra margin for cross-court angle
        )

        // Drain stamina for active modes
        if activeShotModes.contains(.power) { stamina = max(0, stamina - P.maxStamina * 0.20) }
        if activeShotModes.contains(.focus) { stamina = max(0, stamina - P.maxStamina * 0.10) }

        phase = .playing
        ballSim.launch(
            from: CGPoint(x: playerNX, y: max(0, playerNY)),
            toward: CGPoint(x: targetNX, y: targetNY),
            power: servePower,
            arc: serveArc,
            spin: angleDeviation * 0.3
        )
        ballSim.lastHitByPlayer = true
        previousBallNY = ballSim.courtY
        ballNode.alpha = 1
        ballShadow.alpha = 1
        playerAnimator.play(.serveSwing)
    }

    private func npcServe() {
        let shot = npcAI.generateServe(npcScore: npcScore)

        // NPC double fault chance — lower consistency/accuracy = more faults
        let consistencyStat = CGFloat(min(99, npc.stats.stat(.consistency) + P.npcStatBoost))
        let accuracyStat = CGFloat(min(99, npc.stats.stat(.accuracy) + P.npcStatBoost))
        let serveStat = (consistencyStat + accuracyStat) / 2.0
        let faultRate = P.npcBaseServeFaultRate * (1.0 - serveStat / 99.0)
        let isDoubleFault = CGFloat.random(in: 0...1) < faultRate

        // Target must clear the kitchen line (0.318) — land in service area
        let evenScore = npcScore % 2 == 0
        let targetNX: CGFloat = evenScore ? 0.25 : 0.75
        let targetNY: CGFloat

        if isDoubleFault {
            // Fault: aim into kitchen or net
            targetNY = CGFloat.random(in: 0.35...0.48)
        } else {
            targetNY = CGFloat.random(in: 0.05...0.28)
        }

        // Compute physics-based arc for the actual serve distance (NPC at ~0.92 → target ~0.15)
        let serveDistNY = abs(npcAI.currentNY - targetNY)
        let serveArc = DrillShotCalculator.arcToLandAt(
            distanceNY: serveDistNY,
            power: shot.power,
            arcMargin: 1.30 // extra margin for cross-court angle
        )

        phase = .playing
        ballSim.launch(
            from: CGPoint(x: npcAI.currentNX, y: npcAI.currentNY),
            toward: CGPoint(x: targetNX, y: targetNY),
            power: shot.power,
            arc: serveArc,
            spin: shot.spinCurve
        )
        ballSim.lastHitByPlayer = false
        previousBallNY = ballSim.courtY
        ballNode.alpha = 1
        ballShadow.alpha = 1
        npcAnimator.play(.serveSwing)
    }

    // MARK: - Point Resolution

    private enum PointResult {
        case playerWon
        case npcWon
    }

    private func resolvePoint(_ result: PointResult, reason: String) {
        // Capture ball state before reset for debug
        let ballX = String(format: "%.2f", ballSim.courtX)
        let ballY = String(format: "%.2f", ballSim.courtY)
        let ballH = String(format: "%.3f", ballSim.height)
        let ballVY = String(format: "%.2f", ballSim.vy)
        let bounces = ballSim.bounceCount
        let hitByPlayer = ballSim.lastHitByPlayer
        let activeT = String(format: "%.1f", ballSim.activeTime)

        ballSim.reset()
        ballNode.alpha = 0
        ballShadow.alpha = 0
        totalPointsPlayed += 1

        // Update rally stats
        if rallyLength > longestRally { longestRally = rallyLength }
        totalRallyShots += rallyLength

        let prevServer = servingSide

        switch result {
        case .playerWon:
            if servingSide == .player {
                playerScore += 1
            } else {
                servingSide = .player
            }
            playerCurrentStreak += 1
            if playerCurrentStreak > playerLongestStreak {
                playerLongestStreak = playerCurrentStreak
            }
        case .npcWon:
            if servingSide == .opponent {
                npcScore += 1
            } else {
                servingSide = .opponent
            }
            playerCurrentStreak = 0
        }

        onScoreUpdate?(playerScore, npcScore, servingSide)

        // Show debug panel (dev mode only)
        if isDevMode {
            let whoWon = result == .playerWon ? "YOU WON" : "NPC WON"
            let serverStr = prevServer == .player ? "You" : npc.name
            let sideOut = prevServer != servingSide ? " → SIDE OUT" : ""
            let bounceZone = firstBounceZoneLabel()
            let debugText = """
            Pt #\(totalPointsPlayed): \(whoWon)
            Reason: \(reason)
            Rally: \(rallyLength) shots
            Ball: (\(ballX), \(ballY)) h=\(ballH) vy=\(ballVY)
            Bounces: \(bounces) LastHit: \(hitByPlayer ? "Player" : "NPC")
            1st Bounce: \(bounceZone)
            ActiveTime: \(activeT)s
            Server: \(serverStr)\(sideOut)
            Score: You \(playerScore) — \(npcScore) \(npc.name)
            """
            showDebugPanel(debugText)
        }

        // Check for match end
        if isMatchOver() {
            endMatch(wasResigned: false)
            return
        }

        phase = .pointOver
        pointOverTimer = isDevMode ? 30.0 : 1.5 // dev mode waits for Done button
    }

    private func isMatchOver() -> Bool {
        let ptsToWin = IM.pointsToWin
        let margin = IM.winByMargin

        if playerScore >= ptsToWin && playerScore - npcScore >= margin { return true }
        if npcScore >= ptsToWin && npcScore - playerScore >= margin { return true }

        // Sudden death at max score
        if playerScore >= IM.maxScore && npcScore >= IM.maxScore {
            return playerScore != npcScore
        }

        return false
    }

    // MARK: - Match End

    private func endMatch(wasResigned: Bool) {
        phase = .matchOver
        resetJoystick()
        ballSim.reset()
        ballNode.alpha = 0
        ballShadow.alpha = 0

        let didPlayerWin: Bool
        if wasResigned {
            didPlayerWin = false
        } else {
            didPlayerWin = playerScore > npcScore
        }

        let duration = matchStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let averageRally = totalPointsPlayed > 0 ? Double(totalRallyShots) / Double(totalPointsPlayed) : 0

        let finalScore = MatchScore(
            playerPoints: playerScore,
            opponentPoints: npcScore,
            playerGames: didPlayerWin ? 1 : 0,
            opponentGames: didPlayerWin ? 0 : 1
        )

        // Generate loot — contested drops use drop rarity for guaranteed items
        let loot: [Equipment]
        let lootGen = LootGenerator()
        if didPlayerWin, let dropRarity = contestedDropRarity, contestedDropItemCount > 0 {
            loot = (0..<contestedDropItemCount).map { _ in
                lootGen.generateEquipment(rarity: dropRarity)
            }
        } else {
            let suprGap = npc.duprRating - player.duprRating
            loot = lootGen.generateMatchLoot(
                didWin: didPlayerWin,
                opponentDifficulty: npc.difficulty,
                playerLevel: player.progression.level,
                suprGap: suprGap
            )
        }

        // Calculate XP
        var xp = IM.baseXP
        if didPlayerWin { xp += IM.winXPBonus }
        xp = Int(Double(xp) * IM.interactiveXPMultiplier)

        // Calculate coins
        let coins = didPlayerWin ? wagerAmount : -wagerAmount

        // DUPR change
        let duprChange: Double?
        if isRated && !wasResigned {
            duprChange = DUPRCalculator.calculateRatingChange(
                playerRating: player.duprRating,
                opponentRating: npc.duprRating,
                playerPoints: playerScore,
                opponentPoints: npcScore,
                pointsToWin: IM.pointsToWin,
                kFactor: player.duprProfile.kFactor
            )
        } else {
            duprChange = nil
        }

        let result = MatchResult(
            didPlayerWin: didPlayerWin,
            finalScore: finalScore,
            gameScores: [finalScore],
            totalPoints: totalPointsPlayed,
            playerStats: MatchPlayerStats(
                aces: playerAces,
                winners: playerWinners,
                unforcedErrors: playerErrors,
                forcedErrors: 0,
                longestRally: longestRally,
                averageRallyLength: averageRally,
                longestStreak: playerLongestStreak,
                finalEnergy: Double(stamina)
            ),
            opponentStats: MatchPlayerStats(
                aces: npcAces,
                winners: npcWinners,
                unforcedErrors: npcErrors,
                forcedErrors: 0,
                longestRally: longestRally,
                averageRallyLength: averageRally,
                longestStreak: 0,
                finalEnergy: Double(npcAI.stamina)
            ),
            xpEarned: xp,
            coinsEarned: coins,
            loot: loot,
            duration: duration,
            wasResigned: wasResigned,
            duprChange: duprChange,
            partnerName: nil,
            opponent2Name: nil,
            teamSynergy: nil,
            isDoubles: false
        )

        onComplete(result)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pos = touch.location(in: self)

            // Debug panel Done button (during pointOver)
            if phase == .pointOver && isDevMode, let doneBtn = debugDoneButton {
                let local = convert(pos, to: doneBtn.parent ?? debugPanel)
                let hitRect = CGRect(x: doneBtn.position.x - 50, y: doneBtn.position.y - 15,
                                     width: 100, height: 30)
                if hitRect.contains(local) {
                    hideDebugPanel()
                    pointOverTimer = 0 // advance immediately
                    continue
                }
            }

            guard phase == .playing || phase == .serving else { continue }

            // Check shot mode buttons first (works during serve too)
            var hitButton = false
            for (i, btn) in shotModeButtons.enumerated() {
                if hitTestButton(btn, at: pos) {
                    shotModeTouch = touch
                    toggleShotMode(at: i)
                    hitButton = true
                    break
                }
            }
            if hitButton { continue }

            // Swipe to serve (player serving)
            if phase == .serving && servingSide == .player {
                swipeTouchStart = pos
                return
            }

            // Joystick
            guard joystickTouch == nil else { continue }
            joystickTouch = touch
            joystickOrigin = pos
            joystickBase.position = pos
            joystickKnob.position = pos
            joystickBase.alpha = 1
            joystickKnob.alpha = 1
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch = joystickTouch, touches.contains(activeTouch) else { return }

        let pos = activeTouch.location(in: self)
        let dx = pos.x - joystickOrigin.x
        let dy = pos.y - joystickOrigin.y
        let dist = sqrt(dx * dx + dy * dy)

        let maxVisualDist = joystickBaseRadius * 1.5
        if dist <= maxVisualDist {
            joystickKnob.position = pos
        } else {
            joystickKnob.position = CGPoint(
                x: joystickOrigin.x + (dx / dist) * maxVisualDist,
                y: joystickOrigin.y + (dy / dist) * maxVisualDist
            )
        }

        joystickMagnitude = min(dist / joystickBaseRadius, 1.5)
        if dist > 1.0 {
            joystickDirection = CGVector(dx: dx / dist, dy: dy / dist)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if phase == .serving && servingSide == .player, let startPos = swipeTouchStart {
                let endPos = touch.location(in: self)
                playerServe(from: startPos, to: endPos)
                swipeTouchStart = nil
                return
            }

            if touch === shotModeTouch {
                shotModeTouch = nil
                continue
            }
            if touch === joystickTouch {
                resetJoystick()
                continue
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        swipeTouchStart = nil
        for touch in touches {
            if touch === shotModeTouch { shotModeTouch = nil }
            if touch === joystickTouch { resetJoystick() }
        }
    }

    private let joystickDefaultPosition = CGPoint(x: MatchAnimationConstants.sceneWidth / 2, y: 100)

    private func resetJoystick() {
        joystickTouch = nil
        joystickDirection = .zero
        joystickMagnitude = 0
        joystickBase.position = joystickDefaultPosition
        joystickKnob.position = joystickDefaultPosition
        joystickBase.alpha = 0.4
        joystickKnob.alpha = 0.4
    }

    // MARK: - Shot Mode Toggles

    private func toggleShotMode(at index: Int) {
        typealias SM = DrillShotCalculator.ShotMode
        let modes: [SM] = [.power, .reset, .slice, .topspin, .angled, .focus]
        guard index < modes.count else { return }

        let mode = modes[index]
        if activeShotModes.contains(mode) {
            activeShotModes.remove(mode)
        } else {
            if mode == .power { activeShotModes.remove(.reset) }
            else if mode == .reset { activeShotModes.remove(.power) }
            else if mode == .topspin { activeShotModes.remove(.slice) }
            else if mode == .slice { activeShotModes.remove(.topspin) }
            activeShotModes.insert(mode)
        }
        updateShotButtonVisuals()
        updateShotModeDots()
    }

    private func updateShotModeDots() {
        typealias SM = DrillShotCalculator.ShotMode
        let modes: [SM] = [.power, .reset, .slice, .topspin, .angled, .focus]
        let colors: [UIColor] = [.systemRed, .systemTeal, .systemPurple, .systemGreen, .systemOrange, .systemYellow]

        for (i, dot) in shotModeDotNodes.enumerated() {
            guard i < modes.count else { break }
            let isActive = activeShotModes.contains(modes[i])
            dot.fillColor = colors[i].withAlphaComponent(isActive ? 0.9 : 0.15)
            dot.strokeColor = colors[i].withAlphaComponent(isActive ? 1.0 : 0.3)
            dot.lineWidth = isActive ? 2.0 : 1.0
        }
    }

    private func updateShotButtonVisuals() {
        typealias SM = DrillShotCalculator.ShotMode
        let modes: [SM] = [.power, .reset, .slice, .topspin, .angled, .focus]
        let colors: [UIColor] = [.systemRed, .systemTeal, .systemPurple, .systemGreen, .systemOrange, .systemYellow]

        for (i, bg) in shotModeBgs.enumerated() {
            guard i < modes.count else { break }
            let isActive = activeShotModes.contains(modes[i])
            bg.fillColor = colors[i].withAlphaComponent(isActive ? 0.85 : 0.35)
            bg.strokeColor = colors[i].withAlphaComponent(isActive ? 1.0 : 0.6)
            bg.lineWidth = isActive ? 3.0 : 1.5
        }
    }

    private func hitTestButton(_ node: SKNode?, at pos: CGPoint, size: CGSize = CGSize(width: 70, height: 36)) -> Bool {
        guard let node else { return false }
        let local = convert(pos, to: node)
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        return rect.contains(local)
    }

    // MARK: - Main Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard phase == .playing || phase == .serving || phase == .pointOver else { return }

        let dt: CGFloat
        if lastUpdateTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(CGFloat(currentTime - lastUpdateTime), 1.0 / 30.0)
        }
        lastUpdateTime = currentTime

        switch phase {
        case .playing:
            movePlayer(dt: dt)
            let prevBounces = ballSim.bounceCount
            previousBallNY = ballSim.courtY
            ballSim.update(dt: dt)
            // Record first bounce position for kitchen check / debug
            if ballSim.bounceCount >= 1 && prevBounces == 0 {
                firstBounceCourtX = ballSim.courtX
                firstBounceCourtY = ballSim.courtY
            }
            npcAI.update(dt: dt, ball: ballSim)
            checkPlayerHit()
            checkNPCHit()
            checkBallState()
            syncAllPositions()
            updatePlayerStaminaBar()
            updateNPCBossBar()

        case .serving:
            movePlayer(dt: dt)
            syncAllPositions()
            updatePlayerStaminaBar()
            updateNPCBossBar()
            // NPC auto-serve after pause
            if servingSide == .opponent {
                servePauseTimer -= dt
                if servePauseTimer <= 0 {
                    npcServe()
                }
            }

        case .pointOver:
            pointOverTimer -= dt
            syncAllPositions()
            if pointOverTimer <= 0 {
                startNextPoint()
            }

        default:
            break
        }
    }

    // MARK: - Player Movement

    private func movePlayer(dt: CGFloat) {
        guard joystickMagnitude > 0.1 else {
            playerAnimator.play(.ready)
            timeSinceLastSprint += dt
            if timeSinceLastSprint >= P.staminaRecoveryDelay {
                stamina = min(P.maxStamina, stamina + P.staminaRecoveryRate * dt)
            }
            return
        }

        let normalMag = min(joystickMagnitude, 1.0)
        var speed = playerMoveSpeed * normalMag

        let staminaPct = stamina / P.maxStamina
        let canSprint = joystickMagnitude > 1.0 && staminaPct > 0.10
        let isSprinting = canSprint
        if isSprinting {
            let sprintFraction = min((joystickMagnitude - 1.0) / 0.5, 1.0)
            var sprintBonus = sprintFraction * P.maxSprintSpeedBoost * playerMoveSpeed
            if staminaPct < 0.50 { sprintBonus *= 0.5 }
            speed += sprintBonus
            stamina = max(0, stamina - P.sprintDrainRate * dt)
            timeSinceLastSprint = 0
        } else {
            timeSinceLastSprint += dt
            if timeSinceLastSprint >= P.staminaRecoveryDelay {
                stamina = min(P.maxStamina, stamina + P.staminaRecoveryRate * dt)
            }
        }

        if activeShotModes.contains(.focus) {
            stamina = max(0, stamina - P.sprintDrainRate * 0.1 * dt)
        }

        // Joystick sprint visual
        if isSprinting {
            joystickBase.strokeColor = UIColor.systemRed.withAlphaComponent(0.8)
            joystickBase.fillColor = UIColor.systemRed.withAlphaComponent(0.2)
            joystickKnob.fillColor = UIColor.systemRed.withAlphaComponent(0.7)
        } else if joystickTouch != nil {
            joystickBase.strokeColor = UIColor(white: 0.6, alpha: 0.3)
            joystickBase.fillColor = UIColor(white: 0.15, alpha: 0.5)
            joystickKnob.fillColor = UIColor(white: 0.8, alpha: 0.6)
        }

        playerNX += joystickDirection.dx * speed * dt
        playerNY += joystickDirection.dy * speed * dt

        // Clamp: player can move anywhere on their side + up to kitchen line
        playerNX = max(0.0, min(1.0, playerNX))
        playerNY = max(-0.05, min(0.48 - P.playerPositioningOffset, playerNY))

        let dx = joystickDirection.dx
        let dy = joystickDirection.dy
        if abs(dx) > abs(dy) {
            playerAnimator.play(dx > 0 ? .walkRight : .walkLeft)
        } else {
            playerAnimator.play(dy > 0 ? .walkAway : .walkToward)
        }
    }

    // MARK: - Hit Detection

    private func checkPlayerHit() {
        guard ballSim.isActive && !ballSim.lastHitByPlayer else { return }
        guard ballSim.bounceCount < 2 else { return }
        guard ballSim.height < 0.20 else { return }

        let positioningStat = CGFloat(playerStats.stat(.positioning))
        let hitboxRadius = P.baseHitboxRadius + (positioningStat / 99.0) * P.positioningHitboxBonus

        let dx = ballSim.courtX - playerNX
        let dy = ballSim.courtY - playerNY
        let dist = sqrt(dx * dx + dy * dy)
        guard dist <= hitboxRadius else { return }

        // Two-bounce rule: return of serve AND server's 3rd shot must be off the bounce
        if rallyLength < 2 && ballSim.bounceCount == 0 {
            playerErrors += 1
            showIndicator("Volley Fault!", color: .systemRed)
            resolvePoint(.npcWon, reason: "Volley fault (two-bounce rule, rally=\(rallyLength))")
            return
        }

        rallyLength += 1

        // Power mode stamina drain
        if activeShotModes.contains(.power) {
            stamina = max(0, stamina - P.maxStamina * 0.20)
        }

        let ballFromLeft = ballSim.courtX < playerNX
        let staminaPct = stamina / P.maxStamina
        let shot = DrillShotCalculator.calculatePlayerShot(
            stats: playerStats,
            ballApproachFromLeft: ballFromLeft,
            drillType: .baselineRally,
            ballHeight: ballSim.height,
            courtNY: playerNY,
            modes: activeShotModes,
            staminaFraction: staminaPct
        )

        let animState: CharacterAnimationState = shot.shotType == .forehand ? .forehand : .backhand
        playerAnimator.play(animState)

        ballSim.launch(
            from: CGPoint(x: playerNX, y: playerNY),
            toward: CGPoint(x: shot.targetNX, y: shot.targetNY),
            power: shot.power,
            arc: shot.arc,
            spin: shot.spinCurve,
            topspin: shot.topspinFactor
        )
        ballSim.lastHitByPlayer = true
        previousBallNY = ballSim.courtY
    }

    private func checkNPCHit() {
        guard ballSim.isActive && ballSim.lastHitByPlayer else { return }
        guard ballSim.bounceCount < 2 else { return }
        guard ballSim.height < 0.20 else { return }

        // Two-bounce rule: NPC must let the ball bounce on return and 3rd shot
        if rallyLength < 2 && ballSim.bounceCount == 0 { return }

        if npcAI.shouldSwing(ball: ballSim) {
            // Check for unforced error before generating the return
            if npcAI.shouldMakeError(ball: ballSim) {
                npcErrors += 1
                rallyLength += 1
                // Animate the whiff
                let ballFromLeft = ballSim.courtX < npcAI.currentNX
                npcAnimator.play(ballFromLeft ? .backhand : .forehand)

                // Error type: 50% net, 50% out
                if Bool.random() {
                    // Hit into net — launch low and into the net
                    ballSim.launch(
                        from: CGPoint(x: npcAI.currentNX, y: npcAI.currentNY),
                        toward: CGPoint(x: CGFloat.random(in: 0.2...0.8), y: 0.3),
                        power: 0.25,
                        arc: 0.02,
                        spin: 0
                    )
                } else {
                    // Hit long/wide — launch hard and out of bounds
                    let wideTarget = Bool.random() ? CGFloat.random(in: -0.2...0.05) : CGFloat.random(in: 0.95...1.2)
                    ballSim.launch(
                        from: CGPoint(x: npcAI.currentNX, y: npcAI.currentNY),
                        toward: CGPoint(x: wideTarget, y: CGFloat.random(in: 0.0...0.15)),
                        power: 0.8,
                        arc: 0.15,
                        spin: 0
                    )
                }
                ballSim.lastHitByPlayer = false
                previousBallNY = ballSim.courtY
                return
            }

            rallyLength += 1
            let shot = npcAI.generateShot(ball: ballSim)

            let animState: CharacterAnimationState = shot.shotType == .forehand ? .forehand : .backhand
            npcAnimator.play(animState)

            ballSim.launch(
                from: CGPoint(x: npcAI.currentNX, y: npcAI.currentNY),
                toward: CGPoint(x: shot.targetNX, y: shot.targetNY),
                power: shot.power,
                arc: shot.arc,
                spin: shot.spinCurve,
                topspin: shot.topspinFactor
            )
            ballSim.lastHitByPlayer = false
            previousBallNY = ballSim.courtY
        }
    }

    // MARK: - Ball State

    private func checkBallState() {
        guard ballSim.isActive else { return }

        // Net collision
        if ballSim.checkNetCollision(previousY: previousBallNY) {
            let lastHitter: PointResult = ballSim.lastHitByPlayer ? .npcWon : .playerWon
            if ballSim.lastHitByPlayer {
                playerErrors += 1
            } else {
                npcErrors += 1
            }
            let h = String(format: "%.3f", ballSim.height)
            showIndicator("Net!", color: .systemRed)
            resolvePoint(lastHitter, reason: "Net collision (h=\(h), prevY=\(String(format: "%.2f", previousBallNY)))")
            return
        }

        // Serve kitchen fault (checked once on first bounce)
        if ballSim.bounceCount >= 1 && !checkedFirstBounce {
            checkedFirstBounce = true
            if rallyLength == 0 {
                // It's a serve — must land past kitchen line on receiver's side
                let kitchenNear: CGFloat = 0.318  // near kitchen line
                let kitchenFar: CGFloat = 0.682   // far kitchen line
                if ballSim.lastHitByPlayer && firstBounceCourtY >= 0.5 && firstBounceCourtY < kitchenFar {
                    // Player serve landed in NPC's kitchen
                    playerErrors += 1
                    showIndicator("Kitchen Fault!", color: .systemRed)
                    resolvePoint(.npcWon, reason: "Serve in kitchen (y=\(String(format: "%.2f", firstBounceCourtY)))")
                    return
                }
                if !ballSim.lastHitByPlayer && firstBounceCourtY <= 0.5 && firstBounceCourtY > kitchenNear {
                    // NPC serve landed in player's kitchen
                    npcErrors += 1
                    showIndicator("Kitchen Fault!", color: .systemRed)
                    resolvePoint(.playerWon, reason: "NPC serve in kitchen (y=\(String(format: "%.2f", firstBounceCourtY)))")
                    return
                }
            }
        }

        // Double bounce
        if ballSim.isDoubleBounce {
            let side = ballSim.courtY < 0.5 ? "player" : "NPC"
            if ballSim.courtY < 0.5 {
                // Ball double-bounced on player's side
                if ballSim.lastHitByPlayer {
                    // Player hit it but it landed on their own side — error
                    playerErrors += 1
                    showIndicator("Out!", color: .systemOrange)
                } else {
                    // NPC's shot landed and player didn't reach it — miss
                    if rallyLength <= 1 { npcAces += 1 } else { npcWinners += 1 }
                    showIndicator("Miss!", color: .systemYellow)
                }
                resolvePoint(.npcWon, reason: "Double bounce on \(side) side")
            } else {
                // Ball double-bounced on NPC's side
                if ballSim.lastHitByPlayer {
                    // Player's shot landed and NPC didn't reach it — winner
                    if rallyLength <= 1 { playerAces += 1 } else { playerWinners += 1 }
                    showIndicator("Winner!", color: .systemGreen)
                } else {
                    // NPC hit it but it landed on their own side — error
                    npcErrors += 1
                    showIndicator("Out!", color: .systemOrange)
                }
                resolvePoint(.playerWon, reason: "Double bounce on \(side) side")
            }
            return
        }

        // Out of bounds
        if ballSim.isOutOfBounds {
            let lastHitter: PointResult = ballSim.lastHitByPlayer ? .npcWon : .playerWon
            if ballSim.lastHitByPlayer {
                playerErrors += 1
            } else {
                npcErrors += 1
            }
            showIndicator("Out!", color: .systemOrange)
            resolvePoint(lastHitter, reason: "Out of bounds (x=\(String(format: "%.2f", ballSim.courtX)), y=\(String(format: "%.2f", ballSim.courtY)))")
            return
        }

        // Stalled
        if ballSim.isStalled {
            let lastHitter: PointResult = ballSim.lastHitByPlayer ? .npcWon : .playerWon
            if ballSim.lastHitByPlayer {
                playerErrors += 1
            } else {
                npcErrors += 1
            }
            let speed = sqrt(ballSim.vx * ballSim.vx + ballSim.vy * ballSim.vy)
            resolvePoint(lastHitter, reason: "Stalled (t=\(String(format: "%.1f", ballSim.activeTime))s spd=\(String(format: "%.3f", speed)))")
            return
        }
    }

    // MARK: - Position Syncing

    private func syncPlayerPosition() {
        let screenPos = CourtRenderer.courtPoint(nx: playerNX, ny: max(0, playerNY))
        playerNode.position = screenPos

        let pScale = CourtRenderer.perspectiveScale(ny: max(0, min(1, playerNY)))
        playerNode.setScale(AC.Sprites.nearPlayerScale * pScale)
        playerNode.zPosition = AC.ZPositions.nearPlayer - CGFloat(playerNY) * 0.1

        // Stamina tint
        let staminaPct = stamina / P.maxStamina
        let isSprinting = joystickMagnitude > 1.0 && stamina > 0
        if isSprinting || staminaPct < 1.0 {
            let redAmount = 1.0 - staminaPct
            let tint = UIColor(red: 1.0, green: 1.0 - redAmount * 0.6, blue: 1.0 - redAmount * 0.7, alpha: 1.0)
            playerNode.color = tint
            playerNode.colorBlendFactor = redAmount * 0.5
        } else {
            playerNode.colorBlendFactor = 0
        }
    }

    private func syncNPCPosition() {
        let screenPos = CourtRenderer.courtPoint(nx: npcAI.currentNX, ny: npcAI.currentNY)
        npcNode.position = screenPos

        let pScale = CourtRenderer.perspectiveScale(ny: npcAI.currentNY)
        npcNode.setScale(AC.Sprites.farPlayerScale * pScale)
        npcNode.zPosition = AC.ZPositions.farPlayer - CGFloat(npcAI.currentNY) * 0.1
    }

    private func syncBallPosition() {
        guard ballSim.isActive else { return }

        let ballScreenPos = ballSim.screenPosition()
        ballNode.position = ballScreenPos

        let clampedNY = max(CGFloat(0), min(1, ballSim.courtY))
        let pScale = CourtRenderer.perspectiveScale(ny: clampedNY)
        ballNode.setScale(AC.Sprites.ballScale * pScale)

        let shadowPos = ballSim.shadowScreenPosition()
        ballShadow.position = shadowPos

        let shadowScale = max(0.3, 1.0 - ballSim.height * 2.0) * pScale
        ballShadow.setScale(shadowScale)

        ballNode.zPosition = AC.ZPositions.ball - CGFloat(ballSim.courtY) * 0.1
    }

    private func syncAllPositions() {
        syncPlayerPosition()
        syncNPCPosition()
        syncBallPosition()
    }

    private func updatePlayerStaminaBar() {
        // Position above player sprite
        let screenPos = CourtRenderer.courtPoint(nx: playerNX, ny: max(0, playerNY))
        let pScale = CourtRenderer.perspectiveScale(ny: max(0, min(1, playerNY)))
        playerStaminaBar.position = CGPoint(x: screenPos.x, y: screenPos.y + 30 * pScale + 15)

        // Update fill
        let pct = stamina / P.maxStamina
        let barWidth: CGFloat = 50
        let barHeight: CGFloat = 5
        let w = max(1, barWidth * pct)
        playerStaminaBarFill.path = UIBezierPath(
            roundedRect: CGRect(x: -barWidth / 2, y: 0, width: w, height: barHeight),
            cornerRadius: 2.5
        ).cgPath

        if pct > 0.5 {
            playerStaminaBarFill.fillColor = .systemGreen
        } else if pct > 0.10 {
            playerStaminaBarFill.fillColor = .systemYellow
        } else {
            playerStaminaBarFill.fillColor = .systemRed
        }

        let time = CACurrentMediaTime()
        if pct <= 0.10 {
            let flash = 0.4 + 0.6 * abs(sin(time * 8))
            playerStaminaBarFill.alpha = CGFloat(flash)
            playerStaminaBarBg.alpha = CGFloat(flash)
        } else if pct <= 0.50 {
            let flash = 0.6 + 0.4 * abs(sin(time * 3))
            playerStaminaBarFill.alpha = CGFloat(flash)
            playerStaminaBarBg.alpha = 1.0
        } else {
            playerStaminaBarFill.alpha = 1.0
            playerStaminaBarBg.alpha = 1.0
        }

        // Stamina warning text
        if pct <= 0.10 {
            staminaWarningLabel.text = "LOW STAMINA — Power/Focus OFF • Sprint locked"
            staminaWarningLabel.fontColor = .systemRed
            staminaWarningLabel.alpha = CGFloat(0.5 + 0.5 * abs(sin(time * 8)))
            if activeShotModes.contains(.power) || activeShotModes.contains(.focus) {
                activeShotModes.remove(.power)
                activeShotModes.remove(.focus)
                updateShotButtonVisuals()
                updateShotModeDots()
            }
        } else if pct <= 0.50 {
            var warnings: [String] = []
            if activeShotModes.contains(.power) { warnings.append("Power reduced") }
            if activeShotModes.contains(.focus) { warnings.append("Focus reduced") }
            warnings.append("Sprint halved")
            staminaWarningLabel.text = warnings.joined(separator: " • ")
            staminaWarningLabel.fontColor = .systemYellow
            staminaWarningLabel.alpha = 1.0
        } else {
            staminaWarningLabel.alpha = 0
        }

        // Shot mode dots follow player
        shotModeDots.position = CGPoint(x: screenPos.x, y: screenPos.y + 30 * pScale + 5)
    }

    private func updateNPCBossBar() {
        let screenPos = CourtRenderer.courtPoint(nx: npcAI.currentNX, ny: npcAI.currentNY)
        let coachScale = CourtRenderer.perspectiveScale(ny: npcAI.currentNY)
        npcBossBar.position = CGPoint(x: screenPos.x, y: screenPos.y + 30 * coachScale + 20)

        // Update stamina fill
        let pct = npcAI.stamina / P.maxStamina
        let barWidth: CGFloat = 60
        let barHeight: CGFloat = 6
        let w = max(1, barWidth * pct)
        npcStaminaBarFill.path = UIBezierPath(
            roundedRect: CGRect(x: -barWidth / 2, y: 0, width: w, height: barHeight),
            cornerRadius: 3
        ).cgPath

        if pct > 0.5 {
            npcStaminaBarFill.fillColor = .systemGreen
        } else if pct > 0.10 {
            npcStaminaBarFill.fillColor = .systemYellow
        } else {
            npcStaminaBarFill.fillColor = .systemRed
        }
    }

    private func showIndicator(_ text: String, color: UIColor, duration: TimeInterval = 0.8) {
        outcomeLabel.removeAllActions()
        outcomeLabel.text = text
        outcomeLabel.fontColor = color
        outcomeLabel.alpha = 0
        outcomeLabel.setScale(0.5)

        outcomeLabel.run(.group([
            .fadeIn(withDuration: 0.15),
            .scale(to: 1.0, duration: 0.15)
        ]))
        outcomeLabel.run(.sequence([
            .wait(forDuration: duration),
            .fadeOut(withDuration: 0.3)
        ]))
    }
}
