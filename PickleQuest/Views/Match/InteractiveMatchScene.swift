import SpriteKit
import UIKit

@MainActor
final class InteractiveMatchScene: SKScene {
    private typealias AC = MatchAnimationConstants
    private typealias P = GameConstants.DrillPhysics
    private typealias IM = GameConstants.InteractiveMatch
    private typealias PB = GameConstants.PlayerBalance

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
    private let joystickBaseRadius: CGFloat = 50
    private let joystickKnobRadius: CGFloat = 30

    // Swipe-to-serve state
    private var swipeTouchStart: CGPoint?
    private var swipeHintNode: SKSpriteNode?

    // NPC serve-stall taunts → walkoff
    private var npcSpeechBubble: SKNode?
    private var playerServeStallTimer: CGFloat = 0
    private var serveStallTauntIndex: Int = 0
    private var npcIsWalkingOff: Bool = false
    private var nextSnarkyTime: CGFloat = 0 // countdown to next idle comment
    private var nextPaceTime: CGFloat = 20  // countdown to next frustration pace
    private var npcIsPacing: Bool = false
    /// Snarky idle comments shown every 5-10 seconds while player stalls
    private static let snarkyComments: [String] = [
        "You gonna serve or what? 😏",
        "Any day now...",
        "I got places to be 🙄",
        "Hello? Anybody home?",
        "*taps paddle impatiently*",
        "My grandma serves\nfaster than this",
        "I'm literally falling\nasleep over here",
        "Is this your first time\nholding a paddle?",
        "*checks watch*",
        "You practicing your\nserve face? 😂",
        "I didn't sign up for\na staring contest",
        "*yawns dramatically*",
        "Take your time,\nI cleared my schedule... 😒",
        "The suspense is\nkilling me 💀",
    ]
    /// 3-step walkoff warnings at escalating severity
    private static let walkoffWarnings: [String] = [
        "Okay for real,\nserve or I'm leaving ⚠️",
        "Last chance.\nI'm not kidding. ⚠️",
        "That's it. I'm done.",
    ]
    /// Lob taunts — NPC says something after successfully lobbing the player
    private static let lobTaunts: [String] = [
        "See ya! 👋",
        "Fore! ...wait,\nwrong sport",
        "Fly ball! \nAnybody? No?",
        "I believe I can fly 🎵",
        "Did you see\nthat hang time?",
        "Lob city, baby! 🏙️",
        "Hope you packed\na parachute",
        "Watch the birdie! 🐦",
        "That one had\nfrequent flyer miles",
        "Over your head?\nCouldn't tell 😏",
        "*chef's kiss* 👨‍🍳",
        "Roof! Oh wait,\nwe're outside",
    ]
    /// Muffled angry text shown during walkoff animation
    private static let walkoffMumbles: [String] = [
        "@#$%&!!",
        "*grumble grumble*",
        "...unbelievable...",
        "waste of my @$#& time",
        "*angry paddle waving*",
    ]

    // Shot mode buttons
    private var activeShotModes: DrillShotCalculator.ShotMode = []
    private var shotModeButtons: [SKNode] = []
    private var shotModeBgs: [SKShapeNode] = []
    private var shotModeTouch: UITouch?

    // Jump button
    private var jumpButton: SKNode!
    private var jumpButtonBg: SKShapeNode!
    private var jumpButtonLabel: SKLabelNode!

    // Jump state (player)
    private var playerJumpPhase: JumpPhase = .grounded
    private var playerJumpTimer: CGFloat = 0
    private var playerJumpCooldownTimer: CGFloat = 0
    private var playerJumpHeightBonus: CGFloat = 0

    // Sprite flipping for directional animations
    private var playerSpriteFlipped: Bool = false
    private var npcSpriteFlipped: Bool = false

    // Shot animation lock — prevents movePlayer() from overwriting one-shot animations
    private var playerShotAnimTimer: CGFloat = 0
    private var npcShotAnimTimer: CGFloat = 0
    private let shotAnimDuration: CGFloat = 0.40  // lock duration for shot animations

    // Swing timing: delay ball launch so contact aligns with mid-animation
    // Swing animations are ~10 frames at 0.06s = 0.60s. Mid-swing ≈ 0.15s delay.
    private let swingContactDelay: CGFloat = 0.15  // delay from animation start to ball launch
    private var pendingPlayerShot: PendingShot?
    private var pendingNPCShot: PendingShot?
    private var pendingServeShot: PendingServe?

    private struct PendingShot {
        let origin: CGPoint
        let target: CGPoint
        let power: CGFloat
        let arc: CGFloat
        let spin: CGFloat
        let topspin: CGFloat
        let smashFactor: CGFloat
        let isPlayer: Bool
        let targetNX: CGFloat
        let targetNY: CGFloat
        let accuracy: CGFloat
        var timer: CGFloat
    }

    private struct PendingServe {
        let origin: CGPoint
        let target: CGPoint
        let power: CGFloat
        let arc: CGFloat
        let spin: CGFloat
        let accuracy: CGFloat
        var timer: CGFloat
    }

    // Dink push animation
    private var playerDinkPushTimer: CGFloat = 0
    private var npcDinkPushTimer: CGFloat = 0
    private let dinkPushDuration: CGFloat = 0.25
    private let dinkKitchenThreshold: CGFloat = 0.30

    // Lateral lunge: load (crouch) → jump → land (recovery)
    enum LungePhase { case none, loading, jumping, landing }
    private var lungePhase: LungePhase = .none
    private var lungeTimer: CGFloat = 0
    private var lungeDirection: CGFloat = 0          // +1 right, -1 left
    private let lungeLoadDuration: CGFloat = 0.08    // crouch/load before jump
    private let lungeJumpDuration: CGFloat = 0.18    // airborne phase
    private let lungeLandDuration: CGFloat = 0.08    // can't move after landing (same as load)
    private let lungeDistance: CGFloat = 0.50         // half court width
    private let lungeJumpPeak: CGFloat = 10.0         // hop height in points
    private var prevJoystickMagnitude: CGFloat = 0   // for boundary-crossing detection

    // Movement guide arrows (court-painted directional hints)
    private var moveGuideBack: SKNode!
    private var moveGuideLeft: SKNode!
    private var moveGuideRight: SKNode!
    private var moveGuideForward: SKNode!
    private var wasLobbed: Bool = false  // tracks if current point had an unreachable lob

    // Split step animation (quick foot shuffle before opponent contacts ball)
    private var playerSplitStepPlayed: Bool = false
    private var npcSplitStepPlayed: Bool = false

    // Stamina
    private var stamina: CGFloat = P.maxStamina
    private var timeSinceLastSprint: CGFloat = 10

    // Footstep sound cadence
    private var footstepTimer: CGFloat = 0
    private let footstepInterval: CGFloat = 0.28
    private let footstepSprintInterval: CGFloat = 0.18

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

    // Shot landing markers (target, error margin, actual landing)
    private var shotMarkersNode: SKNode!
    private var lastShotTargetNX: CGFloat = 0.5
    private var lastShotTargetNY: CGFloat = 0.5

    // MARK: - Game State

    private let ballSim = DrillBallSimulation()
    private var npcAI: MatchAI!
    private let playerStats: PlayerStats

    // Player position in court space
    private var playerNX: CGFloat = 0.5
    private var playerNY: CGFloat = 0.08
    private var playerMoveSpeed: CGFloat = 0.6
    private var playerSprintSpeed: CGFloat = 1.0 // stat-based sprint multiplier
    private var lastUpdateTime: TimeInterval = 0
    private var previousBallNY: CGFloat = 0.5
    // Previous frame ball position for swept collision detection
    private var prevBallX: CGFloat = 0.5
    private var prevBallY: CGFloat = 0.5
    private var prevBallHeight: CGFloat = 0.0

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
    private let dbg = MatchDebugLogger.shared
    private let npcBoost: Int

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
        self.npcBoost = P.npcStatBoost(forBaseStatAverage: CGFloat(npc.stats.average))

        super.init(size: CGSize(width: AC.sceneWidth, height: AC.sceneHeight))
        self.scaleMode = .aspectFill
        self.anchorPoint = CGPoint(x: 0, y: 0)
        self.backgroundColor = UIColor(hex: "#2C3E50")

        let speedStat = CGFloat(playerStats.stat(.speed))
        let reflexesStat = CGFloat(playerStats.stat(.reflexes))
        let athleticism = (speedStat + reflexesStat) / 2.0 / 99.0
        playerMoveSpeed = P.baseMoveSpeed + (speedStat / 99.0) * P.maxMoveSpeedBonus
        // Sprint speed scales with athleticism: low stats = 50% boost, high stats = 150% boost
        playerSprintSpeed = 0.5 + athleticism * 1.0
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

        // Enable debug logging in dev mode
        dbg.isEnabled = isDevMode
        dbg.logMatchStart(
            player: player,
            playerStats: playerStats,
            npc: npc,
            npcStatBoost: npcBoost
        )

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

        // Shot landing markers container (above court lines, below characters)
        shotMarkersNode = SKNode()
        shotMarkersNode.zPosition = AC.ZPositions.courtLines + 0.5
        addChild(shotMarkersNode)

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

        // Jump button
        buildJumpButton()

        // High ball indicator
        buildHighBallIndicator()

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
        npcAI = MatchAI(npc: npc, playerDUPR: player.duprRating)

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
            ("Touch", .systemTeal, .touch),
            ("Lob", .systemIndigo, .lob),
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

    private func buildJumpButton() {
        let buttonRadius: CGFloat = 28
        let buttonX: CGFloat = 51  // left side, mirroring shot buttons on right
        let buttonY: CGFloat = 350

        jumpButton = SKNode()
        jumpButton.position = CGPoint(x: buttonX, y: buttonY)
        jumpButton.zPosition = 20
        jumpButton.name = "jumpButton"

        jumpButtonBg = SKShapeNode(circleOfRadius: buttonRadius)
        jumpButtonBg.fillColor = UIColor.systemCyan.withAlphaComponent(0.35)
        jumpButtonBg.strokeColor = UIColor.systemCyan.withAlphaComponent(0.6)
        jumpButtonBg.lineWidth = 2
        jumpButton.addChild(jumpButtonBg)

        jumpButtonLabel = SKLabelNode(text: "\u{25B2}")  // upward triangle
        jumpButtonLabel.fontName = "AvenirNext-Bold"
        jumpButtonLabel.fontSize = 22
        jumpButtonLabel.fontColor = .white
        jumpButtonLabel.verticalAlignmentMode = .center
        jumpButtonLabel.horizontalAlignmentMode = .center
        jumpButton.addChild(jumpButtonLabel)

        let subLabel = SKLabelNode(text: "JUMP")
        subLabel.fontName = "AvenirNext-Bold"
        subLabel.fontSize = 8
        subLabel.fontColor = UIColor.white.withAlphaComponent(0.7)
        subLabel.verticalAlignmentMode = .top
        subLabel.horizontalAlignmentMode = .center
        subLabel.position = CGPoint(x: 0, y: -12)
        jumpButton.addChild(subLabel)

        jumpButton.isHidden = true  // jump is now automatic
        addChild(jumpButton)
    }

    private func buildHighBallIndicator() {
        // Movement guide arrows — court-painted perspective arrows in 4 directions
        moveGuideBack = buildMoveGuideArrow(text: "GO BACK!", rotation: 0)
        moveGuideLeft = buildMoveGuideArrow(text: "GO LEFT!", rotation: .pi / 2)
        moveGuideRight = buildMoveGuideArrow(text: "GO RIGHT!", rotation: -.pi / 2)
        moveGuideForward = buildMoveGuideArrow(text: "MOVE UP!", rotation: .pi)
        addChild(moveGuideBack)
        addChild(moveGuideLeft)
        addChild(moveGuideRight)
        addChild(moveGuideForward)
    }

    /// Build a single court-painted movement guide arrow with text.
    /// Rotation 0 = pointing down (toward player baseline), .pi/2 = pointing left, etc.
    private func buildMoveGuideArrow(text: String, rotation: CGFloat) -> SKNode {
        let node = SKNode()
        node.zPosition = AC.ZPositions.courtLines + 1.5
        node.alpha = 0

        // Large triangle arrow (perspective-squished to look flat on court)
        let arrowPath = CGMutablePath()
        arrowPath.move(to: CGPoint(x: 0, y: 30))     // tip
        arrowPath.addLine(to: CGPoint(x: -22, y: -10))  // bottom-left
        arrowPath.addLine(to: CGPoint(x: 22, y: -10))   // bottom-right
        arrowPath.closeSubpath()

        let arrow = SKShapeNode(path: arrowPath)
        arrow.fillColor = UIColor.systemGreen.withAlphaComponent(0.45)
        arrow.strokeColor = UIColor.systemGreen.withAlphaComponent(0.85)
        arrow.lineWidth = 2.5
        arrow.zRotation = rotation
        node.addChild(arrow)

        // Text label
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 13
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        // Offset text behind the arrow tip direction
        let textOffset: CGFloat = -30
        label.position = CGPoint(
            x: sin(rotation) * textOffset,
            y: -cos(rotation) * textOffset
        )
        node.addChild(label)

        return node
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

    // MARK: - Shot Markers

    private func showShotMarkers(targetNX: CGFloat, targetNY: CGFloat, accuracy: CGFloat) {
        clearShotMarkers()
        lastShotTargetNX = targetNX
        lastShotTargetNY = targetNY

        let pos = CourtRenderer.courtPoint(nx: targetNX, ny: targetNY)
        let scale = CourtRenderer.perspectiveScale(ny: targetNY)

        // Error margin (orange, larger ellipse) — less accurate = bigger circle
        let errorRadius = max(6, (1.0 - accuracy) * 50) * scale
        let errorMarker = SKShapeNode(ellipseOf: CGSize(width: errorRadius * 2, height: errorRadius * 0.6))
        errorMarker.fillColor = UIColor.orange.withAlphaComponent(0.25)
        errorMarker.strokeColor = UIColor.orange.withAlphaComponent(0.6)
        errorMarker.lineWidth = 1.5
        errorMarker.position = pos
        errorMarker.name = "errorMargin"
        shotMarkersNode.addChild(errorMarker)

        // Target (yellow, small ellipse)
        let targetRadius: CGFloat = 5 * scale
        let targetMarker = SKShapeNode(ellipseOf: CGSize(width: targetRadius * 2, height: targetRadius * 0.6))
        targetMarker.fillColor = UIColor.yellow.withAlphaComponent(0.5)
        targetMarker.strokeColor = UIColor.yellow.withAlphaComponent(0.8)
        targetMarker.lineWidth = 1.5
        targetMarker.position = pos
        targetMarker.name = "targetMarker"
        shotMarkersNode.addChild(targetMarker)
    }

    private func showLandingSpot(courtX: CGFloat, courtY: CGFloat) {
        let pos = CourtRenderer.courtPoint(nx: courtX, ny: courtY)
        let scale = CourtRenderer.perspectiveScale(ny: courtY)

        // Actual landing spot (white dot)
        let radius: CGFloat = 4 * scale
        let landingMarker = SKShapeNode(ellipseOf: CGSize(width: radius * 2, height: radius * 0.6))
        landingMarker.fillColor = UIColor.white.withAlphaComponent(0.9)
        landingMarker.strokeColor = UIColor.white
        landingMarker.lineWidth = 1
        landingMarker.position = pos
        landingMarker.name = "landingSpot"
        shotMarkersNode.addChild(landingMarker)
    }

    private func clearShotMarkers() {
        shotMarkersNode?.removeAllChildren()
    }

    // MARK: - Match Flow

    private func startNextPoint() {
        rallyLength = 0
        ballSim.reset()
        ballNode.alpha = 0
        ballShadow.alpha = 0
        checkedFirstBounce = false
        clearShotMarkers()
        hideDebugPanel()
        hideNPCSpeech()
        playerServeStallTimer = 0
        serveStallTauntIndex = 0
        nextSnarkyTime = CGFloat.random(in: 5...10)
        nextPaceTime = 20
        npcIsPacing = false
        npcNode?.removeAction(forKey: "frustrationPace")

        // Reset jump state
        playerJumpPhase = .grounded
        playerJumpTimer = 0
        playerJumpCooldownTimer = 0
        playerJumpHeightBonus = 0
        playerSpriteFlipped = false
        npcSpriteFlipped = false
        playerDinkPushTimer = 0
        npcDinkPushTimer = 0
        playerSplitStepPlayed = false
        npcSplitStepPlayed = false
        playerShotAnimTimer = 0
        npcShotAnimTimer = 0
        lungePhase = .none
        lungeTimer = 0
        lungeDirection = 0
        pendingPlayerShot = nil
        pendingNPCShot = nil
        pendingServeShot = nil
        hideAllMoveGuides()
        wasLobbed = false

        // Recover stamina between points (scaled by stamina stat)
        let staminaStat = CGFloat(playerStats.stat(.stamina))
        let staminaRecovery: CGFloat = 10 + (staminaStat / 99.0) * 12
        stamina = min(P.maxStamina, stamina + staminaRecovery)
        npcAI.recoverBetweenPoints()

        // Reset NPC state for new point (clears shot count, pattern memory, kitchen approach)
        npcAI.reset(npcScore: npcScore, isServing: servingSide == .opponent)

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

        dbg.logPointStart(
            pointNum: totalPointsPlayed + 1,
            servingSide: servingSide,
            playerScore: playerScore,
            npcScore: npcScore,
            playerNX: playerNX,
            playerNY: playerNY,
            playerStamina: stamina,
            npcNX: npcAI.currentNX,
            npcNY: npcAI.currentNY,
            npcStamina: npcAI.stamina
        )
    }

    private func playerServe(from startPos: CGPoint, to endPos: CGPoint) {
        let dx = endPos.x - startPos.x
        let dy = endPos.y - startPos.y
        let distance = sqrt(dx * dx + dy * dy)

        guard dy > 0, distance >= P.serveSwipeMinDistance else { return }

        hideSwipeHint()
        hideNPCSpeech()
        playerServeStallTimer = 0
        serveStallTauntIndex = 0

        run(SoundManager.shared.skAction(for: .serveWhoosh))

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

        // Service box is 0.682 (kitchen) to 1.0 (baseline), midpoint ~0.84
        // Light swipe → mid-box, strong swipe → deep near baseline
        let baseTargetNY: CGFloat = 0.78 + rawPowerFactor * 0.15
        let targetNX = max(0.15, min(0.85, 0.5 + angleDeviation + scatterX))
        let targetNY = max(0.73, min(0.92, baseTargetNY + scatterY))

        // Power mode boosts serve speed
        let powerMultiplier: CGFloat = activeShotModes.contains(.power) ? 1.2 : 1.0
        let servePower = max(0.30, (0.10 + min(rawPowerFactor, 1.3) * 0.75) * powerMultiplier)

        // Physics-based arc: compute exact arc to land at target distance
        let serveDistNY = abs(targetNY - max(0, playerNY))
        let serveArc = DrillShotCalculator.arcToLandAt(
            distanceNY: serveDistNY,
            power: servePower,
            arcMargin: 1.15 // net clearance margin
        )

        // Drain stamina for active modes
        if activeShotModes.contains(.power) { stamina = max(0, stamina - P.maxStamina * 0.20) }
        if activeShotModes.contains(.focus) { stamina = max(0, stamina - P.maxStamina * 0.10) }

        dbg.logPlayerServe(
            originNX: playerNX, originNY: max(0, playerNY),
            targetNX: targetNX, targetNY: targetNY,
            power: servePower, arc: serveArc,
            scatter: scatter, modes: activeShotModes,
            stamina: stamina
        )

        // Play forehand swing animation immediately — ball launches at mid-swing
        playerAnimator.play(.forehand(isNear: true))
        playerShotAnimTimer = shotAnimDuration
        playerSpriteFlipped = false

        let serveAccuracy = 1.0 - scatter * 3
        pendingServeShot = PendingServe(
            origin: CGPoint(x: playerNX, y: max(0, playerNY)),
            target: CGPoint(x: targetNX, y: targetNY),
            power: servePower,
            arc: serveArc,
            spin: angleDeviation * 0.3,
            accuracy: max(0, serveAccuracy),
            timer: swingContactDelay
        )
    }

    private func npcServe() {
        // Ensure NPC is at correct serve position (right/left side behind baseline)
        npcAI.positionForServe(npcScore: npcScore)
        syncNPCPosition()

        let shot = npcAI.generateServe(npcScore: npcScore)
        let S = GameConstants.NPCStrategy.self

        // NPC double fault chance — base rate from stats + mode penalties for power/spin
        let consistencyStat = CGFloat(min(99, npc.stats.stat(.consistency) + npcBoost))
        let accuracyStat = CGFloat(min(99, npc.stats.stat(.accuracy) + npcBoost))
        let serveStat = (consistencyStat + accuracyStat) / 2.0
        let baseFaultRate = P.npcBaseServeFaultRate * (1.0 - serveStat / 99.0)

        // Power/spin modes increase fault risk — skilled NPCs manage it better
        let modes = npcAI.lastServeModes
        var rawPenalty: CGFloat = 0
        if modes.contains(.power) { rawPenalty += S.npcServePowerFaultPenalty }
        if modes.contains(.topspin) || modes.contains(.slice) { rawPenalty += S.npcServeSpinFaultPenalty }
        // aggressionControl reduces penalty: pow(1 - aC, 0.7)
        // 4.5 (aC 0.6) → 0.4^0.7 ≈ 0.49 → ~50% of raw penalty retained
        // 5.0 (aC 0.7) → 0.3^0.7 ≈ 0.39 → ~39% retained
        // 7.0 (aC 0.9) → 0.1^0.7 ≈ 0.20 → ~20% retained
        let controlFactor = pow(1.0 - npcAI.strategy.aggressionControl, S.npcServeControlExponent)
        let modePenalty = rawPenalty * controlFactor

        let faultRate = baseFaultRate + modePenalty
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

        dbg.logNPCServe(
            originNX: npcAI.currentNX, originNY: npcAI.currentNY,
            targetNX: targetNX, targetNY: targetNY,
            power: shot.power, arc: serveArc,
            faultRate: faultRate, isDoubleFault: isDoubleFault,
            modes: npcAI.lastServeModes,
            stamina: npcAI.stamina
        )

        // Play forehand swing animation — ball launches at mid-swing after delay
        npcAnimator.play(.forehand(isNear: false))
        npcShotAnimTimer = shotAnimDuration
        npcSpriteFlipped = false

        let launchOrigin = CGPoint(x: npcAI.currentNX, y: npcAI.currentNY)
        let launchTarget = CGPoint(x: targetNX, y: targetNY)
        let launchPower = shot.power
        let launchSpin = shot.spinCurve
        let serveAccuracy: CGFloat = isDoubleFault ? 0.0 : 0.8

        // Delay ball launch to mid-swing
        let delay = SKAction.wait(forDuration: TimeInterval(swingContactDelay))
        let launch = SKAction.run { [weak self] in
            guard let self else { return }
            self.phase = .playing
            self.ballSim.launch(
                from: launchOrigin, toward: launchTarget,
                power: launchPower, arc: serveArc,
                spin: launchSpin
            )
            self.ballSim.lastHitByPlayer = false
            self.previousBallNY = self.ballSim.courtY
            self.ballNode.alpha = 1
            self.ballShadow.alpha = 1
            self.showShotMarkers(targetNX: targetNX, targetNY: targetNY, accuracy: serveAccuracy)
        }
        self.run(.sequence([delay, launch]))
    }

    // MARK: - Point Resolution

    private enum PointResult {
        case playerWon
        case npcWon
    }

    private func resolvePoint(_ result: PointResult, reason: String) {
        run(SoundManager.shared.skAction(for: .pointChime))

        dbg.logPointEnd(
            result: result == .playerWon ? "PLAYER WON" : "NPC WON",
            reason: reason,
            rallyLength: rallyLength
        )

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

        run(SoundManager.shared.skAction(for: didPlayerWin ? .matchWin : .matchLose))
        if didPlayerWin {
        } else {
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

            // Check jump button
            if phase == .playing, let jb = jumpButton, hitTestButton(jb, at: pos, size: CGSize(width: 56, height: 56)) {
                initiatePlayerJump()
                continue
            }

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
            prevJoystickMagnitude = 0
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

        // Lunge trigger: joystick crosses boundary while mainly horizontal
        let prevMag = prevJoystickMagnitude
        prevJoystickMagnitude = joystickMagnitude
        if prevMag < 1.0 && joystickMagnitude >= 1.0
            && abs(dx) > abs(dy) * 1.5  // mainly horizontal
            && lungePhase == .none
            && playerJumpPhase == .grounded
            && phase == .playing {
            lungePhase = .loading
            lungeTimer = 0
            lungeDirection = dx > 0 ? 1.0 : -1.0
            playerSpriteFlipped = lungeDirection < 0
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
        prevJoystickMagnitude = 0
        joystickBase.position = joystickDefaultPosition
        joystickKnob.position = joystickDefaultPosition
        joystickBase.alpha = 0.4
        joystickKnob.alpha = 0.4
    }

    // MARK: - Shot Mode Toggles

    private func toggleShotMode(at index: Int) {
        typealias SM = DrillShotCalculator.ShotMode
        let modes: [SM] = [.power, .touch, .lob, .slice, .topspin, .angled, .focus]
        guard index < modes.count else { return }

        let mode = modes[index]
        if activeShotModes.contains(mode) {
            activeShotModes.remove(mode)
        } else {
            // Mutual exclusivity: power/touch/lob are mutually exclusive
            if mode == .power { activeShotModes.remove(.touch); activeShotModes.remove(.lob) }
            else if mode == .touch { activeShotModes.remove(.power); activeShotModes.remove(.lob) }
            else if mode == .lob { activeShotModes.remove(.power); activeShotModes.remove(.touch) }
            else if mode == .topspin { activeShotModes.remove(.slice) }
            else if mode == .slice { activeShotModes.remove(.topspin) }
            activeShotModes.insert(mode)
        }
        updateShotButtonVisuals()
        updateShotModeDots()
        run(SoundManager.shared.skAction(for: .buttonClick))
    }

    private func updateShotModeDots() {
        typealias SM = DrillShotCalculator.ShotMode
        let modes: [SM] = [.power, .touch, .lob, .slice, .topspin, .angled, .focus]
        let colors: [UIColor] = [.systemRed, .systemTeal, .systemIndigo, .systemPurple, .systemGreen, .systemOrange, .systemYellow]

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
        let modes: [SM] = [.power, .touch, .lob, .slice, .topspin, .angled, .focus]
        let colors: [UIColor] = [.systemRed, .systemTeal, .systemIndigo, .systemPurple, .systemGreen, .systemOrange, .systemYellow]

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
            updatePlayerJump(dt: dt)
            movePlayer(dt: dt)
            let prevBounces = ballSim.bounceCount
            previousBallNY = ballSim.courtY
            // Store previous ball position for swept collision detection
            prevBallX = ballSim.courtX
            prevBallY = ballSim.courtY
            prevBallHeight = ballSim.height
            ballSim.update(dt: dt)
            // Record first bounce position using sub-frame interpolation
            if ballSim.didBounceThisFrame && prevBounces == 0 {
                firstBounceCourtX = ballSim.lastBounceCourtX
                firstBounceCourtY = ballSim.lastBounceCourtY
                showLandingSpot(courtX: firstBounceCourtX, courtY: firstBounceCourtY)
            }
            // Log when ball crosses player's Y line (NPC shots heading toward player)
            if !ballSim.lastHitByPlayer && prevBallY > playerNY && ballSim.courtY <= playerNY {
                let xDist = abs(ballSim.courtX - playerNX)
                let positioningStat = CGFloat(playerStats.stat(.positioning))
                let hitbox = P.baseHitboxRadius + (positioningStat / 99.0) * P.positioningHitboxBonus
                dbg.logBallAtPlayerY(
                    ballX: ballSim.courtX, ballY: ballSim.courtY, ballHeight: ballSim.height,
                    playerNX: playerNX, playerNY: playerNY,
                    xDistance: xDist,
                    hitboxRadius: hitbox,
                    wouldBeInHitbox: xDist <= hitbox,
                    bounceCount: ballSim.bounceCount
                )
            }

            npcAI.playerPositionNX = playerNX
            npcAI.update(dt: dt, ball: ballSim)
            checkBallState()
            checkPlayerHit()
            checkNPCHit()

            // Shot animation lock timers (prevent movePlayer from overwriting swing animations)
            if playerShotAnimTimer > 0 { playerShotAnimTimer = max(0, playerShotAnimTimer - dt) }
            if npcShotAnimTimer > 0 { npcShotAnimTimer = max(0, npcShotAnimTimer - dt) }

            // Pending shot timers — launch ball at mid-swing
            tickPendingShots(dt: dt)

            // Dink push animation timers
            if playerDinkPushTimer > 0 { playerDinkPushTimer = max(0, playerDinkPushTimer - dt) }
            if npcDinkPushTimer > 0 { npcDinkPushTimer = max(0, npcDinkPushTimer - dt) }

            syncAllPositions()
            updatePlayerStaminaBar()
            updateNPCBossBar()
            updateMovementGuide()
            updateJumpButtonVisual()
            updateSplitSteps()

        case .serving:
            movePlayer(dt: dt)
            tickPendingServe(dt: dt)
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
            // NPC taunts when player stalls on serve → walkoff after ~5 min
            if servingSide == .player && !npcIsWalkingOff {
                playerServeStallTimer += dt
                nextSnarkyTime -= dt
                nextPaceTime -= dt

                // Frustration pacing every ~20 seconds
                if nextPaceTime <= 0 && !npcIsPacing {
                    npcFrustrationPace()
                    nextPaceTime = 20
                }

                // Walkoff warnings at escalating thresholds
                let thresholds: [CGFloat] = [120.0, 210.0, 280.0] // ~2min, ~3.5min, ~4.7min → walkoff at ~5min
                if serveStallTauntIndex < thresholds.count,
                   playerServeStallTimer >= thresholds[serveStallTauntIndex] {
                    let warning = Self.walkoffWarnings[serveStallTauntIndex]
                    showNPCSpeech(warning)
                    serveStallTauntIndex += 1
                    nextSnarkyTime = CGFloat.random(in: 5...10) // reset snarky timer after warning
                    // After final warning, trigger walkoff
                    if serveStallTauntIndex >= thresholds.count {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                            self?.triggerNPCWalkoff()
                        }
                    }
                } else if nextSnarkyTime <= 0 {
                    // Idle snarky comment every 5-10 seconds
                    let comment = Self.snarkyComments.randomElement() ?? "..."
                    showNPCSpeech(comment)
                    nextSnarkyTime = CGFloat.random(in: 5...10)
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

    // MARK: - Player Jump

    private func initiatePlayerJump() {
        guard playerJumpPhase == .grounded else { return }
        guard playerJumpCooldownTimer <= 0 else { return }
        guard stamina >= P.jumpMinStamina else { return }
        stamina -= P.jumpStaminaCost
        playerJumpPhase = .rising
        playerJumpTimer = 0
    }

    private func updatePlayerJump(dt: CGFloat) {
        // Cooldown
        if playerJumpCooldownTimer > 0 {
            playerJumpCooldownTimer = max(0, playerJumpCooldownTimer - dt)
        }

        guard playerJumpPhase != .grounded else {
            playerJumpHeightBonus = 0
            return
        }

        playerJumpTimer += dt
        let totalDuration = P.jumpDuration
        let riseEnd = totalDuration * P.jumpRiseFraction
        let hangEnd = riseEnd + totalDuration * P.jumpHangFraction

        switch playerJumpPhase {
        case .rising:
            let riseFraction = min(playerJumpTimer / riseEnd, 1.0)
            playerJumpHeightBonus = P.jumpHeightReachBonus * riseFraction
            if playerJumpTimer >= riseEnd {
                playerJumpPhase = .hanging
            }
        case .hanging:
            playerJumpHeightBonus = P.jumpHeightReachBonus
            if playerJumpTimer >= hangEnd {
                playerJumpPhase = .falling
            }
        case .falling:
            let fallStart = hangEnd
            let fallDuration = totalDuration * P.jumpFallFraction
            let fallFraction = min((playerJumpTimer - fallStart) / fallDuration, 1.0)
            playerJumpHeightBonus = P.jumpHeightReachBonus * (1.0 - fallFraction)
            if playerJumpTimer >= totalDuration {
                playerJumpPhase = .grounded
                playerJumpHeightBonus = 0
                playerJumpCooldownTimer = P.jumpCooldown
            }
        case .grounded:
            break
        }
    }

    /// Sprite Y-offset for player jump visual. Sine arc: 0 → peak → 0.
    private var playerJumpSpriteYOffset: CGFloat {
        guard playerJumpPhase != .grounded else { return 0 }
        let fraction = min(playerJumpTimer / P.jumpDuration, 1.0)
        return sin(fraction * .pi) * P.jumpSpriteYOffset
    }

    /// Lunge Y-offset: crouch down during load, hop up during jump, back to 0 on land.
    private var lungeSpriteYOffset: CGFloat {
        switch lungePhase {
        case .none:
            return 0
        case .loading:
            // Crouch down: dip below baseline
            let fraction = min(lungeTimer / lungeLoadDuration, 1.0)
            return -3.0 * fraction
        case .jumping:
            // Sine arc hop: start from slight crouch, peak at lungeJumpPeak
            let fraction = min(lungeTimer / lungeJumpDuration, 1.0)
            return sin(fraction * .pi) * lungeJumpPeak - 3.0 * (1.0 - fraction)
        case .landing:
            // Settle back to ground
            let fraction = min(lungeTimer / lungeLandDuration, 1.0)
            return -2.0 * (1.0 - fraction)
        }
    }

    private func tickLunge(dt: CGFloat) {
        lungeTimer += dt
        switch lungePhase {
        case .loading:
            // Crouching — show idle (bent knees visual via Y offset)
            playerAnimator.play(.idle(isNear: true))
            if lungeTimer >= lungeLoadDuration {
                lungePhase = .jumping
                lungeTimer = 0
                playerAnimator.play(.shuffle(isNear: true))
                playerSpriteFlipped = lungeDirection < 0
            }
        case .jumping:
            // Airborne — move sideways
            let lungeSpeed = lungeDistance / lungeJumpDuration
            playerNX += lungeDirection * lungeSpeed * dt
            playerNX = max(0.0, min(1.0, playerNX))
            if lungeTimer >= lungeJumpDuration {
                lungePhase = .landing
                lungeTimer = 0
                playerAnimator.play(.idle(isNear: true))
            }
        case .landing:
            // Frozen on landing
            if lungeTimer >= lungeLandDuration {
                lungePhase = .none
                lungeTimer = 0
            }
        case .none:
            break
        }
    }

    // MARK: - Movement Guide

    private func hideAllMoveGuides() {
        moveGuideBack.alpha = 0
        moveGuideLeft.alpha = 0
        moveGuideRight.alpha = 0
        moveGuideForward.alpha = 0
    }

    private func updateMovementGuide() {
        guard ballSim.isActive && !ballSim.lastHitByPlayer else {
            hideAllMoveGuides()
            return
        }
        guard ballSim.vy < 0 else {  // ball heading toward player
            hideAllMoveGuides()
            return
        }

        // Predict landing position using projectile equation:
        // 0 = h + vz*t - 0.5*g*t²  →  t = (vz + sqrt(vz² + 2*g*h)) / g
        let h = ballSim.height
        let vzCur = ballSim.vz
        let g = P.gravity
        let discriminant = vzCur * vzCur + 2 * g * h
        guard discriminant >= 0 else { hideAllMoveGuides(); return }

        let timeToLand = (vzCur + sqrt(discriminant)) / g
        guard timeToLand > 0.05 else { hideAllMoveGuides(); return }

        let landNX = ballSim.courtX + ballSim.vx * timeToLand
        let landNY = ballSim.courtY + ballSim.vy * timeToLand

        // Only guide on player's half
        guard landNY < 0.55 else { hideAllMoveGuides(); return }

        // How far player needs to move to reach landing spot
        let needDX = landNX - playerNX   // positive = need to go right
        let needDY = landNY - playerNY   // negative = need to go back (lower Y)

        // Threshold: only show if player needs to move a meaningful distance
        let lateralThreshold: CGFloat = 0.12
        let depthThreshold: CGFloat = 0.10

        let needLeft = needDX < -lateralThreshold
        let needRight = needDX > lateralThreshold
        let needBack = needDY < -depthThreshold
        let needForward = needDY > depthThreshold

        // DUPR-based anticipation: higher DUPR = show guide earlier
        // DUPR 2.0 → show at 0.6s before land, DUPR 8.0 → show at 1.5s before land
        let dupr = player.duprRating
        let anticipation: CGFloat = 0.6 + CGFloat((dupr - 2.0) / 6.0) * 0.9
        guard timeToLand < anticipation else { hideAllMoveGuides(); return }

        // Auto-jump for high balls within jump reach
        let ballSpeedY = abs(ballSim.vy)
        if ballSpeedY > 0.01 {
            let timeToPlayerY = abs(ballSim.courtY - playerNY) / ballSpeedY
            let heightAtPlayer = ballSim.height + ballSim.vz * timeToPlayerY
                - 0.5 * g * timeToPlayerY * timeToPlayerY
            let speedStat = CGFloat(playerStats.stat(.speed))
            let reflexesStat = CGFloat(playerStats.stat(.reflexes))
            let athleticism = (speedStat + reflexesStat) / 2.0 / 99.0
            let standingReach = P.baseHeightReach + athleticism * P.maxHeightReachBonus
            let jumpReach = standingReach + P.jumpHeightReachBonus

            if heightAtPlayer > standingReach && heightAtPlayer <= jumpReach && timeToPlayerY < 0.4 {
                initiatePlayerJump()
            }
            // Mark as lob if unreachable even with jump
            if heightAtPlayer > jumpReach {
                wasLobbed = true
            }
        }

        // Pulsing alpha — faster pulse as ball gets closer
        let urgency = 1.0 - min(timeToLand / anticipation, 1.0)
        let pulseSpeed: CGFloat = 4 + urgency * 6
        let pulse = (0.4 + urgency * 0.6) * (0.6 + 0.4 * abs(sin(CGFloat(CACurrentMediaTime()) * pulseSpeed)))

        // Position each arrow on the court relative to the player
        let pNY = max(0.0, playerNY)

        if needBack {
            let arrowNY = max(0.0, pNY - 0.12)
            let pos = CourtRenderer.courtPoint(nx: playerNX, ny: arrowNY)
            let scale = CourtRenderer.perspectiveScale(ny: arrowNY)
            moveGuideBack.position = pos
            moveGuideBack.setScale(scale)
            moveGuideBack.alpha = pulse
        } else {
            moveGuideBack.alpha = 0
        }

        if needForward {
            let arrowNY = min(0.48, pNY + 0.12)
            let pos = CourtRenderer.courtPoint(nx: playerNX, ny: arrowNY)
            let scale = CourtRenderer.perspectiveScale(ny: arrowNY)
            moveGuideForward.position = pos
            moveGuideForward.setScale(scale)
            moveGuideForward.alpha = pulse
        } else {
            moveGuideForward.alpha = 0
        }

        if needLeft {
            let arrowNX = max(0.05, playerNX - 0.14)
            let pos = CourtRenderer.courtPoint(nx: arrowNX, ny: pNY)
            let scale = CourtRenderer.perspectiveScale(ny: pNY)
            moveGuideLeft.position = pos
            moveGuideLeft.setScale(scale)
            moveGuideLeft.alpha = pulse
        } else {
            moveGuideLeft.alpha = 0
        }

        if needRight {
            let arrowNX = min(0.95, playerNX + 0.14)
            let pos = CourtRenderer.courtPoint(nx: arrowNX, ny: pNY)
            let scale = CourtRenderer.perspectiveScale(ny: pNY)
            moveGuideRight.position = pos
            moveGuideRight.setScale(scale)
            moveGuideRight.alpha = pulse
        } else {
            moveGuideRight.alpha = 0
        }
    }

    private func updateJumpButtonVisual() {
        let canJump = playerJumpPhase == .grounded
            && playerJumpCooldownTimer <= 0
            && stamina >= P.jumpMinStamina
        jumpButtonBg.fillColor = canJump
            ? UIColor.systemCyan.withAlphaComponent(0.35)
            : UIColor.gray.withAlphaComponent(0.2)
        jumpButtonBg.strokeColor = canJump
            ? UIColor.systemCyan.withAlphaComponent(0.6)
            : UIColor.gray.withAlphaComponent(0.3)
        jumpButtonLabel.fontColor = canJump ? .white : UIColor.white.withAlphaComponent(0.3)

        // Flash when airborne
        if playerJumpPhase != .grounded {
            jumpButtonBg.fillColor = UIColor.systemCyan.withAlphaComponent(0.7)
            jumpButtonBg.strokeColor = UIColor.systemCyan
        }
    }

    // MARK: - Split Step

    /// Trigger split step animation when the opponent is about to contact the ball.
    /// Player split-steps when NPC is about to hit; NPC split-steps when player is about to hit.
    private func updateSplitSteps() {
        guard ballSim.isActive else { return }

        let leadTime = SpriteSheetAnimator.splitStepRunDuration // 0.32s

        // Player split step: ball heading toward NPC (player hit it), NPC about to return
        if ballSim.lastHitByPlayer {
            // Reset NPC split step flag (ball now going other way)
            npcSplitStepPlayed = false

            if !playerSplitStepPlayed {
                let ballSpeed = abs(ballSim.vy)
                if ballSpeed > 0.01 {
                    let distToNPC = abs(ballSim.courtY - npcAI.currentNY)
                    let timeToContact = distToNPC / ballSpeed
                    // Only play split step if player is standing still and not in shot animation
                    if timeToContact <= leadTime && timeToContact > 0 && joystickMagnitude < 0.1 && playerShotAnimTimer <= 0 {
                        playerAnimator.playSplitStep()
                        playerSpriteFlipped = false
                        playerSplitStepPlayed = true
                    }
                }
            }
        } else {
            // Ball heading toward player (NPC hit it), player about to return
            // Reset player split step flag
            playerSplitStepPlayed = false

            if !npcSplitStepPlayed {
                let ballSpeed = abs(ballSim.vy)
                if ballSpeed > 0.01 {
                    let distToPlayer = abs(ballSim.courtY - playerNY)
                    let timeToContact = distToPlayer / ballSpeed
                    if timeToContact <= leadTime && timeToContact > 0 && npcShotAnimTimer <= 0 {
                        npcAnimator.playSplitStep()
                        npcSpriteFlipped = false
                        npcSplitStepPlayed = true
                    }
                }
            }
        }
    }

    // MARK: - Player Movement

    private func movePlayer(dt: CGFloat) {
        let canChangeAnim = playerShotAnimTimer <= 0

        // Tick active lunge regardless of joystick state
        if lungePhase != .none {
            tickLunge(dt: dt)
            return
        }

        guard joystickMagnitude > 0.1 else {
            if canChangeAnim { playerAnimator.play(.idle(isNear: true)) }
            footstepTimer = 0
            timeSinceLastSprint += dt
            if timeSinceLastSprint >= P.staminaRecoveryDelay {
                stamina = min(P.maxStamina, stamina + P.staminaRecoveryRate * dt)
            }
            return
        }

        // Speed scales linearly from 0 to full (base + sprint) based on distance from center
        let mag = min(joystickMagnitude, 1.0)
        let maxSpeed = playerMoveSpeed * (1.0 + playerSprintSpeed)
        var speed = maxSpeed * mag

        // Jump air mobility penalty
        if playerJumpPhase != .grounded {
            speed *= P.jumpAirMobilityFactor
        }

        let staminaPct = stamina / P.maxStamina
        // Sprint zone: outer 40% of circle (magnitude > 0.6) drains stamina
        let isSprinting = mag > 0.6 && staminaPct > 0.10
        if isSprinting {
            if staminaPct < 0.50 { speed *= 0.75 }
            stamina = max(0, stamina - P.sprintDrainRate * mag * dt)
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

        // Movement animation: direction-aware sprint vs shuffle
        let dx = joystickDirection.dx
        let dy = joystickDirection.dy
        let isMainlyHorizontal = abs(dx) > abs(dy)

        // Normal movement (lunge is handled by tickLunge above)
        playerNX += joystickDirection.dx * speed * dt
        playerNY += joystickDirection.dy * speed * dt

        // Clamp: player can move anywhere on their side + up to kitchen line
        playerNX = max(0.0, min(1.0, playerNX))
        playerNY = max(-0.05, min(0.48 - P.playerPositioningOffset, playerNY))

        if canChangeAnim && lungePhase == .none {
            if isSprinting {
                if isMainlyHorizontal {
                    // Horizontal sprint: runSide (base = running right, flip for left)
                    playerAnimator.play(.runSide)
                    playerSpriteFlipped = dx < 0
                } else if dy > 0 {
                    // Forward sprint (toward net): run forward
                    playerAnimator.play(.run(isNear: true))
                    playerSpriteFlipped = false
                } else {
                    // Backward sprint: fast shuffle (don't turn around)
                    playerAnimator.play(.shuffle(isNear: true))
                    playerSpriteFlipped = false
                }
            } else {
                // Non-sprint: shuffle in all directions
                playerAnimator.play(.shuffle(isNear: true))
                if abs(dx) > 0.3 {
                    playerSpriteFlipped = dx < 0 // flip when shuffling left
                } else {
                    playerSpriteFlipped = false
                }
            }
        }

        // Footstep sounds on cadence timer
        footstepTimer += dt
        let interval = isSprinting ? footstepSprintInterval : footstepInterval
        if footstepTimer >= interval {
            footstepTimer = 0
            let soundID: SoundManager.SoundID = isSprinting ? .footstepSprint : .footstep
            run(SoundManager.shared.skAction(for: soundID))
        }
    }

    // MARK: - Pending Shot Timing

    /// Tick pending player/NPC shots — launches ball at mid-swing
    private func tickPendingShots(dt: CGFloat) {
        if var shot = pendingPlayerShot {
            shot.timer -= dt
            if shot.timer <= 0 {
                ballSim.launch(
                    from: shot.origin, toward: shot.target,
                    power: shot.power, arc: shot.arc,
                    spin: shot.spin, topspin: shot.topspin
                )
                ballSim.smashFactor = shot.smashFactor
                ballSim.lastHitByPlayer = true
                previousBallNY = ballSim.courtY
                checkedFirstBounce = false
                ballNode.alpha = 1
                ballShadow.alpha = 1
                showShotMarkers(targetNX: shot.targetNX, targetNY: shot.targetNY, accuracy: shot.accuracy)
                pendingPlayerShot = nil
            } else {
                pendingPlayerShot = shot
            }
        }

        if var shot = pendingNPCShot {
            shot.timer -= dt
            if shot.timer <= 0 {
                ballSim.launch(
                    from: shot.origin, toward: shot.target,
                    power: shot.power, arc: shot.arc,
                    spin: shot.spin, topspin: shot.topspin
                )
                ballSim.smashFactor = shot.smashFactor
                ballSim.lastHitByPlayer = false
                previousBallNY = ballSim.courtY
                checkedFirstBounce = false
                ballNode.alpha = 1
                ballShadow.alpha = 1
                showShotMarkers(targetNX: shot.targetNX, targetNY: shot.targetNY, accuracy: shot.accuracy)
                pendingNPCShot = nil
            } else {
                pendingNPCShot = shot
            }
        }
    }

    /// Tick pending serve — launches ball at mid-swing
    private func tickPendingServe(dt: CGFloat) {
        if var serve = pendingServeShot {
            serve.timer -= dt
            if serve.timer <= 0 {
                phase = .playing
                ballSim.launch(
                    from: serve.origin, toward: serve.target,
                    power: serve.power, arc: serve.arc,
                    spin: serve.spin
                )
                ballSim.lastHitByPlayer = true
                previousBallNY = ballSim.courtY
                ballNode.alpha = 1
                ballShadow.alpha = 1
                showShotMarkers(targetNX: serve.target.x, targetNY: serve.target.y, accuracy: serve.accuracy)
                pendingServeShot = nil
            } else {
                pendingServeShot = serve
            }
        }
    }

    // MARK: - Swept Collision

    /// Find the minimum 3D distance from the ball's path segment (prev→curr) to a target point.
    /// Uses closest-point-on-segment in 2D, then evaluates interpolated height at that point.
    /// Prevents fast balls from tunneling through the hitbox between frames.
    private func sweptBallDistance(
        prevX: CGFloat, prevY: CGFloat, prevH: CGFloat,
        currX: CGFloat, currY: CGFloat, currH: CGFloat,
        targetX: CGFloat, targetY: CGFloat,
        heightReach: CGFloat
    ) -> CGFloat {
        let segDX = currX - prevX
        let segDY = currY - prevY
        let segLenSq = segDX * segDX + segDY * segDY

        let t: CGFloat
        if segLenSq < 0.000001 {
            // Ball barely moved — use current position
            t = 1.0
        } else {
            // Project target onto segment: t = dot(target-prev, seg) / |seg|²
            let toTargetX = targetX - prevX
            let toTargetY = targetY - prevY
            t = max(0, min(1, (toTargetX * segDX + toTargetY * segDY) / segLenSq))
        }

        // Interpolate ball position at closest parameter
        let closestX = prevX + t * segDX
        let closestY = prevY + t * segDY
        let closestH = prevH + t * (currH - prevH)

        let dx = closestX - targetX
        let dy = closestY - targetY
        let excessHeight = max(0, closestH - heightReach)
        return sqrt(dx * dx + dy * dy + excessHeight * excessHeight)
    }

    // MARK: - Hit Detection

    private func checkPlayerHit() {
        guard ballSim.isActive && !ballSim.lastHitByPlayer else { return }
        guard ballSim.bounceCount < 2 else { return }

        let positioningStat = CGFloat(playerStats.stat(.positioning))
        let hitboxRadius = P.baseHitboxRadius + (positioningStat / 99.0) * P.positioningHitboxBonus

        // Two-bounce rule: during serve return (rally 0) and 3rd shot (rally 1),
        // the ball MUST bounce before being hit. Instead of penalizing a "volley fault",
        // simply ignore the ball — the player's avatar auto-moves and can't avoid it.
        if rallyLength < 2 && ballSim.bounceCount == 0 { return }

        // 3D hitbox: height reach based on athleticism (speed + reflexes) + jump bonus
        let speedStat = CGFloat(playerStats.stat(.speed))
        let reflexesStat = CGFloat(playerStats.stat(.reflexes))
        let athleticism = (speedStat + reflexesStat) / 2.0 / 99.0
        let heightReach = P.baseHeightReach + athleticism * P.maxHeightReachBonus + playerJumpHeightBonus
        let excessHeight_dbg = max(0, ballSim.height - heightReach)

        // Swept collision: find closest point on ball's path segment to player
        // This prevents fast balls from tunneling through the hitbox between frames
        let dist = sweptBallDistance(
            prevX: prevBallX, prevY: prevBallY, prevH: prevBallHeight,
            currX: ballSim.courtX, currY: ballSim.courtY, currH: ballSim.height,
            targetX: playerNX, targetY: playerNY, heightReach: heightReach
        )

        // Also compute simple 2D distance for logging
        let dx_dbg = ballSim.courtX - playerNX
        let dy_dbg = ballSim.courtY - playerNY
        let dist2D_dbg = sqrt(dx_dbg * dx_dbg + dy_dbg * dy_dbg)

        let ballSpeed_dbg = sqrt(ballSim.vx * ballSim.vx + ballSim.vy * ballSim.vy)

        // Log ball approaching player when it's within 2x hitbox (to see near-misses too)
        if dist <= hitboxRadius * 2.0 {
            dbg.logBallApproachingPlayer(
                ballX: ballSim.courtX, ballY: ballSim.courtY, ballHeight: ballSim.height,
                ballVX: ballSim.vx, ballVY: ballSim.vy, ballVZ: ballSim.vz,
                ballSpeed: ballSpeed_dbg, ballSpin: ballSim.spinCurve, ballTopspin: ballSim.topspinFactor,
                bounceCount: ballSim.bounceCount,
                playerNX: playerNX, playerNY: playerNY,
                hitboxRadius: hitboxRadius,
                dist2D: dist2D_dbg,
                dist3D: dist,
                heightReach: heightReach,
                excessHeight: excessHeight_dbg,
                isInHitbox: dist <= hitboxRadius
            )
        }

        guard dist <= hitboxRadius else { return }

        rallyLength += 1

        // Power mode stamina drain
        if activeShotModes.contains(.power) {
            stamina = max(0, stamina - P.maxStamina * 0.20)
        }

        let ballFromLeft = ballSim.courtX < playerNX
        let staminaPct = stamina / P.maxStamina

        // Save shot context for NPC shot quality assessment
        npcAI.lastPlayerShotModes = activeShotModes
        npcAI.lastPlayerHitBallHeight = ballSim.height
        // Compute player-side difficulty using ball speed / distance
        let pBallSpeed = sqrt(ballSim.vx * ballSim.vx + ballSim.vy * ballSim.vy)
        let pMaxSpeed = P.baseShotSpeed + 2.0 * (P.maxShotSpeed - P.baseShotSpeed)
        let pSpeedFrac = max(0, min(1, (pBallSpeed - P.baseShotSpeed) / (pMaxSpeed - P.baseShotSpeed)))
        let pDist = sqrt((ballSim.courtX - playerNX) * (ballSim.courtX - playerNX)
                       + (ballSim.courtY - playerNY) * (ballSim.courtY - playerNY))
        let pStretch = min(pDist / hitboxRadius, 1.0)
        npcAI.lastPlayerHitDifficulty = pSpeedFrac * 0.5 + pStretch * 0.5

        var shot = DrillShotCalculator.calculatePlayerShot(
            stats: playerStats,
            ballApproachFromLeft: ballFromLeft,
            drillType: .baselineRally,
            ballHeight: ballSim.height,
            ballHeightAtNet: ballSim.heightAtNetCrossing,
            courtNY: playerNY,
            modes: activeShotModes,
            staminaFraction: staminaPct
        )

        // --- Net fault: low-stat players hit into the net ---
        let accuracyStat_nf = CGFloat(playerStats.stat(.accuracy))
        let consistencyStat_nf = CGFloat(playerStats.stat(.consistency))
        let focusStat_nf = CGFloat(playerStats.stat(.focus))
        let avgControl_nf = (accuracyStat_nf + consistencyStat_nf + focusStat_nf) / 3.0
        let netFaultRate = PB.netFaultBaseRate * pow(1.0 - avgControl_nf / 99.0, 1.5)
        let netFaultRoll = CGFloat.random(in: 0...1)
        let isNetFault = netFaultRoll < netFaultRate
        if isNetFault {
            ballSim.skipNetCorrection = true
            shot.arc *= 0.15
        }

        dbg.logPlayerHit(
            modes: activeShotModes,
            stamina: stamina,
            targetNX: shot.targetNX,
            targetNY: shot.targetNY,
            power: shot.power,
            arc: shot.arc,
            spinCurve: shot.spinCurve,
            topspinFactor: shot.topspinFactor,
            netFaultRate: netFaultRate,
            isNetFault: isNetFault
        )

        // Pick animation based on shot context:
        // - Smash: jumping (lobbed) or high overhead
        // - Volley: ball hasn't bounced and no jump needed — show swing unless touch mode
        // - Dink: at kitchen without power — push motion
        // - Normal: forehand/backhand swing
        let animState: CharacterAnimationState
        let isVolley = ballSim.bounceCount == 0 && playerJumpPhase == .grounded
        if (playerJumpPhase != .grounded || shot.smashFactor > 0) && !activeShotModes.contains(.touch) {
            animState = .smash(isNear: true)
        } else if isVolley && activeShotModes.contains(.touch) {
            // Touch volley: soft dink push (no swing animation)
            animState = .run(isNear: true)
            playerDinkPushTimer = dinkPushDuration
        } else if isVolley {
            // Volley: show swing animation (forehand/backhand)
            animState = shot.shotType == .forehand
                ? .forehand(isNear: true) : .backhand(isNear: true)
        } else if playerNY > dinkKitchenThreshold && !activeShotModes.contains(.power) {
            // Dink at kitchen: use run animation + push motion
            animState = .run(isNear: true)
            playerDinkPushTimer = dinkPushDuration
        } else {
            animState = shot.shotType == .forehand
                ? .forehand(isNear: true) : .backhand(isNear: true)
        }
        playerAnimator.play(animState)
        playerShotAnimTimer = shotAnimDuration
        playerSpriteFlipped = false

        // Sound + haptic
        let isSmashShot = (playerJumpPhase != .grounded || shot.smashFactor > 0) && !activeShotModes.contains(.touch)
        if isSmashShot {
            run(SoundManager.shared.skAction(for: .paddleHitSmash))
        } else {
            run(SoundManager.shared.skAction(for: .paddleHit))
        }

        // Hide ball during swing wind-up (it reappears on launch)
        ballSim.isActive = false
        ballNode.alpha = 0
        ballShadow.alpha = 0

        // Push player shot X to NPC pattern memory (keep last 5)
        npcAI.playerShotHistory.append(shot.targetNX)
        if npcAI.playerShotHistory.count > 5 {
            npcAI.playerShotHistory.removeFirst()
        }

        // Defer ball launch to mid-swing
        pendingPlayerShot = PendingShot(
            origin: CGPoint(x: playerNX, y: playerNY),
            target: CGPoint(x: shot.targetNX, y: shot.targetNY),
            power: shot.power,
            arc: shot.arc,
            spin: shot.spinCurve,
            topspin: shot.topspinFactor,
            smashFactor: shot.smashFactor,
            isPlayer: true,
            targetNX: shot.targetNX,
            targetNY: shot.targetNY,
            accuracy: shot.accuracy,
            timer: swingContactDelay
        )
    }

    private func checkNPCHit() {
        guard ballSim.isActive && ballSim.lastHitByPlayer else { return }
        guard ballSim.bounceCount < 2 else { return }

        // Two-bounce rule: NPC must let the ball bounce on return and 3rd shot
        if rallyLength < 2 && ballSim.bounceCount == 0 { return }

        // Compute NPC hitbox metrics for logging (mirrors shouldSwing logic)
        let npcSpeedStat = CGFloat(min(99, npc.stats.stat(.speed) + npcBoost))
        let npcReflexesStat = CGFloat(min(99, npc.stats.stat(.reflexes) + npcBoost))
        let npcAthleticism = (npcSpeedStat + npcReflexesStat) / 2.0 / 99.0
        let npcHeightReach = P.baseHeightReach + npcAthleticism * P.maxHeightReachBonus + npcAI.jumpHeightBonus
        let npcExcessH = max(0, ballSim.height - npcHeightReach)
        let npcDX = ballSim.courtX - npcAI.currentNX
        let npcDY = ballSim.courtY - npcAI.currentNY
        let npcDist = sqrt(npcDX * npcDX + npcDY * npcDY + npcExcessH * npcExcessH)
        let npcBallSpeed = sqrt(ballSim.vx * ballSim.vx + ballSim.vy * ballSim.vy)
        let npcInHitbox = npcDist <= npcAI.hitboxRadius

        // Log when ball is near NPC (within 2x hitbox)
        if npcDist <= npcAI.hitboxRadius * 2.0 {
            dbg.logBallApproachingNPC(
                ballX: ballSim.courtX, ballY: ballSim.courtY, ballHeight: ballSim.height,
                ballVX: ballSim.vx, ballVY: ballSim.vy, ballVZ: ballSim.vz,
                ballSpeed: npcBallSpeed, ballSpin: ballSim.spinCurve, ballTopspin: ballSim.topspinFactor,
                bounceCount: ballSim.bounceCount,
                npcNX: npcAI.currentNX, npcNY: npcAI.currentNY,
                hitboxRadius: npcAI.hitboxRadius,
                dist: npcDist,
                heightReach: npcHeightReach,
                excessHeight: npcExcessH,
                isInHitbox: npcInHitbox
            )
        }

        if npcAI.shouldSwing(ball: ballSim) {
            // Pre-select modes so error type is context-aware
            npcAI.preselectModes(ball: ballSim)

            // Capture debug info before the roll
            let errDbg = npcAI.computeErrorDebugInfo(ball: ballSim)

            // Check for unforced error before generating the return
            if npcAI.shouldMakeError(ball: ballSim) {
                npcErrors += 1
                rallyLength += 1
                // Animate the whiff
                let ballFromLeft = ballSim.courtX < npcAI.currentNX
                npcAnimator.play(ballFromLeft ? .backhand(isNear: false) : .forehand(isNear: false))

                // Context-aware error type based on shot attempted
                let errType = npcAI.errorType(for: npcAI.lastShotModes)

                dbg.logNPCError(
                    errorRate: errDbg.errorRate,
                    baseError: errDbg.baseError,
                    pressureError: errDbg.pressureError,
                    shotDifficulty: errDbg.shotDifficulty,
                    speedFrac: errDbg.speedFrac,
                    spinPressure: errDbg.spinPressure,
                    stretchFrac: errDbg.stretchFrac,
                    stretchMultiplier: errDbg.stretchMultiplier,
                    staminaPct: errDbg.staminaPct,
                    shotQuality: errDbg.shotQuality,
                    duprMultiplier: errDbg.duprMultiplier,
                    errorType: errType,
                    modes: npcAI.lastShotModes
                )

                switch errType {
                case .net:
                    ballSim.launch(
                        from: CGPoint(x: npcAI.currentNX, y: npcAI.currentNY),
                        toward: CGPoint(x: CGFloat.random(in: 0.2...0.8), y: 0.3),
                        power: 0.25,
                        arc: 0.02,
                        spin: 0
                    )
                case .long:
                    ballSim.launch(
                        from: CGPoint(x: npcAI.currentNX, y: npcAI.currentNY),
                        toward: CGPoint(x: CGFloat.random(in: 0.2...0.8), y: CGFloat.random(in: -0.10...0.05)),
                        power: 0.8,
                        arc: 0.15,
                        spin: 0
                    )
                case .wide:
                    let wideTarget = Bool.random() ? CGFloat.random(in: -0.2...0.05) : CGFloat.random(in: 0.95...1.2)
                    ballSim.launch(
                        from: CGPoint(x: npcAI.currentNX, y: npcAI.currentNY),
                        toward: CGPoint(x: wideTarget, y: CGFloat.random(in: 0.0...0.20)),
                        power: 0.7,
                        arc: 0.12,
                        spin: 0
                    )
                }
                ballSim.lastHitByPlayer = false
                previousBallNY = ballSim.courtY
                checkedFirstBounce = false
                return
            }

            rallyLength += 1
            let shot = npcAI.generateShot(ball: ballSim)

            dbg.logNPCHit(
                modes: npcAI.lastShotModes,
                stamina: npcAI.stamina,
                targetNX: shot.targetNX,
                targetNY: shot.targetNY,
                power: shot.power,
                arc: shot.arc,
                spinCurve: shot.spinCurve,
                topspinFactor: shot.topspinFactor,
                errorRate: errDbg.errorRate
            )

            // Pick animation based on shot context (mirrors player logic)
            let npcAnimState: CharacterAnimationState
            let npcIsVolley = ballSim.bounceCount == 0 && npcAI.jumpPhase == .grounded
            if (npcAI.jumpPhase != .grounded || shot.smashFactor > 0) && !npcAI.lastShotModes.contains(.touch) {
                npcAnimState = .smash(isNear: false)
            } else if npcIsVolley && npcAI.lastShotModes.contains(.touch) {
                npcAnimState = .run(isNear: false)
                npcDinkPushTimer = dinkPushDuration
            } else if npcIsVolley {
                npcAnimState = shot.shotType == .forehand
                    ? .forehand(isNear: false) : .backhand(isNear: false)
            } else if npcAI.currentNY < (1.0 - dinkKitchenThreshold) && !npcAI.lastShotModes.contains(.power) {
                npcAnimState = .run(isNear: false)
                npcDinkPushTimer = dinkPushDuration
            } else {
                npcAnimState = shot.shotType == .forehand
                    ? .forehand(isNear: false) : .backhand(isNear: false)
            }
            npcAnimator.play(npcAnimState)
            npcShotAnimTimer = shotAnimDuration
            npcSpriteFlipped = false

            run(SoundManager.shared.skAction(for: .paddleHitDistant))

            // Hide ball during swing wind-up (it reappears on launch)
            ballSim.isActive = false
            ballNode.alpha = 0
            ballShadow.alpha = 0

            // Defer ball launch to mid-swing
            pendingNPCShot = PendingShot(
                origin: CGPoint(x: npcAI.currentNX, y: npcAI.currentNY),
                target: CGPoint(x: shot.targetNX, y: shot.targetNY),
                power: shot.power,
                arc: shot.arc,
                spin: shot.spinCurve,
                topspin: shot.topspinFactor,
                smashFactor: shot.smashFactor,
                isPlayer: false,
                targetNX: shot.targetNX,
                targetNY: shot.targetNY,
                accuracy: shot.accuracy,
                timer: swingContactDelay
            )
        }
    }

    // MARK: - Ball State

    private func checkBallState() {
        guard ballSim.isActive else { return }

        // Net collision
        if ballSim.checkNetCollision(previousY: previousBallNY) {
            dbg.logNetCollision(
                ballHeight: ballSim.height,
                previousBallNY: previousBallNY,
                currentBallNY: ballSim.courtY,
                lastHitByPlayer: ballSim.lastHitByPlayer
            )
            let lastHitter: PointResult = ballSim.lastHitByPlayer ? .npcWon : .playerWon
            if ballSim.lastHitByPlayer {
                playerErrors += 1
            } else {
                npcErrors += 1
            }
            let h = String(format: "%.3f", ballSim.height)
            run(SoundManager.shared.skAction(for: .netThud))
            showIndicator("Net!", color: .systemRed)
            resolvePoint(lastHitter, reason: "Net collision (h=\(h), prevY=\(String(format: "%.2f", previousBallNY)))")
            return
        }

        // Bounce-time line call: check on first bounce using interpolated position
        if ballSim.didBounceThisFrame && !checkedFirstBounce {
            checkedFirstBounce = true
            run(SoundManager.shared.skAction(for: .ballBounce))

            dbg.logBallBounce(
                bounceNum: 1,
                courtX: firstBounceCourtX, courtY: firstBounceCourtY,
                isOut: ballSim.isLandingOut,
                isKitchenFault: rallyLength == 0 && (
                    (ballSim.lastHitByPlayer && firstBounceCourtY >= 0.5 && firstBounceCourtY < 0.682) ||
                    (!ballSim.lastHitByPlayer && firstBounceCourtY <= 0.5 && firstBounceCourtY > 0.318)
                )
            )

            // Out of bounds — ball landed outside the court lines (exact 0-1 boundaries)
            if ballSim.isLandingOut {
                let lastHitter: PointResult = ballSim.lastHitByPlayer ? .npcWon : .playerWon
                if ballSim.lastHitByPlayer {
                    playerErrors += 1
                } else {
                    npcErrors += 1
                }
                let bx = String(format: "%.3f", firstBounceCourtX)
                let by = String(format: "%.3f", firstBounceCourtY)
                showIndicator("Out!", color: .systemOrange)
                resolvePoint(lastHitter, reason: "Out of bounds (bounce x=\(bx), y=\(by))")
                return
            }

            // Serve kitchen fault — serve must land past kitchen line on receiver's side
            if rallyLength == 0 {
                let kitchenNear: CGFloat = 0.318
                let kitchenFar: CGFloat = 0.682
                if ballSim.lastHitByPlayer && firstBounceCourtY >= 0.5 && firstBounceCourtY < kitchenFar {
                    playerErrors += 1
                    showIndicator("Kitchen Fault!", color: .systemRed)
                    resolvePoint(.npcWon, reason: "Serve in kitchen (y=\(String(format: "%.3f", firstBounceCourtY)))")
                    return
                }
                if !ballSim.lastHitByPlayer && firstBounceCourtY <= 0.5 && firstBounceCourtY > kitchenNear {
                    npcErrors += 1
                    showIndicator("Kitchen Fault!", color: .systemRed)
                    resolvePoint(.playerWon, reason: "NPC serve in kitchen (y=\(String(format: "%.3f", firstBounceCourtY)))")
                    return
                }
            }
        }

        // Double bounce — ball bounced twice, point is over
        if ballSim.isDoubleBounce {
            dbg.logDoubleBounce(courtY: ballSim.lastBounceCourtY, lastHitByPlayer: ballSim.lastHitByPlayer, bounceCount: ballSim.bounceCount)
            let bounceY = ballSim.lastBounceCourtY
            let side = bounceY < 0.5 ? "player" : "NPC"
            if bounceY < 0.5 {
                // Ball double-bounced on player's side
                if ballSim.lastHitByPlayer {
                    playerErrors += 1
                    showIndicator("Out!", color: .systemOrange)
                } else {
                    if rallyLength <= 1 { npcAces += 1 } else { npcWinners += 1 }
                    showIndicator(wasLobbed ? "Lobbed!" : "Miss!", color: .systemYellow)
                    if wasLobbed {
                        showNPCSpeech(Self.lobTaunts.randomElement() ?? "See ya!")
                    }
                }
                resolvePoint(.npcWon, reason: "Double bounce on \(side) side")
            } else {
                // Ball double-bounced on NPC's side
                if ballSim.lastHitByPlayer {
                    if rallyLength <= 1 { playerAces += 1 } else { playerWinners += 1 }
                    showIndicator("Winner!", color: .systemGreen)
                } else {
                    npcErrors += 1
                    showIndicator("Out!", color: .systemOrange)
                }
                resolvePoint(.playerWon, reason: "Double bounce on \(side) side")
            }
            return
        }

        // Safety: ball escaped the playing area entirely (way past court)
        if ballSim.isOutOfBounds {
            let lastHitter: PointResult = ballSim.lastHitByPlayer ? .npcWon : .playerWon
            if ballSim.lastHitByPlayer {
                playerErrors += 1
            } else {
                npcErrors += 1
            }
            showIndicator("Out!", color: .systemOrange)
            resolvePoint(lastHitter, reason: "Escaped area (x=\(String(format: "%.2f", ballSim.courtX)), y=\(String(format: "%.2f", ballSim.courtY)))")
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
        let pScale = CourtRenderer.perspectiveScale(ny: max(0, min(1, playerNY)))

        // Jump Y-offset
        let jumpOffset = playerJumpSpriteYOffset * pScale

        // Lunge hop Y-offset
        let lungeOffset = lungeSpriteYOffset * pScale

        // Dink push Y-offset (toward net = positive screen Y for player)
        var dinkPushOffset: CGFloat = 0
        if playerDinkPushTimer > 0 {
            let progress = 1.0 - playerDinkPushTimer / dinkPushDuration
            dinkPushOffset = sin(progress * .pi) * 8.0 * pScale
        }
        playerNode.position = CGPoint(x: screenPos.x, y: screenPos.y + jumpOffset + lungeOffset + dinkPushOffset)

        // Squash/stretch during jump + sprite flipping
        let baseScale = AC.Sprites.nearPlayerScale * pScale
        if playerJumpPhase != .grounded {
            let fraction = min(playerJumpTimer / P.jumpDuration, 1.0)
            let sinVal = sin(fraction * .pi)
            // Rising: narrow + tall. Landing: wide + short (squash).
            let xMag = baseScale * (1.0 - sinVal * 0.12)
            let yScale = baseScale * (1.0 + sinVal * 0.15)
            playerNode.xScale = playerSpriteFlipped ? -xMag : xMag
            playerNode.yScale = yScale
        } else {
            playerNode.xScale = playerSpriteFlipped ? -baseScale : baseScale
            playerNode.yScale = baseScale
        }
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
        let pScale = CourtRenderer.perspectiveScale(ny: npcAI.currentNY)

        // NPC jump Y-offset
        let jumpOffset = npcAI.jumpSpriteYOffset * pScale

        // NPC dink push Y-offset (toward net = negative screen Y for NPC at top)
        var dinkPushOffset: CGFloat = 0
        if npcDinkPushTimer > 0 {
            let progress = 1.0 - npcDinkPushTimer / dinkPushDuration
            dinkPushOffset = -sin(progress * .pi) * 8.0 * pScale
        }
        npcNode.position = CGPoint(x: screenPos.x, y: screenPos.y + jumpOffset + dinkPushOffset)

        // Squash/stretch during NPC jump + sprite flipping
        let baseScale = AC.Sprites.farPlayerScale * pScale
        if npcAI.jumpPhase != .grounded {
            let sinVal = sin(npcAI.jumpAnimationFraction * .pi)
            let xMag = baseScale * (1.0 - sinVal * 0.12)
            let yScale = baseScale * (1.0 + sinVal * 0.15)
            npcNode.xScale = npcSpriteFlipped ? -xMag : xMag
            npcNode.yScale = yScale
        } else {
            npcNode.xScale = npcSpriteFlipped ? -baseScale : baseScale
            npcNode.yScale = baseScale
        }
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

    // MARK: - NPC Speech Bubble

    private func showNPCSpeech(_ text: String) {
        hideNPCSpeech()

        let bubble = SKNode()
        bubble.zPosition = AC.ZPositions.text + 5

        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 10
        label.fontColor = .white
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = 140
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        // Background pill
        let textSize = label.frame
        let padX: CGFloat = 10
        let padY: CGFloat = 6
        let bgRect = CGRect(
            x: textSize.minX - padX,
            y: textSize.minY - padY,
            width: textSize.width + padX * 2,
            height: textSize.height + padY * 2
        )
        let bg = SKShapeNode(rect: bgRect, cornerRadius: 8)
        bg.fillColor = UIColor(white: 0.15, alpha: 0.85)
        bg.strokeColor = UIColor(white: 0.5, alpha: 0.4)
        bg.lineWidth = 1

        bubble.addChild(bg)
        bubble.addChild(label)

        // Position above NPC
        let npcScreenPos = CourtRenderer.courtPoint(nx: npcAI.currentNX, ny: npcAI.currentNY)
        let pScale = CourtRenderer.perspectiveScale(ny: npcAI.currentNY)
        bubble.position = CGPoint(x: npcScreenPos.x, y: npcScreenPos.y + 35 * pScale)
        bubble.setScale(pScale * 1.5)

        bubble.alpha = 0
        addChild(bubble)

        bubble.run(.sequence([
            .fadeIn(withDuration: 0.2),
            .wait(forDuration: 2.5),
            .fadeOut(withDuration: 0.4),
            .removeFromParent()
        ]))

        npcSpeechBubble = bubble
    }

    private func hideNPCSpeech() {
        npcSpeechBubble?.removeAllActions()
        npcSpeechBubble?.removeFromParent()
        npcSpeechBubble = nil
    }

    // MARK: - NPC Frustration Pacing

    private func npcFrustrationPace() {
        guard !npcIsPacing, !npcIsWalkingOff else { return }
        npcIsPacing = true

        let baseNX = npcAI.currentNX
        let paceDistance: CGFloat = 0.12
        let leftNX = max(0.05, baseNX - paceDistance)
        let rightNX = min(0.95, baseNX + paceDistance)
        let stepDuration: TimeInterval = 0.5

        let leftPos = CourtRenderer.courtPoint(nx: leftNX, ny: npcAI.currentNY)
        let rightPos = CourtRenderer.courtPoint(nx: rightNX, ny: npcAI.currentNY)
        let centerPos = CourtRenderer.courtPoint(nx: baseNX, ny: npcAI.currentNY)

        let pace = SKAction.sequence([
            .run { [weak self] in
                self?.npcAnimator.play(.shuffle(isNear: false))
                self?.npcSpriteFlipped = true  // shuffle-right flipped = going left
            },
            .move(to: leftPos, duration: stepDuration),
            .run { [weak self] in
                self?.npcAnimator.play(.shuffle(isNear: false))
                self?.npcSpriteFlipped = false  // shuffle-right = going right
            },
            .move(to: rightPos, duration: stepDuration * 2),
            .run { [weak self] in
                self?.npcAnimator.play(.shuffle(isNear: false))
                self?.npcSpriteFlipped = true
            },
            .move(to: centerPos, duration: stepDuration),
            .run { [weak self] in
                self?.npcAnimator.play(.idle(isNear: false))
                self?.npcSpriteFlipped = false
                self?.npcIsPacing = false
            }
        ])

        npcNode.run(pace, withKey: "frustrationPace")
    }

    // MARK: - NPC Walkoff

    private func triggerNPCWalkoff() {
        guard !npcIsWalkingOff, phase != .matchOver else { return }
        npcIsWalkingOff = true
        phase = .matchOver // prevent further play
        resetJoystick()
        ballSim.reset()
        ballNode.alpha = 0
        ballShadow.alpha = 0
        hideSwipeHint()
        hideNPCSpeech()

        // Animate NPC walking off to the right with muffled angry mumbles
        npcAnimator.play(.runSide)
        npcSpriteFlipped = false  // runSide base = running right, walkoff goes right

        let walkDuration: TimeInterval = 3.0
        let startX = npcNode.position.x
        let exitX = (scene?.size.width ?? 400) + 40 // off screen right
        let walkAction = SKAction.moveTo(x: exitX, duration: walkDuration)
        walkAction.timingMode = .easeIn

        // Spawn muffled text bubbles during the walk
        let mumbleCount = Self.walkoffMumbles.count
        let mumbleInterval = walkDuration / Double(mumbleCount)
        let mumbleSequence = SKAction.repeat(
            .sequence([
                .run { [weak self] in self?.spawnWalkoffMumble() },
                .wait(forDuration: mumbleInterval)
            ]),
            count: mumbleCount
        )

        npcNode.run(.group([walkAction, mumbleSequence])) { [weak self] in
            guard let self else { return }
            // Brief pause, then show "draw" and end
            self.showIndicator("\(self.npc.name) left the court!", color: .systemOrange, duration: 2.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.endMatchAsWalkoff()
            }
        }

        // Hide boss bar during walkoff
        npcBossBar.run(.fadeOut(withDuration: 0.5))
    }

    private var walkoffMumbleIndex: Int = 0

    private func spawnWalkoffMumble() {
        let mumbles = Self.walkoffMumbles
        let text = mumbles[walkoffMumbleIndex % mumbles.count]
        walkoffMumbleIndex += 1

        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 9
        label.fontColor = UIColor.red.withAlphaComponent(0.9)
        label.position = CGPoint(x: npcNode.position.x, y: npcNode.position.y + 25)
        label.zPosition = AC.ZPositions.text + 10
        label.alpha = 0

        // Slight random horizontal offset for variety
        label.position.x += CGFloat.random(in: -10...10)

        addChild(label)

        label.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.15),
                .moveBy(x: 0, y: 20, duration: 1.2),
            ]),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }

    private func endMatchAsWalkoff() {
        let duration = matchStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let averageRally = totalPointsPlayed > 0 ? Double(totalRallyShots) / Double(totalPointsPlayed) : 0

        let finalScore = MatchScore(
            playerPoints: playerScore,
            opponentPoints: npcScore,
            playerGames: 0,
            opponentGames: 0
        )

        // Partial XP: base amount scaled by points played (min 10 XP)
        let pointsFraction = min(Double(totalPointsPlayed) / Double(IM.pointsToWin), 1.0)
        let partialXP = max(10, Int(Double(IM.baseXP) * pointsFraction * IM.interactiveXPMultiplier))

        let result = MatchResult(
            didPlayerWin: false,
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
                finalEnergy: 0
            ),
            xpEarned: partialXP,
            coinsEarned: 0, // draw — no wager
            loot: [],       // no loot
            duration: duration,
            wasResigned: true,  // skip DUPR, durability, etc.
            duprChange: nil
        )

        onComplete(result)
    }
}
