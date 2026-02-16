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

    // HUD
    private var ballCountLabel: SKLabelNode!
    private var scoreLabel: SKLabelNode!
    private var rallyLabel: SKLabelNode!
    private var outcomeLabel: SKLabelNode!

    // Cone targets (return of serve)
    private var coneNodes: [SKShapeNode] = []

    // Game state
    private let ballSim = DrillBallSimulation()
    private var coachAI: DrillCoachAI!
    private var scorekeeper: DrillScorekeeper!
    private let drillConfig: DrillConfig
    private let playerStats: PlayerStats
    private let coachLevel: Int

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
        buildScene()
        setupHUD()
    }

    /// Called from SwiftUI when the player taps "Let's Play Pickleball!".
    func beginDrill() {
        guard phase == .waitingToStart else { return }
        ballCountLabel.alpha = 1
        scoreLabel.alpha = 1
        rallyLabel.alpha = 1
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

        // Joystick (floating — appears at touch point)
        joystickBase = SKShapeNode(circleOfRadius: joystickBaseRadius)
        joystickBase.fillColor = UIColor(white: 0.15, alpha: 0.5)
        joystickBase.strokeColor = UIColor(white: 0.6, alpha: 0.3)
        joystickBase.lineWidth = 2
        joystickBase.zPosition = 15
        joystickBase.alpha = 0
        addChild(joystickBase)

        joystickKnob = SKShapeNode(circleOfRadius: joystickKnobRadius)
        joystickKnob.fillColor = UIColor(white: 0.8, alpha: 0.6)
        joystickKnob.strokeColor = UIColor(white: 1.0, alpha: 0.4)
        joystickKnob.lineWidth = 1.5
        joystickKnob.zPosition = 16
        joystickKnob.alpha = 0
        addChild(joystickKnob)

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
        for target in P.coneTargets {
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

    private func setupHUD() {
        let fontName = AC.Text.fontName

        ballCountLabel = SKLabelNode(text: "Round 0/\(scorekeeper.totalRounds)")
        ballCountLabel.fontName = fontName
        ballCountLabel.fontSize = 24
        ballCountLabel.fontColor = .white
        ballCountLabel.position = CGPoint(x: AC.sceneWidth / 2, y: AC.sceneHeight - 60)
        ballCountLabel.zPosition = AC.ZPositions.text
        addChild(ballCountLabel)

        scoreLabel = SKLabelNode(text: "Returns: 0")
        scoreLabel.fontName = fontName
        scoreLabel.fontSize = 18
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: 20, y: AC.sceneHeight - 90)
        scoreLabel.zPosition = AC.ZPositions.text
        addChild(scoreLabel)

        rallyLabel = SKLabelNode(text: "")
        rallyLabel.fontName = fontName
        rallyLabel.fontSize = 18
        rallyLabel.fontColor = .white
        rallyLabel.horizontalAlignmentMode = .right
        rallyLabel.position = CGPoint(x: AC.sceneWidth - 20, y: AC.sceneHeight - 90)
        rallyLabel.zPosition = AC.ZPositions.text
        addChild(rallyLabel)

        // Outcome indicator (center of court)
        outcomeLabel = SKLabelNode(text: "")
        outcomeLabel.fontName = fontName
        outcomeLabel.fontSize = 36
        outcomeLabel.fontColor = .white
        outcomeLabel.position = CGPoint(x: AC.sceneWidth / 2, y: AC.sceneHeight * 0.45)
        outcomeLabel.zPosition = AC.ZPositions.text + 1
        outcomeLabel.alpha = 0
        addChild(outcomeLabel)

        ballCountLabel.alpha = 0
        scoreLabel.alpha = 0
        rallyLabel.alpha = 0
    }

    private func startPlaying() {
        switch drillConfig.inputMode {
        case .joystick:
            phase = .playing
            feedNewBall()
        case .swipeToServe:
            phase = .waitingForServe
            updateHUD()
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let pos = touch.location(in: self)

        if drillConfig.inputMode == .swipeToServe && phase == .waitingForServe {
            swipeTouchStart = pos
            swipeTouchStartTime = touch.timestamp
            return
        }

        guard phase == .playing || phase == .feedPause else { return }
        guard joystickTouch == nil else { return }

        joystickTouch = touch
        joystickOrigin = pos

        joystickBase.position = pos
        joystickKnob.position = pos
        joystickBase.alpha = 1
        joystickKnob.alpha = 1
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch = joystickTouch, touches.contains(activeTouch) else { return }

        let pos = activeTouch.location(in: self)
        let dx = pos.x - joystickOrigin.x
        let dy = pos.y - joystickOrigin.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist <= joystickBaseRadius {
            joystickKnob.position = pos
        } else {
            joystickKnob.position = CGPoint(
                x: joystickOrigin.x + (dx / dist) * joystickBaseRadius,
                y: joystickOrigin.y + (dy / dist) * joystickBaseRadius
            )
        }

        let clamped = min(dist, joystickBaseRadius)
        joystickMagnitude = clamped / joystickBaseRadius
        if dist > 1.0 {
            joystickDirection = CGVector(dx: dx / dist, dy: dy / dist)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first, drillConfig.inputMode == .swipeToServe,
           phase == .waitingForServe, let startPos = swipeTouchStart {
            let endPos = touch.location(in: self)
            handleServeSwipe(from: startPos, to: endPos)
            swipeTouchStart = nil
            swipeTouchStartTime = nil
            return
        }

        guard let activeTouch = joystickTouch, touches.contains(activeTouch) else { return }
        resetJoystick()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        swipeTouchStart = nil
        swipeTouchStartTime = nil
        guard let activeTouch = joystickTouch, touches.contains(activeTouch) else { return }
        resetJoystick()
    }

    private func resetJoystick() {
        joystickTouch = nil
        joystickDirection = .zero
        joystickMagnitude = 0
        joystickBase.alpha = 0
        joystickKnob.alpha = 0
    }

    // MARK: - Serve Swipe Handling

    private func handleServeSwipe(from startPos: CGPoint, to endPos: CGPoint) {
        let dx = endPos.x - startPos.x
        let dy = endPos.y - startPos.y
        let distance = sqrt(dx * dx + dy * dy)

        // Must swipe upward and exceed minimum distance
        guard dy > 0, distance >= P.serveSwipeMinDistance else { return }

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

        // Swipe distance → power (capped)
        let powerFactor = min(distance / P.serveSwipeMaxPower, 1.0)

        // Player stats reduce random scatter
        let accuracyStat = CGFloat(playerStats.stat(.accuracy))
        let focusStat = CGFloat(playerStats.stat(.focus))
        let scatterReduction = ((accuracyStat + focusStat) / 2.0) / 99.0
        let scatter = (1.0 - scatterReduction * 0.7) * 0.15
        let scatterX = CGFloat.random(in: -scatter...scatter)
        let scatterY = CGFloat.random(in: -scatter...scatter)

        // Calculate target position
        let targetNX = max(0.15, min(0.85, 0.5 + angleDeviation + scatterX))
        let targetNY = max(0.60, min(0.90, 0.75 + scatterY))

        let servePower = 0.4 + powerFactor * 0.5
        let serveArc: CGFloat = 0.35 + (1.0 - powerFactor) * 0.15

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
            return
        }

        let speed = playerMoveSpeed * joystickMagnitude
        playerNX += joystickDirection.dx * speed * dt
        playerNY += joystickDirection.dy * speed * dt

        // Clamp to movable range
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

        // Check rally completion for rally mode
        if scorekeeper.scoringMode == .rallyStreak,
           scorekeeper.currentConsecutiveReturns >= drillConfig.rallyShotsRequired {
            scorekeeper.onRallyCompleted()
            showIndicator("Rally Complete!", color: .systemGreen, duration: 0.8)
        }

        let ballFromLeft = ballSim.courtX < playerNX
        let shot = DrillShotCalculator.calculatePlayerShot(
            stats: playerStats,
            ballApproachFromLeft: ballFromLeft,
            drillType: drill.type,
            ballHeight: ballSim.height
        )

        let animState: CharacterAnimationState = shot.shotType == .forehand ? .forehand : .backhand
        playerAnimator.play(animState)

        ballSim.launch(
            from: CGPoint(x: playerNX, y: playerNY),
            toward: CGPoint(x: shot.targetNX, y: shot.targetNY),
            power: shot.power,
            arc: shot.arc,
            spin: shot.spinCurve
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
        guard drill.type == .returnOfServe else { return }
        guard ballSim.bounceCount == 1, ballSim.lastHitByPlayer else { return }

        let ballNX = ballSim.courtX
        let ballNY = ballSim.courtY

        for (index, target) in P.coneTargets.enumerated() {
            let dx = ballNX - target.nx
            let dy = ballNY - target.ny
            let dist = sqrt(dx * dx + dy * dy)

            if dist <= P.coneHitRadius {
                scorekeeper.onConeHit()
                showIndicator("Cone Hit!", color: .orange, duration: 0.6)
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

        // Check cone hits when ball bounces on coach's side (return of serve)
        if drill.type == .returnOfServe && ballSim.bounceCount == 1 && ballSim.lastHitByPlayer {
            checkConeHits()
        }

        if ballSim.isDoubleBounce {
            if drill.type == .servePractice {
                // Serve: ball landed on coach's side = In!
                if ballSim.lastHitByPlayer && ballSim.courtY > 0.5 {
                    scorekeeper.onSuccessfulReturn()
                    onBallDead(outcome: .serveIn)
                } else {
                    onBallDead(outcome: .serveFault)
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
    }

    private func onBallDead(outcome: PointOutcome) {
        ballSim.reset()
        ballNode.alpha = 0
        ballShadow.alpha = 0
        scorekeeper.onRallyEnd()
        scorekeeper.onRoundAttempted()
        showOutcome(outcome)

        phase = .feedPause
        feedPauseTimer = P.feedDelay + 0.4
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
        case .returnOfServe:
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

        switch drill.type {
        case .baselineRally, .dinkingDrill:
            coachAI.feedBall(ball: ballSim)
        case .servePractice:
            // Player serves via swipe — don't feed
            return
        case .returnOfServe:
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

    private func updateHUD() {
        switch scorekeeper.scoringMode {
        case .rallyStreak:
            ballCountLabel.text = "Rally \(scorekeeper.ralliesCompleted + 1)/\(scorekeeper.totalRounds)"
            scoreLabel.text = "Returns: \(scorekeeper.currentConsecutiveReturns)/\(drillConfig.rallyShotsRequired)"
            rallyLabel.text = "Completed: \(scorekeeper.ralliesCompleted)"
        case .serveAccuracy:
            let sideText = serveCount <= 5 ? "Right Side" : "Left Side"
            ballCountLabel.text = "Serve \(scorekeeper.totalRoundsAttempted + 1)/\(scorekeeper.totalRounds)"
            scoreLabel.text = sideText
            rallyLabel.text = "In: \(scorekeeper.successfulReturns)"
        case .returnTarget:
            ballCountLabel.text = "Return \(scorekeeper.totalRoundsAttempted + 1)/\(scorekeeper.totalRounds)"
            scoreLabel.text = "Returns: \(scorekeeper.successfulReturns)"
            rallyLabel.text = "Cone Hits: \(scorekeeper.coneHits)"
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
