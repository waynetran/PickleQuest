import SpriteKit
import UIKit

@MainActor
final class InteractiveDrillScene: SKScene {
    private typealias AC = MatchAnimationConstants
    private typealias P = GameConstants.DrillPhysics

    // Player controller (shared physics, joystick, hitbox)
    private var controller: InteractivePlayerController!

    // Sprites
    private var coachNode: SKSpriteNode!
    private var ballNode: SKSpriteNode!
    private var ballShadow: SKShapeNode!
    private var ballTrailOuter: SKShapeNode!  // red/orange fire edge
    private var ballTrailInner: SKShapeNode!  // yellow/orange core
    private var ballTrailHistory: [CGPoint] = []
    private let ballTrailMaxLength: CGFloat = AC.sceneWidth * 0.5
    private let ballTrailMaxPoints: Int = 20
    private var coachAnimator: SpriteSheetAnimator!
    private var ballTextures: [SKTexture] = []

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

    // Shot type flash label (shows "POWER!", "TOUCH", "LOB" on hit)
    private var shotTypeLabel: SKLabelNode!
    private var shotTypeLabelTimer: CGFloat = 0

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

        // Create shared player controller
        controller = InteractivePlayerController(
            playerStats: playerStats,
            appearance: appearance,
            startNX: drillConfig.playerStartNX,
            startNY: drillConfig.playerStartNY,
            config: PlayerControllerConfig(
                minNX: drillConfig.playerMinNX,
                maxNX: drillConfig.playerMaxNX,
                minNY: drillConfig.playerMinNY,
                maxNY: drillConfig.playerMaxNY,
                jumpEnabled: true,
                lungeEnabled: true,
                hitboxRingsVisible: true
            )
        )
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

        // Player sprite + joystick + hitbox rings via shared controller
        controller.buildNodes(parent: self, appearance: appearance)
        controller.parentScene = self

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

        // Ball comet trail (two layers: outer fire edge + inner glow core)
        ballTrailOuter = SKShapeNode()
        ballTrailOuter.strokeColor = .clear
        ballTrailOuter.zPosition = AC.ZPositions.ball - 0.2
        ballTrailOuter.alpha = 0
        addChild(ballTrailOuter)

        ballTrailInner = SKShapeNode()
        ballTrailInner.strokeColor = .clear
        ballTrailInner.zPosition = AC.ZPositions.ball - 0.1
        ballTrailInner.alpha = 0
        addChild(ballTrailInner)

        // Shot type flash label (joystick drills)
        if drillConfig.inputMode == .joystick {
            buildShotTypeLabel()
        }

        // Cone targets (return of serve only)
        if drillConfig.showConeTargets {
            buildConeTargets()
        }

        // Initialize positions
        controller.syncPositions()

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

    private func buildShotTypeLabel() {
        shotTypeLabel = SKLabelNode(text: "")
        shotTypeLabel.fontName = "AvenirNext-Heavy"
        shotTypeLabel.fontSize = 14
        shotTypeLabel.fontColor = .white
        shotTypeLabel.horizontalAlignmentMode = .center
        shotTypeLabel.verticalAlignmentMode = .top
        shotTypeLabel.zPosition = AC.ZPositions.text + 2
        shotTypeLabel.alpha = 0
        addChild(shotTypeLabel)
    }

    // MARK: - Swipe Shot Determination

    private let powerSwipeThreshold: CGFloat = 400
    private let touchSwipeThreshold: CGFloat = 50
    private let lobSwipeThreshold: CGFloat = 200
    private let maxSwipePowerBoost: CGFloat = 0.5
    private let maxSwipeSpeed: CGFloat = 800    // pts/sec for max power boost
    private let maxLobSwipeSpeed: CGFloat = 600 // pts/sec for max lob arc

    /// Determine shot modes from joystick state at the moment of contact.
    private func determineShotMode() -> DrillShotCalculator.ShotMode {
        // Joystick released → neutral touch/dink
        guard controller.joystickTouch != nil else { return [.touch] }

        let vy = controller.joystickSwipeVelocity.dy  // positive = upward on screen
        let speed = sqrt(controller.joystickSwipeVelocity.dx * controller.joystickSwipeVelocity.dx
                       + controller.joystickSwipeVelocity.dy * controller.joystickSwipeVelocity.dy)

        if vy > powerSwipeThreshold {
            return [.power]
        } else if vy < -lobSwipeThreshold {
            return [.lob]
        } else if speed < touchSwipeThreshold {
            return [.touch]
        } else {
            return [.touch]
        }
    }

    /// Horizontal swipe direction mapped to target NX override.
    private func swipeDirectionNX() -> CGFloat? {
        guard controller.joystickTouch != nil else { return nil }
        return 0.5 + controller.joystickDirection.dx * 0.35
    }

    /// Extra power boost from swipe velocity for power shots.
    private func swipePowerBoost() -> CGFloat {
        let speed = sqrt(controller.joystickSwipeVelocity.dx * controller.joystickSwipeVelocity.dx
                       + controller.joystickSwipeVelocity.dy * controller.joystickSwipeVelocity.dy)
        let swipeFraction = min(speed / maxSwipeSpeed, 1.0)
        let powerStat = CGFloat(playerStats.stat(.power))
        return swipeFraction * maxSwipePowerBoost * (powerStat / 99.0)
    }

    /// Extra arc from downward swipe velocity for lob shots.
    private func swipeLobArcBoost() -> CGFloat {
        let downSpeed = abs(min(controller.joystickSwipeVelocity.dy, 0))
        let lobFraction = min(downSpeed / maxLobSwipeSpeed, 1.0)
        return lobFraction * 0.3
    }

    /// Flash shot type label below the player on hit.
    private func showShotTypeFlash(_ text: String, color: UIColor) {
        shotTypeLabel.text = text
        shotTypeLabel.fontColor = color
        shotTypeLabel.alpha = 1.0
        shotTypeLabel.setScale(1.0)
        shotTypeLabelTimer = 0.7

        shotTypeLabel.removeAllActions()
        shotTypeLabel.run(.sequence([
            .scale(to: 1.3, duration: 0.15),
            .scale(to: 1.0, duration: 0.15),
            .wait(forDuration: 0.1),
            .fadeOut(withDuration: 0.3)
        ]))
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

        let playerScreenPos = CourtRenderer.courtPoint(nx: controller.playerNX, ny: max(0, controller.playerNY))
        // Crosscourt direction: if player is on right (nx > 0.5), swipe toward left
        let crosscourtDX: CGFloat = controller.playerNX > 0.5 ? -60 : 60
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
                let pos = CourtRenderer.courtPoint(nx: self.controller.playerNX, ny: max(0, self.controller.playerNY))
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

        // Container — full width, with top padding for Dynamic Island
        let topPadding: CGFloat = 60
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
            controller.handleJoystickBegan(touch: touch, location: pos)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch = controller.joystickTouch,
              touches.contains(activeTouch) else { return }
        let pos = activeTouch.location(in: self)
        controller.handleJoystickMoved(touch: activeTouch, location: pos)
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

            if touch === controller.joystickTouch {
                controller.handleJoystickEnded(touch: touch)
                continue
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        swipeTouchStart = nil
        swipeTouchStartTime = nil
        for touch in touches {
            if touch === controller.joystickTouch {
                controller.handleJoystickEnded(touch: touch)
            }
        }
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
            controller.playerNX = 0.35
            controller.playerNY = -0.03
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
            from: CGPoint(x: controller.playerNX, y: max(0, controller.playerNY)),
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
        controller.playerAnimator.play(.forehand(isNear: true))

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
            controller.isPlayable = true
            controller.updateJump(dt: dt)
            if drillConfig.inputMode == .joystick {
                controller.movePlayer(dt: dt)
            }
            controller.storeBallPosition(courtX: ballSim.courtX, courtY: ballSim.courtY, height: ballSim.height)
            controller.currentBallX = ballSim.courtX
            controller.isBallActive = ballSim.isActive
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
                controller.movePlayer(dt: dt)
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

    private let shotAnimDuration: CGFloat = 0.40

    // MARK: - Hit Detection

    private func checkPlayerHit() {
        guard ballSim.isActive && !ballSim.lastHitByPlayer else { return }
        guard ballSim.bounceCount < 2 else { return }

        // Pre-bounce: don't reach forward — wait for ball to arrive at player's Y
        if ballSim.bounceCount == 0 && ballSim.courtY > controller.playerNY { return }

        // Swept collision via controller (anti-tunneling)
        let dist = controller.checkHitDistance(
            ballX: ballSim.courtX, ballY: ballSim.courtY, ballHeight: ballSim.height
        )
        guard dist <= controller.hitboxRadius else { return }

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
            ballTrailOuter.alpha = 0
            ballTrailInner.alpha = 0
            ballTrailHistory.removeAll()
            scorekeeper.onRallyEnd()
            scorekeeper.onRoundAttempted()
            showIndicator("Rally!", color: .systemGreen, duration: 0.8)

            phase = .feedPause
            feedPauseTimer = P.feedDelay + 2.5
            updateHUD()
            return
        }

        // Determine shot mode from joystick swipe state
        var shotModes = determineShotMode()

        // Auto-upgrade to power at the kitchen when ball is high (put-away opportunity)
        let distFromNet = abs(0.5 - controller.playerNY)
        if distFromNet < P.kitchenVolleyRange
            && ballSim.height > P.smashHeightThreshold
            && shotModes.contains(.touch) {
            shotModes = [.power]
        }

        // Power mode: drain 20% of max stamina per shot (5 shots to empty)
        if shotModes.contains(.power) {
            controller.stamina = max(0, controller.stamina - P.maxStamina * 0.20)
        }

        let ballFromLeft = ballSim.courtX < controller.playerNX
        let staminaPct = controller.stamina / P.maxStamina
        var shot = DrillShotCalculator.calculatePlayerShot(
            stats: playerStats,
            ballApproachFromLeft: ballFromLeft,
            drillType: drill.type,
            ballHeight: ballSim.height,
            courtNY: controller.playerNY,
            modes: shotModes,
            staminaFraction: staminaPct
        )

        // Apply swipe direction override
        if let directionNX = swipeDirectionNX() {
            shot.targetNX = max(0.15, min(0.85, directionNX))
        }

        // Apply power boost from swipe velocity
        if shotModes.contains(.power) {
            shot.power = min(shot.power + swipePowerBoost(), 2.5)
        }

        // Apply lob arc boost from downward swipe velocity
        if shotModes.contains(.lob) {
            shot.arc += swipeLobArcBoost()
        }

        // Flash shot type label
        if shotModes.contains(.power) {
            showShotTypeFlash("POWER!", color: .systemRed)
        } else if shotModes.contains(.lob) {
            showShotTypeFlash("LOB", color: .systemIndigo)
        } else {
            showShotTypeFlash("TOUCH", color: .systemTeal)
        }

        let animState: CharacterAnimationState = shot.shotType == .forehand
            ? .forehand(isNear: true) : .backhand(isNear: true)
        controller.playerAnimator.play(animState)
        controller.playerShotAnimTimer = shotAnimDuration

        run(SoundManager.shared.skAction(for: .paddleHit))

        ballSim.launch(
            from: CGPoint(x: controller.playerNX, y: controller.playerNY),
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

        if coachAI.shouldSwing(ball: ballSim) {
            let shot = coachAI.generateShot(ball: ballSim)

            let animState: CharacterAnimationState = shot.shotType == .forehand
                ? .forehand(isNear: false) : .backhand(isNear: false)
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
        case miss       // player didn't reach the ball
        case winner
        case serveIn
        case serveFault

        var text: String {
            switch self {
            case .net: return "Net!"
            case .out: return "Out!"
            case .miss: return "Miss!"
            case .winner: return "Winner!"
            case .serveIn: return "In!"
            case .serveFault: return "Fault!"
            }
        }

        var color: UIColor {
            switch self {
            case .net: return .systemRed
            case .out: return .systemOrange
            case .miss: return .systemYellow
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
            && ballSim.didBounceThisFrame && ballSim.bounceCount == 1 && ballSim.lastHitByPlayer {
            checkConeHits()
        }

        // Bounce-time out call using interpolated landing position
        if ballSim.didBounceThisFrame && ballSim.bounceCount == 1 && ballSim.isLandingOut {
            if drill.type == .servePractice {
                onBallDead(outcome: .serveFault)
            } else {
                onBallDead(outcome: .out)
            }
            return
        }

        if ballSim.isDoubleBounce {
            let bounceY = ballSim.lastBounceCourtY
            if drill.type == .servePractice {
                // Serve: must land past kitchen line (0.682) to be in
                if ballSim.lastHitByPlayer && bounceY > 0.682 {
                    scorekeeper.onSuccessfulReturn()
                    onBallDead(outcome: .serveIn)
                } else if ballSim.lastHitByPlayer && bounceY > 0.5 {
                    onBallDead(outcome: .serveFault)
                } else {
                    onBallDead(outcome: .serveFault)
                }
            } else if drill.type == .returnOfServe {
                if ballSim.lastHitByPlayer && bounceY > 0.5 {
                    scorekeeper.onSuccessfulReturn()
                    onBallDead(outcome: .winner)
                } else {
                    onBallDead(outcome: .miss)
                }
            } else {
                let outcome: PointOutcome = ballSim.lastHitByPlayer ? .winner : .miss
                onBallDead(outcome: outcome)
            }
            return
        }

        // Safety: ball escaped the playing area entirely
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
        ballTrailOuter.alpha = 0
        ballTrailInner.alpha = 0
        ballTrailHistory.removeAll()

        // Determine if the player won the point
        let playerWon: Bool
        switch outcome {
        case .winner, .serveIn: playerWon = true
        case .miss, .serveFault: playerWon = false
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
        case .net, .out, .miss:
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
        controller.syncPositions()

        // Shot type label follows player (below feet)
        let screenPos = CourtRenderer.courtPoint(nx: controller.playerNX, ny: max(0, controller.playerNY))
        let pScale = CourtRenderer.perspectiveScale(ny: max(0, min(1, controller.playerNY)))
        shotTypeLabel?.position = CGPoint(x: screenPos.x, y: screenPos.y - 25 * pScale)
    }

    private func syncCoachPosition() {
        let screenPos = CourtRenderer.courtPoint(nx: coachAI.currentNX, ny: coachAI.currentNY)
        coachNode.position = screenPos

        let pScale = CourtRenderer.perspectiveScale(ny: coachAI.currentNY)
        coachNode.setScale(AC.Sprites.farPlayerScale * pScale)
        coachNode.zPosition = AC.ZPositions.farPlayer - CGFloat(coachAI.currentNY) * 0.1
    }

    private func syncBallPosition() {
        guard ballSim.isActive else {
            ballTrailOuter.alpha = 0
            ballTrailInner.alpha = 0
            ballTrailHistory.removeAll()
            return
        }

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

        // Update comet trail
        updateBallTrail(ballScreenPos: ballScreenPos, pScale: pScale)
    }

    private func updateBallTrail(ballScreenPos: CGPoint, pScale: CGFloat) {
        ballTrailHistory.append(ballScreenPos)

        if ballTrailHistory.count > ballTrailMaxPoints {
            ballTrailHistory.removeFirst(ballTrailHistory.count - ballTrailMaxPoints)
        }

        // Trim by max length
        var totalDist: CGFloat = 0
        var trimIndex = ballTrailHistory.count
        for i in stride(from: ballTrailHistory.count - 1, through: 1, by: -1) {
            let dx = ballTrailHistory[i].x - ballTrailHistory[i - 1].x
            let dy = ballTrailHistory[i].y - ballTrailHistory[i - 1].y
            totalDist += sqrt(dx * dx + dy * dy)
            if totalDist > ballTrailMaxLength {
                trimIndex = i
                break
            }
        }
        if trimIndex > 0 && trimIndex < ballTrailHistory.count {
            ballTrailHistory.removeFirst(trimIndex)
        }

        guard ballTrailHistory.count >= 2 else {
            ballTrailOuter.alpha = 0
            ballTrailInner.alpha = 0
            return
        }

        // Ball speed → fire intensity
        let ballSpeed = sqrt(ballSim.vx * ballSim.vx + ballSim.vy * ballSim.vy)
        let maxSpeed = P.baseShotSpeed + 2.0 * (P.maxShotSpeed - P.baseShotSpeed)
        let fireIntensity = min(ballSpeed / maxSpeed, 1.0)

        let headHalfWidth = AC.Sprites.ballSize * pScale * 0.25
        let count = ballTrailHistory.count

        let outerPath = buildTrailPath(halfWidth: headHalfWidth, count: count)
        let innerPath = buildTrailPath(halfWidth: headHalfWidth * 0.55, count: count)

        // Outer: yellow → red
        let outerG: CGFloat = 0.85 - fireIntensity * 0.65
        let outerAlpha: CGFloat = 0.3 + fireIntensity * 0.25
        ballTrailOuter.fillColor = UIColor(red: 1.0, green: outerG, blue: 0.1 * (1.0 - fireIntensity), alpha: outerAlpha)
        ballTrailOuter.path = outerPath
        ballTrailOuter.alpha = 1
        ballTrailOuter.zPosition = AC.ZPositions.ball - 0.2 - CGFloat(ballSim.courtY) * 0.1

        // Inner: yellow → orange
        let innerG: CGFloat = 0.92 - fireIntensity * 0.42
        let innerAlpha: CGFloat = 0.45 + fireIntensity * 0.25
        ballTrailInner.fillColor = UIColor(red: 1.0, green: innerG, blue: 0.2 * (1.0 - fireIntensity), alpha: innerAlpha)
        ballTrailInner.path = innerPath
        ballTrailInner.alpha = 1
        ballTrailInner.zPosition = AC.ZPositions.ball - 0.1 - CGFloat(ballSim.courtY) * 0.1
    }

    private func buildTrailPath(halfWidth: CGFloat, count: Int) -> CGPath {
        var topEdge: [CGPoint] = []
        var bottomEdge: [CGPoint] = []

        for i in 0..<count {
            let p = ballTrailHistory[i]
            let t = CGFloat(i) / CGFloat(count - 1)
            let taper = pow(sin(t * .pi / 2), 0.7)
            let halfW = halfWidth * taper

            let next = i < count - 1 ? ballTrailHistory[i + 1] : p
            let prev = i > 0 ? ballTrailHistory[i - 1] : p
            let dx = next.x - prev.x
            let dy = next.y - prev.y
            let len = sqrt(dx * dx + dy * dy)

            let nx: CGFloat, ny: CGFloat
            if len > 0.01 {
                nx = -dy / len
                ny = dx / len
            } else {
                nx = 0
                ny = 1
            }

            topEdge.append(CGPoint(x: p.x + nx * halfW, y: p.y + ny * halfW))
            bottomEdge.append(CGPoint(x: p.x - nx * halfW, y: p.y - ny * halfW))
        }

        let path = CGMutablePath()
        path.move(to: topEdge[0])
        for i in 1..<topEdge.count {
            path.addLine(to: topEdge[i])
        }

        // Rounded cap at the head
        let headTop = topEdge[topEdge.count - 1]
        let headBot = bottomEdge[bottomEdge.count - 1]
        let headCenter = CGPoint(x: (headTop.x + headBot.x) / 2,
                                 y: (headTop.y + headBot.y) / 2)
        let capRadius = sqrt(pow(headTop.x - headCenter.x, 2) + pow(headTop.y - headCenter.y, 2))
        if capRadius > 0.5 {
            let angleTop = atan2(headTop.y - headCenter.y, headTop.x - headCenter.x)
            let angleBot = atan2(headBot.y - headCenter.y, headBot.x - headCenter.x)
            path.addArc(center: headCenter, radius: capRadius,
                        startAngle: angleTop, endAngle: angleBot, clockwise: true)
        }

        for i in stride(from: bottomEdge.count - 1, through: 0, by: -1) {
            path.addLine(to: bottomEdge[i])
        }
        path.closeSubpath()
        return path
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
        let pct = controller.stamina / P.maxStamina
        hudStaminaValue.text = "\(Int(controller.stamina))%"
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

        // Warning text
        if pct <= 0.10 {
            hudStaminaWarning.text = "LOW STAMINA — Sprint locked"
            hudStaminaWarning.fontColor = .systemRed
            hudStaminaWarning.alpha = CGFloat(0.5 + 0.5 * abs(sin(time * 8)))
        } else if pct <= 0.50 {
            hudStaminaWarning.text = "Sprint halved"
            hudStaminaWarning.fontColor = .systemYellow
            hudStaminaWarning.alpha = 1.0
        } else {
            hudStaminaWarning.alpha = 0
        }
    }

    // MARK: - Drill End

    private func endDrill() {
        phase = .finished
        controller.resetJoystick()
        ballSim.reset()
        ballNode.alpha = 0
        ballShadow.alpha = 0
        ballTrailOuter.alpha = 0
        ballTrailInner.alpha = 0
        ballTrailHistory.removeAll()

        let result = scorekeeper.calculateResult()
        onComplete(result)
    }
}
