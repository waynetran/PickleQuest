import SpriteKit
import UIKit

@MainActor
final class InteractiveDrillScene: SKScene {
    private typealias AC = MatchAnimationConstants
    private typealias P = GameConstants.DrillPhysics

    // Sprites
    private var playerNode: SKSpriteNode!
    private var coachNode: SKSpriteNode!
    private var ballNode: SKSpriteNode!
    private var ballShadow: SKShapeNode!
    private var playerAnimator: SpriteSheetAnimator!
    private var coachAnimator: SpriteSheetAnimator!
    private var ballTextures: [SKTexture] = []

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
    private var swipeTouchStartTime: TimeInterval?

    // HUD container
    private var hudContainer: SKNode!
    private var hudBackground: SKShapeNode!
    private var outcomeLabel: SKLabelNode!

    // HUD row nodes (label + bar bg + bar fill + value label per row)
    private var hudRow1Label: SKLabelNode!
    private var hudRow1BarBg: SKShapeNode!
    private var hudRow1BarFill: SKShapeNode!
    private var hudRow1Value: SKLabelNode!
    private var hudRow2Label: SKLabelNode!
    private var hudRow2BarBg: SKShapeNode!
    private var hudRow2BarFill: SKShapeNode!
    private var hudRow2Value: SKLabelNode!
    private var hudStaminaLabel: SKLabelNode!
    private var hudStaminaBarBg: SKShapeNode!
    private var hudStaminaBarFill: SKShapeNode!
    private var hudStaminaValue: SKLabelNode!
    private var hudStarsLabel: SKLabelNode! // stars row (last)
    private var hudStaminaWarning: SKLabelNode! // warning below HUD

    // Cone targets (return of serve)
    private var coneNodes: [SKShapeNode] = []

    // Shot mode toggle buttons (5 modes)
    private var activeShotModes: DrillShotCalculator.ShotMode = []
    private var shotModeButtons: [SKNode] = []
    private var shotModeBgs: [SKShapeNode] = []
    private var shotModeTouch: UITouch?

    // Stamina
    private var stamina: CGFloat = GameConstants.DrillPhysics.maxStamina
    private var timeSinceLastSprint: CGFloat = 10 // start recovered

    // Swipe hint (serve mode)
    private var swipeHintNode: SKSpriteNode?

    // Speech bubble
    private var speechBubbleNode: SKNode!
    private var speechBubbleBackground: SKShapeNode!
    private var speechBubbleLabel: SKLabelNode!
    private var speechBubbleTail: SKShapeNode!

    // Game state
    private let ballSim = DrillBallSimulation()
    private var coachAI: DrillCoachAI!
    private var scorekeeper: DrillScorekeeper!
    private let drillConfig: DrillConfig
    private let playerStats: PlayerStats
    private let coachLevel: Int
    private let coachPersonality: CoachPersonality

    // Player position in court space
    private var playerNX: CGFloat = 0.5
    private var playerNY: CGFloat = 0.1

    // Movement
    private var playerMoveSpeed: CGFloat = 0.6
    private var lastUpdateTime: TimeInterval = 0
    private var previousBallNY: CGFloat = 0.5

    // Serve side tracking
    private var serveCount: Int = 0
    private var hasSwitchedSides: Bool = false

    // Game phases
    private enum Phase {
        case waitingToStart
        case playing
        case feedPause
        case waitingForServe
        case finished
    }
    private var phase: Phase = .waitingToStart
    private var feedPauseTimer: TimeInterval = 0

    // Configuration
    private let drill: TrainingDrill
    private let statGained: StatType
    private let appearance: CharacterAppearance
    private let coachAppearance: CharacterAppearance
    private let playerEnergy: Double
    private let coachEnergy: Double
    private let onComplete: (InteractiveDrillResult) -> Void

    init(
        drill: TrainingDrill,
        statGained: StatType,
        playerStats: PlayerStats,
        appearance: CharacterAppearance,
        coachAppearance: CharacterAppearance,
        coachLevel: Int,
        coachPersonality: CoachPersonality,
        playerEnergy: Double,
        coachEnergy: Double,
        onComplete: @escaping (InteractiveDrillResult) -> Void
    ) {
        self.drill = drill
        self.statGained = statGained
        self.playerStats = playerStats
        self.appearance = appearance
        self.coachAppearance = coachAppearance
        self.coachLevel = coachLevel
        self.coachPersonality = coachPersonality
        self.playerEnergy = playerEnergy
        self.coachEnergy = coachEnergy
        self.onComplete = onComplete

        self.drillConfig = DrillConfig.config(for: drill.type)

        super.init(size: CGSize(width: AC.sceneWidth, height: AC.sceneHeight))
        self.scaleMode = .aspectFill
        self.anchorPoint = CGPoint(x: 0, y: 0)
        self.backgroundColor = UIColor(hex: "#2C3E50")

        // Calculate player move speed from stats
        let speedStat = CGFloat(playerStats.stat(.speed))
        playerMoveSpeed = P.baseMoveSpeed + (speedStat / 99.0) * P.maxMoveSpeedBonus
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        buildScene()
        setupHUD()
    }

    /// Called from SwiftUI to skip/fast-forward the drill.
    func skipDrill() {
        guard phase != .finished && phase != .waitingToStart else { return }
        endDrill()
    }

    /// Called from SwiftUI when the player taps "Let's Play Pickleball!".
    func beginDrill() {
        guard phase == .waitingToStart else { return }
        hudContainer.alpha = 1
        startPlaying()
    }

    // MARK: - Scene Setup

    private func buildScene() {
        // Court
        let court = CourtRenderer.buildCourt()
        addChild(court)

        // Player sprite (near side)
        let (pNode, pTextures) = SpriteFactory.makeCharacterNode(appearance: appearance, isNearPlayer: true)
        playerNode = pNode
        playerNode.setScale(AC.Sprites.nearPlayerScale)
        playerNode.zPosition = AC.ZPositions.nearPlayer
        addChild(playerNode)
        playerAnimator = SpriteSheetAnimator(node: playerNode, textures: pTextures, isNear: true)

        // Coach sprite (far side)
        let (cNode, cTextures) = SpriteFactory.makeCharacterNode(appearance: coachAppearance, isNearPlayer: false)
        coachNode = cNode
        let coachNY = drillConfig.coachStartNY
        let farScale = AC.Sprites.farPlayerScale * CourtRenderer.perspectiveScale(ny: coachNY)
        coachNode.setScale(farScale)
        coachNode.zPosition = AC.ZPositions.farPlayer
        addChild(coachNode)
        coachAnimator = SpriteSheetAnimator(node: coachNode, textures: cTextures, isNear: false)

        // Speech bubble (follows coach)
        buildSpeechBubble()

        // Swipe hint (serve mode)
        if drillConfig.inputMode == .swipeToServe {
            buildSwipeHint()
        }

        // Ball
        ballTextures = SpriteFactory.makeBallTextures()
        let ballTexture = ballTextures.first
        ballNode = SKSpriteNode(texture: ballTexture)
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

        // Joystick (visible at default position, centers on touch)
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

        // Shot intensity buttons (right side, only for joystick drills)
        if drillConfig.inputMode == .joystick {
            buildShotButtons()
        }

        // Cone targets (return of serve only)
        if drillConfig.showConeTargets {
            buildConeTargets()
        }

        // Initialize positions
        playerNX = drillConfig.playerStartNX
        playerNY = drillConfig.playerStartNY
        syncPlayerPosition()

        // Coach AI
        coachAI = DrillCoachAI(config: drillConfig, coachLevel: coachLevel, playerStatAverage: playerStats.average)
        syncCoachPosition()

        // Scorekeeper
        scorekeeper = DrillScorekeeper(
            drill: drill,
            statGained: statGained,
            coachLevel: coachLevel,
            playerEnergy: playerEnergy,
            coachEnergy: coachEnergy
        )
    }

    private func buildConeTargets() {
        let targets = drill.type == .returnOfServe
            ? P.returnOfServeConeTargets
            : P.accuracyConeTargets
        for target in targets {
            let screenPos = CourtRenderer.courtPoint(nx: target.nx, ny: target.ny)
            let cone = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 8))
            path.addLine(to: CGPoint(x: -6, y: -4))
            path.addLine(to: CGPoint(x: 6, y: -4))
            path.closeSubpath()
            cone.path = path
            cone.fillColor = UIColor.orange.withAlphaComponent(0.7)
            cone.strokeColor = UIColor.white.withAlphaComponent(0.5)
            cone.lineWidth = 1
            cone.position = screenPos
            cone.zPosition = AC.ZPositions.nearPlayer - 0.5
            addChild(cone)
            coneNodes.append(cone)
        }
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

        // Vertically center 6 buttons around y=350
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

    private func toggleShotMode(at index: Int) {
        typealias SM = DrillShotCalculator.ShotMode
        let modes: [SM] = [.power, .reset, .slice, .topspin, .angled, .focus]
        guard index < modes.count else { return }

        let mode = modes[index]

        if activeShotModes.contains(mode) {
            activeShotModes.remove(mode)
        } else {
            // Power/Reset mutually exclusive; Topspin/Slice mutually exclusive
            if mode == .power {
                activeShotModes.remove(.reset)
            } else if mode == .reset {
                activeShotModes.remove(.power)
            } else if mode == .topspin {
                activeShotModes.remove(.slice)
            } else if mode == .slice {
                activeShotModes.remove(.topspin)
            }
            activeShotModes.insert(mode)
        }
        updateShotButtonVisuals()
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

    private func buildSpeechBubble() {
        speechBubbleNode = SKNode()
        speechBubbleNode.zPosition = AC.ZPositions.text + 2
        speechBubbleNode.alpha = 0

        // Label (multiline, comic style)
        speechBubbleLabel = SKLabelNode(text: "")
        speechBubbleLabel.fontName = "ChalkboardSE-Bold"
        speechBubbleLabel.fontSize = 11
        speechBubbleLabel.fontColor = .black
        speechBubbleLabel.numberOfLines = 0
        speechBubbleLabel.preferredMaxLayoutWidth = 160
        speechBubbleLabel.verticalAlignmentMode = .center
        speechBubbleLabel.horizontalAlignmentMode = .center

        // Background bubble (sized dynamically in showCoachSpeech)
        speechBubbleBackground = SKShapeNode()
        speechBubbleBackground.fillColor = .white
        speechBubbleBackground.strokeColor = UIColor(white: 0.2, alpha: 0.8)
        speechBubbleBackground.lineWidth = 1.5

        // Tail triangle pointing down toward coach
        speechBubbleTail = SKShapeNode()
        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: -6, y: 0))
        tailPath.addLine(to: CGPoint(x: 6, y: 0))
        tailPath.addLine(to: CGPoint(x: 0, y: -8))
        tailPath.closeSubpath()
        speechBubbleTail.path = tailPath
        speechBubbleTail.fillColor = .white
        speechBubbleTail.strokeColor = .clear

        speechBubbleNode.addChild(speechBubbleBackground)
        speechBubbleNode.addChild(speechBubbleTail)
        speechBubbleNode.addChild(speechBubbleLabel)
        addChild(speechBubbleNode)
    }

    private func showCoachSpeech(_ text: String, duration: TimeInterval = 3.0) {
        speechBubbleLabel.text = text
        speechBubbleNode.removeAllActions()

        // Size the bubble to fit text
        let textFrame = speechBubbleLabel.frame
        let padding: CGFloat = 10
        let bubbleWidth = max(textFrame.width + padding * 2, 60)
        let bubbleHeight = max(textFrame.height + padding * 2, 26)
        let rect = CGRect(
            x: -bubbleWidth / 2,
            y: -bubbleHeight / 2,
            width: bubbleWidth,
            height: bubbleHeight
        )
        speechBubbleBackground.path = UIBezierPath(roundedRect: rect, cornerRadius: 8).cgPath

        // Position tail at bottom center
        speechBubbleTail.position = CGPoint(x: 0, y: -bubbleHeight / 2)

        // Position bubble above coach
        let coachScreenPos = CourtRenderer.courtPoint(nx: coachAI.currentNX, ny: coachAI.currentNY)
        let coachScale = CourtRenderer.perspectiveScale(ny: coachAI.currentNY)
        let bubbleY = coachScreenPos.y + 30 * coachScale + bubbleHeight / 2 + 8
        speechBubbleNode.position = CGPoint(x: coachScreenPos.x, y: bubbleY)

        // Clamp to screen bounds
        let halfW = bubbleWidth / 2 + 4
        if speechBubbleNode.position.x < halfW {
            speechBubbleNode.position.x = halfW
        } else if speechBubbleNode.position.x > AC.sceneWidth - halfW {
            speechBubbleNode.position.x = AC.sceneWidth - halfW
        }

        speechBubbleNode.setScale(0.5)
        speechBubbleNode.run(.group([
            .fadeIn(withDuration: 0.15),
            .scale(to: 1.0, duration: 0.15)
        ]))
        speechBubbleNode.run(.sequence([
            .wait(forDuration: duration),
            .fadeOut(withDuration: 0.4)
        ]))
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
        // Crosscourt direction: if player is on right (nx > 0.5), swipe toward left
        let crosscourtDX: CGFloat = playerNX > 0.5 ? -60 : 60
        let startX = playerScreenPos.x
        let startY = playerScreenPos.y + 30
        let endX = startX + crosscourtDX
        let endY = startY + 90

        hint.position = CGPoint(x: startX, y: startY)
        hint.alpha = 0.85

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
                hint.position = CGPoint(x: pos.x, y: pos.y + 30)
            },
            .wait(forDuration: 0.15)
        ]))
        hint.run(animation, withKey: "swipeHint")
    }

    private func hideSwipeHint() {
        swipeHintNode?.removeAction(forKey: "swipeHint")
        swipeHintNode?.run(.fadeOut(withDuration: 0.2))
    }

    private func setupHUD() {
        let fontName = AC.Text.fontName
        let margin: CGFloat = 8
        let containerWidth: CGFloat = AC.sceneWidth - margin * 2
        let rowHeight: CGFloat = 20
        let barHeight: CGFloat = 10
        let labelX: CGFloat = 10
        let barX: CGFloat = 62
        let barWidth = containerWidth - barX - 10
        let padding: CGFloat = 8
        let rowCount: CGFloat = 4 // row1, row2, stamina, stars
        let containerHeight = rowCount * rowHeight + padding * 2

        // Store bar width for updateHUD
        hudBarWidthCurrent = barWidth

        // Container — full width, with top padding for safe area
        let topPadding: CGFloat = 24
        hudContainer = SKNode()
        hudContainer.position = CGPoint(x: margin, y: AC.sceneHeight - topPadding - containerHeight)
        hudContainer.zPosition = AC.ZPositions.text - 0.2
        hudContainer.alpha = 0
        addChild(hudContainer)

        hudBackground = SKShapeNode(rect: CGRect(
            x: 0, y: 0, width: containerWidth, height: containerHeight
        ), cornerRadius: 10)
        hudBackground.fillColor = UIColor(white: 0, alpha: 0.55)
        hudBackground.strokeColor = UIColor(white: 1, alpha: 0.12)
        hudBackground.lineWidth = 1
        hudContainer.addChild(hudBackground)

        // Helper: label + bar bg + bar fill + value label inside bar
        func makeRow(y: CGFloat, labelText: String) -> (SKLabelNode, SKShapeNode, SKShapeNode, SKLabelNode) {
            let label = SKLabelNode(text: labelText)
            label.fontName = fontName
            label.fontSize = 11
            label.fontColor = UIColor(white: 0.85, alpha: 1)
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: labelX, y: y)
            label.zPosition = 1

            let bg = SKShapeNode(rect: CGRect(x: 0, y: -barHeight / 2, width: barWidth, height: barHeight), cornerRadius: 4)
            bg.fillColor = UIColor(white: 0.2, alpha: 0.8)
            bg.strokeColor = .clear
            bg.position = CGPoint(x: barX, y: y)
            bg.zPosition = 1

            let fill = SKShapeNode(rect: CGRect(x: 0, y: -barHeight / 2, width: barWidth, height: barHeight), cornerRadius: 4)
            fill.fillColor = .systemCyan
            fill.strokeColor = .clear
            fill.position = CGPoint(x: barX, y: y)
            fill.zPosition = 2

            // Value text inside bar, right-aligned
            let value = SKLabelNode(text: "")
            value.fontName = fontName
            value.fontSize = 9
            value.fontColor = .white
            value.horizontalAlignmentMode = .right
            value.verticalAlignmentMode = .center
            value.position = CGPoint(x: barX + barWidth - 4, y: y)
            value.zPosition = 3

            hudContainer.addChild(label)
            hudContainer.addChild(bg)
            hudContainer.addChild(fill)
            hudContainer.addChild(value)
            return (label, bg, fill, value)
        }

        // Rows from top to bottom
        let row1Y = containerHeight - padding - rowHeight * 0.5
        let row2Y = row1Y - rowHeight
        let row3Y = row2Y - rowHeight
        let row4Y = row3Y - rowHeight

        (hudRow1Label, hudRow1BarBg, hudRow1BarFill, hudRow1Value) = makeRow(y: row1Y, labelText: "Round")
        (hudRow2Label, hudRow2BarBg, hudRow2BarFill, hudRow2Value) = makeRow(y: row2Y, labelText: "Shots")

        // Row 3: stamina
        (hudStaminaLabel, hudStaminaBarBg, hudStaminaBarFill, hudStaminaValue) = makeRow(y: row3Y, labelText: "Stamina")

        // Row 4: stars (no bar, just a label)
        hudStarsLabel = SKLabelNode(text: "")
        hudStarsLabel.fontName = fontName
        hudStarsLabel.fontSize = 13
        hudStarsLabel.fontColor = UIColor.systemYellow
        hudStarsLabel.horizontalAlignmentMode = .left
        hudStarsLabel.verticalAlignmentMode = .center
        hudStarsLabel.position = CGPoint(x: labelX, y: row4Y)
        hudStarsLabel.zPosition = 1
        hudContainer.addChild(hudStarsLabel)

        // Stamina warning label (below HUD container)
        hudStaminaWarning = SKLabelNode(text: "")
        hudStaminaWarning.fontName = fontName
        hudStaminaWarning.fontSize = 9
        hudStaminaWarning.fontColor = .systemYellow
        hudStaminaWarning.horizontalAlignmentMode = .left
        hudStaminaWarning.verticalAlignmentMode = .top
        hudStaminaWarning.position = CGPoint(x: margin + 10, y: hudContainer.position.y - 4)
        hudStaminaWarning.zPosition = AC.ZPositions.text
        hudStaminaWarning.alpha = 0
        addChild(hudStaminaWarning)

        // Outcome indicator (center of court)
        outcomeLabel = SKLabelNode(text: "")
        outcomeLabel.fontName = fontName
        outcomeLabel.fontSize = 36
        outcomeLabel.fontColor = .white
        outcomeLabel.position = CGPoint(x: AC.sceneWidth / 2, y: AC.sceneHeight * 0.45)
        outcomeLabel.zPosition = AC.ZPositions.text + 1
        outcomeLabel.alpha = 0
        addChild(outcomeLabel)
    }

    private func startPlaying() {
        switch drillConfig.inputMode {
        case .joystick:
            phase = .playing
            feedNewBall()
        case .swipeToServe:
            phase = .waitingForServe
            updateHUD()
            showSwipeHint()
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pos = touch.location(in: self)

            if drillConfig.inputMode == .swipeToServe && phase == .waitingForServe {
                swipeTouchStart = pos
                swipeTouchStartTime = touch.timestamp
                return
            }

            guard phase == .playing || phase == .feedPause else { return }

            // Check shot mode buttons first
            if drillConfig.inputMode == .joystick {
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
            }

            // Otherwise start joystick
            guard joystickTouch == nil else { continue }

            joystickTouch = touch
            joystickOrigin = pos

            // Move joystick to touch point, full alpha
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

        // Knob visual clamped to 1.5x base radius
        let maxVisualDist = joystickBaseRadius * 1.5
        if dist <= maxVisualDist {
            joystickKnob.position = pos
        } else {
            joystickKnob.position = CGPoint(
                x: joystickOrigin.x + (dx / dist) * maxVisualDist,
                y: joystickOrigin.y + (dy / dist) * maxVisualDist
            )
        }

        // Magnitude can exceed 1.0 (sprint zone up to 1.5)
        joystickMagnitude = min(dist / joystickBaseRadius, 1.5)
        if dist > 1.0 {
            joystickDirection = CGVector(dx: dx / dist, dy: dy / dist)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if drillConfig.inputMode == .swipeToServe,
               phase == .waitingForServe, let startPos = swipeTouchStart {
                let endPos = touch.location(in: self)
                handleServeSwipe(from: startPos, to: endPos)
                swipeTouchStart = nil
                swipeTouchStartTime = nil
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
        swipeTouchStartTime = nil
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
        // Snap back to default position at 40% alpha
        joystickBase.position = joystickDefaultPosition
        joystickKnob.position = joystickDefaultPosition
        joystickBase.alpha = 0.4
        joystickKnob.alpha = 0.4
    }

    // MARK: - Serve Swipe Handling

    private func handleServeSwipe(from startPos: CGPoint, to endPos: CGPoint) {
        let dx = endPos.x - startPos.x
        let dy = endPos.y - startPos.y
        let distance = sqrt(dx * dx + dy * dy)

        // Must swipe upward and exceed minimum distance
        guard dy > 0, distance >= P.serveSwipeMinDistance else { return }

        hideSwipeHint()
        serveCount += 1

        // Check if we need to switch sides after serve 5
        if serveCount == 6 && !hasSwitchedSides {
            hasSwitchedSides = true
            playerNX = 0.35
            playerNY = -0.03
            syncPlayerPosition()
            showIndicator("Switch Sides!", color: .cyan, duration: 0.6)
        }

        // Swipe angle → target deviation from center
        let swipeAngle = atan2(dx, dy)
        let angleDeviation = max(-P.serveSwipeAngleRange, min(P.serveSwipeAngleRange, swipeAngle))

        // Swipe distance → raw power factor (0.0–1.0+, uncapped for overhit detection)
        let rawPowerFactor = distance / P.serveSwipeMaxPower

        // Player stats reduce random scatter
        let accuracyStat = CGFloat(playerStats.stat(.accuracy))
        let focusStat = CGFloat(playerStats.stat(.focus))
        let scatterReduction = ((accuracyStat + focusStat) / 2.0) / 99.0
        let scatter = (1.0 - scatterReduction * 0.7) * 0.15
        let scatterX = CGFloat.random(in: -scatter...scatter)
        let scatterY = CGFloat.random(in: -scatter...scatter)

        // Calculate target position — overhit pushes target deeper (past baseline = out)
        // More sensitive: small swipe = kitchen/net, big swipe = long/out
        let baseTargetNY: CGFloat = 0.55 + rawPowerFactor * 0.50  // sweet spot ~0.72–0.85, overhit >0.95 = out
        let targetNX = max(0.15, min(0.85, 0.5 + angleDeviation + scatterX))
        let targetNY = max(0.50, min(1.10, baseTargetNY + scatterY))

        // Power: too slow = can't clear net, too fast = rockets out
        // Sweet spot is rawPowerFactor ~0.3–0.6
        let servePower = 0.10 + min(rawPowerFactor, 1.3) * 0.75
        // Arc: slow swipes get high arc (lobs), fast swipes get flat arc (drives)
        let serveArc: CGFloat = max(0.10, 0.55 - rawPowerFactor * 0.40)

        // Launch ball from player position
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

        // Play serve animation
        playerAnimator.play(.serveSwing)

        scorekeeper.onBallFed()
    }

    // MARK: - Main Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard phase == .playing || phase == .feedPause || phase == .waitingForServe else { return }

        let dt: CGFloat
        if lastUpdateTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(CGFloat(currentTime - lastUpdateTime), 1.0 / 30.0)
        }
        lastUpdateTime = currentTime

        if phase == .playing {
            if drillConfig.inputMode == .joystick {
                movePlayer(dt: dt)
            }
            previousBallNY = ballSim.courtY
            ballSim.update(dt: dt)
            coachAI.update(dt: dt, ball: ballSim)
            checkPlayerHit()
            checkCoachHit()
            checkBallState()
            syncAllPositions()
            updateHUD()
        } else if phase == .feedPause {
            feedPauseTimer -= dt
            if drillConfig.inputMode == .joystick {
                movePlayer(dt: dt)
            }
            syncAllPositions()
            if feedPauseTimer <= 0 {
                if scorekeeper.isAllRoundsComplete {
                    endDrill()
                } else {
                    advanceToNextRound()
                }
            }
        } else if phase == .waitingForServe {
            // Just sync positions, waiting for swipe input
            syncAllPositions()
            updateHUD()
        }
    }

    // MARK: - Player Movement

    private func movePlayer(dt: CGFloat) {
        guard joystickMagnitude > 0.1 else {
            playerAnimator.play(.ready)
            // Recover stamina when standing still
            timeSinceLastSprint += dt
            if timeSinceLastSprint >= P.staminaRecoveryDelay {
                stamina = min(P.maxStamina, stamina + P.staminaRecoveryRate * dt)
            }
            return
        }

        // Base speed from normal magnitude (capped at 1.0)
        let normalMag = min(joystickMagnitude, 1.0)
        var speed = playerMoveSpeed * normalMag

        // Sprint zone: magnitude > 1.0
        // Below 10% stamina: no sprinting. Below 50%: half sprint speed.
        let staminaPct = stamina / P.maxStamina
        let canSprint = joystickMagnitude > 1.0 && staminaPct > 0.10
        let isSprinting = canSprint
        if isSprinting {
            let sprintFraction = min((joystickMagnitude - 1.0) / 0.5, 1.0)
            var sprintBonus = sprintFraction * P.maxSprintSpeedBoost * playerMoveSpeed
            if staminaPct < 0.50 {
                sprintBonus *= 0.5  // half sprint speed when below 50% stamina
            }
            speed += sprintBonus
            stamina = max(0, stamina - P.sprintDrainRate * dt)
            timeSinceLastSprint = 0
        } else {
            // Not sprinting — recover after delay
            timeSinceLastSprint += dt
            if timeSinceLastSprint >= P.staminaRecoveryDelay {
                stamina = min(P.maxStamina, stamina + P.staminaRecoveryRate * dt)
            }
        }

        // Focus mode drains stamina passively (~2.5/sec = lasts 3-5 points)
        if activeShotModes.contains(.focus) {
            stamina = max(0, stamina - P.sprintDrainRate * 0.1 * dt)
        }

        // Joystick visual: turn red when sprinting
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

        // Clamp to movable range — player can go right up to the kitchen line
        playerNX = max(drillConfig.playerMinNX, min(drillConfig.playerMaxNX, playerNX))
        playerNY = max(drillConfig.playerMinNY, min(drillConfig.playerMaxNY, playerNY))

        // Walk animation based on dominant joystick direction
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

        scorekeeper.onSuccessfulReturn()

        // Check rally completion for rally mode — stop the point immediately
        if scorekeeper.scoringMode == .rallyStreak,
           scorekeeper.currentConsecutiveReturns >= drillConfig.rallyShotsRequired {
            scorekeeper.onRallyCompleted()
            let msg = coachPersonality.rallyCompleteLine(requiredShots: drillConfig.rallyShotsRequired)
            showCoachSpeech(msg, duration: 2.5)

            // End the point — rally requirement met
            ballSim.reset()
            ballNode.alpha = 0
            ballShadow.alpha = 0
            scorekeeper.onRallyEnd()
            scorekeeper.onRoundAttempted()
            showIndicator("Rally!", color: .systemGreen, duration: 0.8)

            phase = .feedPause
            feedPauseTimer = P.feedDelay + 2.5
            updateHUD()
            return
        }

        // Power mode: drain 20% of max stamina per shot (5 shots to empty)
        if activeShotModes.contains(.power) {
            stamina = max(0, stamina - P.maxStamina * 0.20)
        }

        let ballFromLeft = ballSim.courtX < playerNX
        let staminaPct = stamina / P.maxStamina
        let shot = DrillShotCalculator.calculatePlayerShot(
            stats: playerStats,
            ballApproachFromLeft: ballFromLeft,
            drillType: drill.type,
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

    private func checkCoachHit() {
        guard ballSim.isActive && ballSim.lastHitByPlayer else { return }
        guard ballSim.bounceCount < 2 else { return }
        guard ballSim.height < 0.20 else { return }

        if coachAI.shouldSwing(ball: ballSim) {
            let shot = coachAI.generateShot(ball: ballSim)

            let animState: CharacterAnimationState = shot.shotType == .forehand ? .forehand : .backhand
            coachAnimator.play(animState)

            ballSim.launch(
                from: CGPoint(x: coachAI.currentNX, y: coachAI.currentNY),
                toward: CGPoint(x: shot.targetNX, y: shot.targetNY),
                power: shot.power,
                arc: shot.arc,
                spin: shot.spinCurve
            )
            ballSim.lastHitByPlayer = false
            previousBallNY = ballSim.courtY
        }
    }

    // MARK: - Cone Hit Detection (Return of Serve)

    private func checkConeHits() {
        guard drill.type == .accuracyDrill || drill.type == .returnOfServe else { return }
        guard ballSim.bounceCount == 1, ballSim.lastHitByPlayer else { return }

        let ballNX = ballSim.courtX
        let ballNY = ballSim.courtY

        let targets = drill.type == .returnOfServe
            ? P.returnOfServeConeTargets
            : P.accuracyConeTargets
        for (index, target) in targets.enumerated() {
            let dx = ballNX - target.nx
            let dy = ballNY - target.ny
            let dist = sqrt(dx * dx + dy * dy)

            if dist <= P.coneHitRadius {
                scorekeeper.onConeHit()
                showCoachSpeech(coachPersonality.coneHitLine(), duration: 2.5)
                // Flash cone green
                if index < coneNodes.count {
                    let cone = coneNodes[index]
                    cone.fillColor = UIColor.green
                    cone.run(.sequence([
                        .wait(forDuration: 0.5),
                        .run { cone.fillColor = UIColor.orange.withAlphaComponent(0.7) }
                    ]))
                }
                break
            }
        }
    }

    // MARK: - Ball State Checks

    private enum PointOutcome {
        case net
        case out
        case doubleBounce
        case winner
        case serveIn
        case serveFault

        var text: String {
            switch self {
            case .net: return "Net!"
            case .out: return "Out!"
            case .doubleBounce: return "Double Bounce"
            case .winner: return "Winner!"
            case .serveIn: return "In!"
            case .serveFault: return "Fault!"
            }
        }

        var color: UIColor {
            switch self {
            case .net: return .systemRed
            case .out: return .systemOrange
            case .doubleBounce: return .systemYellow
            case .winner: return .systemGreen
            case .serveIn: return .systemGreen
            case .serveFault: return .systemRed
            }
        }
    }

    private func checkBallState() {
        guard ballSim.isActive else { return }

        if ballSim.checkNetCollision(previousY: previousBallNY) {
            if drill.type == .servePractice {
                onBallDead(outcome: .serveFault)
            } else {
                onBallDead(outcome: .net)
            }
            return
        }

        // Check cone hits when ball bounces on coach's side (accuracy/return of serve)
        if (drill.type == .accuracyDrill || drill.type == .returnOfServe)
            && ballSim.bounceCount == 1 && ballSim.lastHitByPlayer {
            checkConeHits()
        }

        if ballSim.isDoubleBounce {
            if drill.type == .servePractice {
                // Serve: must land past kitchen line (0.682) to be in
                if ballSim.lastHitByPlayer && ballSim.courtY > 0.682 {
                    scorekeeper.onSuccessfulReturn()
                    onBallDead(outcome: .serveIn)
                } else if ballSim.lastHitByPlayer && ballSim.courtY > 0.5 {
                    // Landed in kitchen — fault
                    onBallDead(outcome: .serveFault)
                } else {
                    onBallDead(outcome: .serveFault)
                }
            } else if drill.type == .returnOfServe {
                // Return of serve: ball landed on coach's side = successful return
                if ballSim.lastHitByPlayer && ballSim.courtY > 0.5 {
                    scorekeeper.onSuccessfulReturn()
                    onBallDead(outcome: .winner)
                } else {
                    onBallDead(outcome: .doubleBounce)
                }
            } else {
                let outcome: PointOutcome = ballSim.lastHitByPlayer ? .winner : .doubleBounce
                onBallDead(outcome: outcome)
            }
            return
        }

        if ballSim.isOutOfBounds {
            if drill.type == .servePractice {
                onBallDead(outcome: .serveFault)
            } else {
                onBallDead(outcome: .out)
            }
            return
        }

        // Stall detection: ball rolling with no velocity or timed out
        if ballSim.isStalled {
            if ballSim.lastHitByPlayer && ballSim.courtY > 0.5 {
                onBallDead(outcome: .winner)
            } else {
                onBallDead(outcome: .net)
            }
            return
        }
    }

    private func onBallDead(outcome: PointOutcome) {
        let lastHitByPlayer = ballSim.lastHitByPlayer
        ballSim.reset()
        ballNode.alpha = 0
        ballShadow.alpha = 0

        // Determine if the player won the point
        let playerWon: Bool
        switch outcome {
        case .winner, .serveIn: playerWon = true
        case .doubleBounce, .serveFault: playerWon = false
        case .net, .out: playerWon = !lastHitByPlayer
        }

        if playerWon {
            scorekeeper.onPlayerWonPoint()
        }

        scorekeeper.onRallyEnd()
        scorekeeper.onRoundAttempted()
        showOutcome(outcome)

        // Show coach commentary after a short delay
        let coachLine = coachCommentary(for: outcome)
        if let line = coachLine {
            run(.sequence([
                .wait(forDuration: 0.5),
                .run { [weak self] in self?.showCoachSpeech(line, duration: 2.5) }
            ]))
        }

        phase = .feedPause
        feedPauseTimer = coachLine != nil ? P.feedDelay + 2.5 : P.feedDelay + 0.4
    }

    private func coachCommentary(for outcome: PointOutcome) -> String? {
        switch outcome {
        case .winner:
            return coachPersonality.goodShotLine()
        case .serveIn:
            return coachPersonality.serveInLine()
        case .net, .out, .doubleBounce:
            return coachPersonality.missLine()
        case .serveFault:
            return coachPersonality.serveFaultLine()
        }
    }

    private func advanceToNextRound() {
        if scorekeeper.isAllRoundsComplete {
            endDrill()
            return
        }

        switch drill.type {
        case .baselineRally, .dinkingDrill:
            phase = .playing
            feedNewBall()
        case .servePractice:
            phase = .waitingForServe
            showSwipeHint()
            // Show coaching tip before each serve
            let tip = coachPersonality.feedTip(drillType: drill.type)
            showCoachSpeech(tip, duration: 2.5)
        case .accuracyDrill, .returnOfServe:
            phase = .playing
            feedNewBall()
        }
    }

    private func showOutcome(_ outcome: PointOutcome) {
        showIndicator(outcome.text, color: outcome.color, duration: 0.8)
    }

    private func showIndicator(_ text: String, color: UIColor, duration: TimeInterval = 0.5) {
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

    private func feedNewBall() {
        scorekeeper.onBallFed()

        // Show a coaching tip before each feed
        let tip = coachPersonality.feedTip(drillType: drill.type)
        showCoachSpeech(tip, duration: 2.5)

        switch drill.type {
        case .baselineRally, .dinkingDrill:
            coachAI.feedBall(ball: ballSim)
        case .servePractice:
            // Player serves via swipe — don't feed
            return
        case .accuracyDrill, .returnOfServe:
            coachAI.serveToPlayer(ball: ballSim)
        }

        previousBallNY = ballSim.courtY
        ballNode.alpha = 1
        ballShadow.alpha = 1
    }

    // MARK: - Position Syncing

    private func syncPlayerPosition() {
        let screenPos = CourtRenderer.courtPoint(nx: playerNX, ny: max(0, playerNY))
        playerNode.position = screenPos

        let pScale = CourtRenderer.perspectiveScale(ny: max(0, min(1, playerNY)))
        playerNode.setScale(AC.Sprites.nearPlayerScale * pScale)
        playerNode.zPosition = AC.ZPositions.nearPlayer - CGFloat(playerNY) * 0.1

        // Gradually tint red when sprinting and losing stamina
        let staminaPct = stamina / P.maxStamina
        let isSprinting = joystickMagnitude > 1.0 && stamina > 0
        if isSprinting || staminaPct < 1.0 {
            let redAmount = 1.0 - staminaPct // 0 = full stamina (white), 1 = empty (red)
            let tint = UIColor(red: 1.0, green: 1.0 - redAmount * 0.6, blue: 1.0 - redAmount * 0.7, alpha: 1.0)
            playerNode.color = tint
            playerNode.colorBlendFactor = redAmount * 0.5
        } else {
            playerNode.colorBlendFactor = 0
        }
    }

    private func syncCoachPosition() {
        let screenPos = CourtRenderer.courtPoint(nx: coachAI.currentNX, ny: coachAI.currentNY)
        coachNode.position = screenPos

        let pScale = CourtRenderer.perspectiveScale(ny: coachAI.currentNY)
        coachNode.setScale(AC.Sprites.farPlayerScale * pScale)
        coachNode.zPosition = AC.ZPositions.farPlayer - CGFloat(coachAI.currentNY) * 0.1
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
        syncCoachPosition()
        syncBallPosition()
    }

    // MARK: - HUD

    private var hudBarWidthCurrent: CGFloat = 100
    private let hudBarHeight: CGFloat = 10

    private func updateHUD() {
        let total = scorekeeper.totalRounds

        switch scorekeeper.scoringMode {
        case .rallyStreak:
            let rallyNum = min(scorekeeper.ralliesCompleted + 1, total)
            hudRow1Label.text = "Rally"
            hudRow1Value.text = "\(rallyNum)/\(total)"
            updateBarFill(hudRow1BarFill, fraction: CGFloat(rallyNum) / CGFloat(total), color: .systemCyan)

            let shots = scorekeeper.currentConsecutiveReturns
            let required = drillConfig.rallyShotsRequired
            hudRow2Label.text = "Shots"
            hudRow2Value.text = "\(shots)/\(required)"
            updateBarFill(hudRow2BarFill, fraction: CGFloat(shots) / CGFloat(max(1, required)), color: .systemBlue)

            // Stars for completed rallies
            let completed = scorekeeper.ralliesCompleted
            let filled = String(repeating: "\u{2605}", count: min(completed, total))
            let empty = String(repeating: "\u{2606}", count: max(0, total - completed))
            hudStarsLabel.text = filled + empty

        case .serveAccuracy:
            let attemptNum = min(scorekeeper.totalRoundsAttempted + 1, total)
            hudRow1Label.text = "Serve"
            hudRow1Value.text = "\(attemptNum)/\(total)"
            updateBarFill(hudRow1BarFill, fraction: CGFloat(attemptNum) / CGFloat(total), color: .systemCyan)

            let sideText = serveCount <= 5 ? "Right" : "Left"
            hudRow2Label.text = sideText
            hudRow2Value.text = "In: \(scorekeeper.successfulReturns)"
            let inPct = CGFloat(scorekeeper.successfulReturns) / CGFloat(max(1, scorekeeper.totalRoundsAttempted))
            updateBarFill(hudRow2BarFill, fraction: inPct, color: .systemBlue)

            let filled = String(repeating: "\u{2605}", count: scorekeeper.successfulReturns)
            let empty = String(repeating: "\u{2606}", count: max(0, total - scorekeeper.successfulReturns))
            hudStarsLabel.text = filled + empty

        case .returnTarget:
            let roundNum = min(scorekeeper.totalRoundsAttempted + 1, total)
            hudRow1Label.text = "Return"
            hudRow1Value.text = "\(roundNum)/\(total)"
            updateBarFill(hudRow1BarFill, fraction: CGFloat(roundNum) / CGFloat(total), color: .systemCyan)

            hudRow2Label.text = "Cones"
            hudRow2Value.text = "\(scorekeeper.coneHits)"
            let conePct = CGFloat(scorekeeper.coneHits) / CGFloat(max(1, total))
            updateBarFill(hudRow2BarFill, fraction: conePct, color: .systemOrange)

            let filled = String(repeating: "\u{2605}", count: scorekeeper.successfulReturns)
            let empty = String(repeating: "\u{2606}", count: max(0, total - scorekeeper.successfulReturns))
            hudStarsLabel.text = filled + empty
        }

        // Stamina bar
        updateStaminaBar()
    }

    private func updateBarFill(_ fill: SKShapeNode, fraction: CGFloat, color: UIColor) {
        let pct = max(0, min(1, fraction))
        let w = max(1, hudBarWidthCurrent * pct)
        fill.path = UIBezierPath(
            roundedRect: CGRect(x: 0, y: -hudBarHeight / 2, width: w, height: hudBarHeight),
            cornerRadius: 4
        ).cgPath
        fill.fillColor = color
    }

    private func updateStaminaBar() {
        let pct = stamina / P.maxStamina
        hudStaminaValue.text = "\(Int(stamina))%"
        let w = max(1, hudBarWidthCurrent * pct)
        hudStaminaBarFill.path = UIBezierPath(
            roundedRect: CGRect(x: 0, y: -hudBarHeight / 2, width: w, height: hudBarHeight),
            cornerRadius: 4
        ).cgPath

        // Bar color
        if pct > 0.5 {
            hudStaminaBarFill.fillColor = .systemGreen
        } else if pct > 0.10 {
            hudStaminaBarFill.fillColor = .systemYellow
        } else {
            hudStaminaBarFill.fillColor = .systemRed
        }

        // Flashing: steady at ≤50%, quick at ≤10%
        let time = CACurrentMediaTime()
        if pct <= 0.10 {
            let flash = 0.4 + 0.6 * abs(sin(time * 8))  // quick flash ~2.5Hz
            hudStaminaBarFill.alpha = CGFloat(flash)
            hudStaminaBarBg.alpha = CGFloat(flash)
        } else if pct <= 0.50 {
            let flash = 0.6 + 0.4 * abs(sin(time * 3))  // steady flash ~1Hz
            hudStaminaBarFill.alpha = CGFloat(flash)
            hudStaminaBarBg.alpha = 1.0
        } else {
            hudStaminaBarFill.alpha = 1.0
            hudStaminaBarBg.alpha = 1.0
        }

        // Warning text and auto-disable
        if pct <= 0.10 {
            hudStaminaWarning.text = "LOW STAMINA — Power/Focus OFF • Sprint locked"
            hudStaminaWarning.fontColor = .systemRed
            hudStaminaWarning.alpha = CGFloat(0.5 + 0.5 * abs(sin(time * 8)))

            // Auto-disable stamina-draining modes
            if activeShotModes.contains(.power) || activeShotModes.contains(.focus) {
                activeShotModes.remove(.power)
                activeShotModes.remove(.focus)
                updateShotButtonVisuals()
            }
        } else if pct <= 0.50 {
            var warnings: [String] = []
            if activeShotModes.contains(.power) { warnings.append("Power reduced") }
            if activeShotModes.contains(.focus) { warnings.append("Focus reduced") }
            warnings.append("Sprint halved")
            hudStaminaWarning.text = warnings.joined(separator: " • ")
            hudStaminaWarning.fontColor = .systemYellow
            hudStaminaWarning.alpha = 1.0
        } else {
            hudStaminaWarning.alpha = 0
        }
    }

    // MARK: - Drill End

    private func endDrill() {
        phase = .finished
        resetJoystick()
        ballSim.reset()
        ballNode.alpha = 0
        ballShadow.alpha = 0

        let result = scorekeeper.calculateResult()
        onComplete(result)
    }
}
