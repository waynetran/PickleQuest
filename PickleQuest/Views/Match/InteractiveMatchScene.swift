import SpriteKit
import UIKit

@MainActor
final class InteractiveMatchScene: SKScene {
    private typealias AC = MatchAnimationConstants
    private typealias P = GameConstants.DrillPhysics
    private typealias IM = GameConstants.InteractiveMatch
    private typealias PB = GameConstants.PlayerBalance

    // MARK: - Player Controller

    private var controller: InteractivePlayerController!

    // MARK: - Sprites

    private var npcNode: SKSpriteNode!
    private var ballNode: SKSpriteNode!
    private var ballShadow: SKShapeNode!
    private var ballTrailOuter: SKShapeNode!  // red/orange fire edge
    private var ballTrailInner: SKShapeNode!  // yellow/orange core
    private var ballTrailHistory: [CGPoint] = []
    private let ballTrailMaxLength: CGFloat = AC.sceneWidth * 0.5  // half court width
    private let ballTrailMaxPoints: Int = 20
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

    // Shot type flash label (shows "POWER!", "TOUCH", "LOB" on hit)
    private var shotTypeLabel: SKLabelNode!
    private var shotTypeLabelTimer: CGFloat = 0

    // Hitbox visualization (subtle ground circles — NPC only; player rings are in controller)
    private var npcHitboxRing: SKShapeNode!
    private var npcHitboxEdge: SKShapeNode!

    // Debug panel for point-over info
    private var debugPanel: SKNode!
    private var debugTextLabel: SKLabelNode!
    private var debugDoneButton: SKLabelNode!

    // NPC effective stats debug overlay
    private var npcStatsLabel: SKLabelNode!

    // (Joystick state is in controller)

    // Swipe-to-serve state
    private var swipeTouchStart: CGPoint?
    private var swipeHintNode: SKSpriteNode?

    // Player speech bubble (score announcements in rec games)
    private var playerSpeechBubble: SKNode?

    // Serve clock
    private var serveClockTimer: CGFloat = 0
    private let serveClockDuration: CGFloat = 10.0
    private var serveClockActive: Bool = false

    // Serve clock HUD nodes
    private var serveClockNode: SKNode!
    private var serveClockRingBg: SKShapeNode!
    private var serveClockRingFill: SKShapeNode!
    private var serveClockLabel: SKLabelNode!

    // Post-match handshake
    private var postMatchResult: MatchResult?

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

    // (Joystick swipe velocity is in controller)

    // Jump button
    private var jumpButton: SKNode!
    private var jumpButtonBg: SKShapeNode!
    private var jumpButtonLabel: SKLabelNode!

    // (Jump state, player sprite flipping, and player shot anim timer are in controller)
    private var npcSpriteFlipped: Bool = false
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
        let isPutAway: Bool
        let isPlayer: Bool
        let targetNX: CGFloat
        let targetNY: CGFloat
        let accuracy: CGFloat
        let allowNetHit: Bool
        let intendedNX: CGFloat
        let intendedNY: CGFloat
        let scatterRadius: CGFloat
        var timer: CGFloat
    }

    private struct PendingServe {
        let origin: CGPoint
        let target: CGPoint
        let power: CGFloat
        let arc: CGFloat
        let spin: CGFloat
        let accuracy: CGFloat
        let intendedNX: CGFloat
        let intendedNY: CGFloat
        let scatterRadius: CGFloat
        var timer: CGFloat
    }

    // Dink push animation
    private var playerDinkPushTimer: CGFloat = 0
    private var npcDinkPushTimer: CGFloat = 0
    private let dinkPushDuration: CGFloat = 0.25
    private let dinkKitchenThreshold: CGFloat = 0.30

    // (Lunge state is in controller)

    // Converging guide arrows (4 arrows pointing inward toward intercept marker)
    private var guideArrows: [SKShapeNode] = []  // N, S, E, W arrows
    private var guideArrowBaseOffsets: [CGPoint] = []  // starting offsets from marker center
    private var wasLobbed: Bool = false  // tracks if current point had an unreachable lob

    // Split step animation (quick foot shuffle before opponent contacts ball)
    private var playerSplitStepPlayed: Bool = false
    private var npcSplitStepPlayed: Bool = false

    // (Stamina and footstep state are in controller)

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

    // Dynamic target marker (updates color based on player distance)
    private var activeShotTargetMarker: SKShapeNode?
    private var activeShotTargetNX: CGFloat = 0.5
    private var activeShotTargetNY: CGFloat = 0.5

    // MARK: - Game State

    private let ballSim = DrillBallSimulation()
    private var npcAI: MatchAI!
    private let playerStats: PlayerStats

    // (Player position, movement speeds, and swept collision state are in controller)
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

    // Per-point debug stats
    private var lastHitScatter: CGFloat = 0
    private var maxBallSpeedThisPoint: CGFloat = 0
    private var lastShotPower: CGFloat = 0

    // Phases
    enum Phase {
        case waitingToStart
        case serving
        case playing
        case pointOver
        case postMatch
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
        playerEffectiveStats: PlayerStats? = nil,
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
        self.playerStats = playerEffectiveStats ?? player.stats
        self.npcBoost = P.npcStatBoost(forBaseStatAverage: CGFloat(npc.stats.average))

        super.init(size: CGSize(width: AC.sceneWidth, height: AC.sceneHeight))
        self.scaleMode = .aspectFill
        self.anchorPoint = CGPoint(x: 0, y: 0)
        self.backgroundColor = UIColor(hex: "#2C3E50")

        self.controller = InteractivePlayerController(
            playerStats: playerStats,
            appearance: player.appearance,
            startNX: 0.5, startNY: 0.08,
            config: PlayerControllerConfig(
                minNX: 0.0, maxNX: 1.0,
                minNY: -0.05, maxNY: 0.48 - P.playerPositioningOffset,
                jumpEnabled: true, lungeEnabled: true, hitboxRingsVisible: true
            )
        )
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
        guard phase != .matchOver && phase != .postMatch else { return }
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

        // Player sprite + joystick + hitbox rings (via controller)
        controller.buildNodes(parent: self, appearance: player.appearance)

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

        // Shot type flash label
        buildShotTypeLabel()

        // Jump button
        buildJumpButton()

        // High ball indicator
        buildHighBallIndicator()

        // NPC boss bar
        buildNPCBossBar()

        // Hitbox visualization rings
        buildHitboxRings()

        // Player floating stamina bar
        buildPlayerStaminaBar()

        // Debug panel
        buildDebugPanel()

        // Swipe hint
        buildSwipeHint()

        // In-game feedback labels
        buildFeedbackLabels()

        // Serve clock widget
        buildServeClockWidget()

        // Initialize AI
        npcAI = MatchAI(npc: npc, playerDUPR: player.duprRating)

        // NPC effective stats debug overlay
        buildNPCStatsOverlay()

        // Set positions
        controller.playerNX = 0.5
        controller.playerNY = 0.08
        syncAllPositions()
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
        // Converging guide arrows — 4 arrows pointing inward toward intercept marker
        buildConvergingArrows()
    }

    /// Build 4 converging arrows (N, S, E, W) that point inward toward a target.
    private func buildConvergingArrows() {
        // Rotations: each arrow points inward (tip toward center)
        // N arrow sits above target, points down → rotation = .pi
        // S arrow sits below target, points up → rotation = 0
        // E arrow sits right of target, points left → rotation = .pi/2
        // W arrow sits left of target, points right → rotation = -.pi/2
        let rotations: [CGFloat] = [.pi, 0, .pi / 2, -.pi / 2]
        // Base offsets from marker center (in screen points, before perspective)
        let baseOffsets: [CGPoint] = [
            CGPoint(x: 0, y: 30),    // N: above
            CGPoint(x: 0, y: -30),   // S: below
            CGPoint(x: 30, y: 0),    // E: right
            CGPoint(x: -30, y: 0),   // W: left
        ]

        guideArrows = []
        guideArrowBaseOffsets = baseOffsets

        for i in 0..<4 {
            let arrowPath = CGMutablePath()
            arrowPath.move(to: CGPoint(x: 0, y: 12))      // tip
            arrowPath.addLine(to: CGPoint(x: -8, y: -4))   // bottom-left
            arrowPath.addLine(to: CGPoint(x: 8, y: -4))    // bottom-right
            arrowPath.closeSubpath()

            let arrow = SKShapeNode(path: arrowPath)
            arrow.fillColor = UIColor.systemGreen.withAlphaComponent(0.55)
            arrow.strokeColor = UIColor.systemGreen.withAlphaComponent(0.9)
            arrow.lineWidth = 2.0
            arrow.zRotation = rotations[i]
            arrow.zPosition = AC.ZPositions.courtLines + 1.5
            arrow.alpha = 0
            addChild(arrow)
            guideArrows.append(arrow)
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

    private func buildHitboxRings() {
        let hitboxZ = AC.ZPositions.nearPlayer + 1  // draw over player sprites

        // Player hitbox rings are built by controller.buildNodes()

        // NPC hitbox: inner (direct hit) + outer (edge/stretch zone)
        npcHitboxRing = SKShapeNode(circleOfRadius: 1)
        npcHitboxRing.strokeColor = UIColor.systemRed.withAlphaComponent(0.7)
        npcHitboxRing.fillColor = UIColor.systemRed.withAlphaComponent(0.15)
        npcHitboxRing.lineWidth = 2.0
        npcHitboxRing.zPosition = hitboxZ
        addChild(npcHitboxRing)

        npcHitboxEdge = SKShapeNode(circleOfRadius: 1)
        npcHitboxEdge.strokeColor = UIColor.systemRed.withAlphaComponent(0.35)
        npcHitboxEdge.fillColor = .clear
        npcHitboxEdge.lineWidth = 1.5
        npcHitboxEdge.zPosition = hitboxZ
        addChild(npcHitboxEdge)
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

    private func buildNPCStatsOverlay() {
        let P = GameConstants.DrillPhysics.self
        let dupr = npc.duprRating
        let boost = npcBoost

        // Compute effective stats (same as MatchAI.effectiveStats)
        func eff(_ stat: StatType) -> Int {
            P.npcScaledStat(stat, base: npc.stats.stat(stat), boost: boost, dupr: dupr)
        }
        let pow = eff(.power), acc = eff(.accuracy), spn = eff(.spin), spd = eff(.speed)
        let def = eff(.defense), rfx = eff(.reflexes), pos = eff(.positioning)
        let clt = eff(.clutch), foc = eff(.focus), sta = eff(.stamina), con = eff(.consistency)
        let mult = P.npcGlobalMultiplier(for: .power, dupr: dupr)

        let text = """
        DUPR \(String(format: "%.1f", dupr)) | mult \(String(format: "%.2f", mult)) | boost +\(boost)
        POW \(pow) ACC \(acc) SPN \(spn) SPD \(spd)
        DEF \(def) RFX \(rfx) POS \(pos) CLT \(clt)
        FOC \(foc) STA \(sta) CON \(con)
        base:\(npc.stats.power) errRate:\(String(format: "%.1f", P.npcBaseErrorRate * 100))%
        """

        npcStatsLabel = SKLabelNode(text: text)
        npcStatsLabel.fontName = "Menlo-Bold"
        npcStatsLabel.fontSize = 8
        npcStatsLabel.fontColor = .yellow
        npcStatsLabel.numberOfLines = 0
        npcStatsLabel.preferredMaxLayoutWidth = 200
        npcStatsLabel.horizontalAlignmentMode = .left
        npcStatsLabel.verticalAlignmentMode = .top
        npcStatsLabel.zPosition = AC.ZPositions.text + 20
        npcStatsLabel.position = CGPoint(x: 8, y: AC.sceneHeight - 8)
        addChild(npcStatsLabel)
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

    // MARK: - Serve Clock Widget

    private func buildServeClockWidget() {
        serveClockNode = SKNode()
        serveClockNode.position = CGPoint(x: AC.sceneWidth - 52, y: 110)
        serveClockNode.zPosition = AC.ZPositions.text + 6
        serveClockNode.alpha = 0

        // Background ring
        let bgPath = CGMutablePath()
        bgPath.addArc(center: .zero, radius: 22, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        serveClockRingBg = SKShapeNode(path: bgPath)
        serveClockRingBg.strokeColor = UIColor(white: 0.4, alpha: 0.6)
        serveClockRingBg.lineWidth = 5
        serveClockRingBg.fillColor = UIColor(white: 0.1, alpha: 0.7)
        serveClockNode.addChild(serveClockRingBg)

        // Foreground depleting arc
        serveClockRingFill = SKShapeNode()
        serveClockRingFill.strokeColor = .systemGreen
        serveClockRingFill.lineWidth = 5
        serveClockRingFill.fillColor = .clear
        serveClockRingFill.lineCap = .round
        serveClockNode.addChild(serveClockRingFill)

        // Center label
        serveClockLabel = SKLabelNode(text: "10")
        serveClockLabel.fontName = "AvenirNext-Heavy"
        serveClockLabel.fontSize = 16
        serveClockLabel.fontColor = .white
        serveClockLabel.verticalAlignmentMode = .center
        serveClockLabel.horizontalAlignmentMode = .center
        serveClockNode.addChild(serveClockLabel)

        addChild(serveClockNode)
    }

    private func updateServeClockWidget() {
        guard serveClockActive else {
            serveClockNode.alpha = 0
            return
        }
        serveClockNode.alpha = 1

        let fraction = max(0, serveClockTimer / serveClockDuration)
        let seconds = Int(ceil(serveClockTimer))
        serveClockLabel.text = "\(max(0, seconds))"

        // Arc: starts at 12 o'clock (-.pi/2), sweeps clockwise
        let startAngle: CGFloat = -.pi / 2
        let endAngle = startAngle - fraction * .pi * 2
        let arcPath = CGMutablePath()
        arcPath.addArc(center: .zero, radius: 22, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        serveClockRingFill.path = arcPath

        // Color: green >5s, yellow ≤5s, red ≤3s
        if serveClockTimer > 5 {
            serveClockRingFill.strokeColor = .systemGreen
            serveClockLabel.fontColor = .white
        } else if serveClockTimer > 3 {
            serveClockRingFill.strokeColor = .systemYellow
            serveClockLabel.fontColor = .systemYellow
        } else {
            serveClockRingFill.strokeColor = .systemRed
            serveClockLabel.fontColor = .systemRed
        }

        // Pulse effect at ≤3s
        if serveClockTimer <= 3 {
            let pulse = 1.0 + 0.12 * sin(serveClockTimer * .pi * 4)
            serveClockNode.setScale(pulse)
        } else {
            serveClockNode.setScale(1.0)
        }
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
        // Crosscourt direction: if player is on right (nx > 0.5), swipe toward left and vice versa
        let crosscourtDX: CGFloat = controller.playerNX > 0.5 ? -60 : 60
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
                let pos = CourtRenderer.courtPoint(nx: self.controller.playerNX, ny: max(0, self.controller.playerNY))
                let dx: CGFloat = self.controller.playerNX > 0.5 ? -60 : 60
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

    private func showShotMarkers(
        intendedNX: CGFloat, intendedNY: CGFloat,
        scatterRadius: CGFloat,
        interceptNX: CGFloat, interceptNY: CGFloat
    ) {
        clearShotMarkers()
        lastShotTargetNX = interceptNX
        lastShotTargetNY = interceptNY
        activeShotTargetNX = interceptNX
        activeShotTargetNY = interceptNY

        let intendedPos = CourtRenderer.courtPoint(nx: intendedNX, ny: intendedNY)
        let intendedScale = CourtRenderer.perspectiveScale(ny: intendedNY)

        // Scatter circle (margin of error) around intended target
        if scatterRadius > 0.005 {
            let scatterScreenRadius = scatterRadius * AC.sceneWidth * intendedScale
            let scatterMarker = SKShapeNode(ellipseOf: CGSize(
                width: scatterScreenRadius * 2,
                height: scatterScreenRadius * 0.6
            ))
            scatterMarker.fillColor = UIColor.orange.withAlphaComponent(0.10)
            scatterMarker.strokeColor = UIColor.orange.withAlphaComponent(0.4)
            scatterMarker.lineWidth = 1.0
            scatterMarker.position = intendedPos
            scatterMarker.name = "scatterCircle"
            shotMarkersNode.addChild(scatterMarker)
        }

        // Intended target (yellow crosshair, small)
        let intendedRadius: CGFloat = 4 * intendedScale
        let intendedMarker = SKShapeNode(ellipseOf: CGSize(width: intendedRadius * 2, height: intendedRadius * 0.6))
        intendedMarker.fillColor = UIColor.yellow.withAlphaComponent(0.4)
        intendedMarker.strokeColor = UIColor.yellow.withAlphaComponent(0.7)
        intendedMarker.lineWidth = 1.0
        intendedMarker.position = intendedPos
        intendedMarker.name = "intendedTarget"
        shotMarkersNode.addChild(intendedMarker)

        // Ideal intercept marker — where player should be for a perfect hit, projected on court
        let interceptPos = CourtRenderer.courtPoint(nx: interceptNX, ny: interceptNY)
        let interceptScale = CourtRenderer.perspectiveScale(ny: interceptNY)
        let interceptRadius: CGFloat = 8 * interceptScale
        let interceptMarker = SKShapeNode(ellipseOf: CGSize(
            width: interceptRadius * 2,
            height: interceptRadius * 0.6
        ))
        interceptMarker.lineWidth = 2.0
        interceptMarker.position = interceptPos
        interceptMarker.name = "interceptMarker"
        shotMarkersNode.addChild(interceptMarker)
        activeShotTargetMarker = interceptMarker

        // Initial color update
        updateShotTargetColor()
    }

    /// Update the intercept marker: recompute prediction live, reposition on court,
    /// color-code by player distance, and animate converging arrows.
    private func updateShotTargetColor() {
        guard let marker = activeShotTargetMarker else { return }
        guard ballSim.isActive else { return }

        // Only show intercept for NPC shots heading toward player
        let isNPCShot = !ballSim.lastHitByPlayer

        // Live-update the intercept prediction as ball moves
        if isNPCShot {
            let intercept = ballSim.predictIdealIntercept()
            activeShotTargetNX = intercept.x
            activeShotTargetNY = intercept.y

            // Reposition marker on court
            let pos = CourtRenderer.courtPoint(nx: intercept.x, ny: intercept.y)
            let scale = CourtRenderer.perspectiveScale(ny: intercept.y)
            let r: CGFloat = 8 * scale
            marker.position = pos
            marker.path = CGPath(ellipseIn: CGRect(
                x: -r, y: -r * 0.3,
                width: r * 2, height: r * 0.6
            ), transform: nil)
        }

        let dx = activeShotTargetNX - controller.playerNX
        let dy = activeShotTargetNY - controller.playerNY
        let dist = sqrt(dx * dx + dy * dy)
        let hitbox = controller.hitboxRadius

        // Out of bounds target — always show red
        let isOut = activeShotTargetNX < 0.0 || activeShotTargetNX > 1.0
            || activeShotTargetNY < 0.0 || activeShotTargetNY > 1.0

        let color: UIColor
        if isOut {
            color = .systemRed
        } else if dist < hitbox * 1.2 {
            color = .systemGreen    // in strike zone
        } else if dist < hitbox * 3.0 {
            color = .systemOrange   // reachable with movement
        } else {
            color = .systemRed      // need to sprint, may not make it
        }
        marker.fillColor = color.withAlphaComponent(0.35)
        marker.strokeColor = color.withAlphaComponent(0.85)
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
        activeShotTargetMarker = nil
        hideAllMoveGuides()
    }

    // MARK: - Match Flow

    private func startNextPoint() {
        rallyLength = 0
        lastHitScatter = 0
        maxBallSpeedThisPoint = 0
        lastShotPower = 0
        ballSim.reset()
        ballNode.alpha = 0
        ballShadow.alpha = 0
        ballTrailOuter.alpha = 0
        ballTrailInner.alpha = 0
        ballTrailHistory.removeAll()
        checkedFirstBounce = false
        clearShotMarkers()
        hideDebugPanel()
        hideNPCSpeech()
        hidePlayerSpeech()
        playerServeStallTimer = 0
        serveStallTauntIndex = 0
        serveClockTimer = serveClockDuration
        serveClockActive = false
        nextSnarkyTime = CGFloat.random(in: 5...10)
        nextPaceTime = 20
        npcIsPacing = false
        npcNode?.removeAction(forKey: "frustrationPace")

        // Reset player controller state
        let staminaStat = CGFloat(playerStats.stat(.stamina))
        let staminaRecovery: CGFloat = 20 + (staminaStat / 99.0) * 15
        npcSpriteFlipped = false
        playerDinkPushTimer = 0
        npcDinkPushTimer = 0
        playerSplitStepPlayed = false
        npcSplitStepPlayed = false
        npcShotAnimTimer = 0
        pendingPlayerShot = nil
        pendingNPCShot = nil
        pendingServeShot = nil
        shotTypeLabelTimer = 0
        shotTypeLabel?.alpha = 0
        hideAllMoveGuides()
        wasLobbed = false

        npcAI.recoverBetweenPoints()

        // Reset NPC state for new point (clears shot count, pattern memory, kitchen approach)
        npcAI.reset(npcScore: npcScore, isServing: servingSide == .opponent)

        // Position players for serve
        if servingSide == .player {
            let evenScore = playerScore % 2 == 0
            controller.resetForNewPoint(startNX: evenScore ? 0.75 : 0.25, startNY: 0.08, staminaRecovery: staminaRecovery)
            npcAI.positionForReceive(playerScore: playerScore)
            phase = .serving
            showSwipeHint()
            serveClockActive = true
            if !isRated { showPlayerSpeech(serveScoreText()) }
        } else {
            let evenScore = npcScore % 2 == 0
            npcAI.positionForServe(npcScore: npcScore)
            // Receiver cross-court from server
            let serverRight = evenScore
            controller.resetForNewPoint(startNX: serverRight ? 0.25 : 0.75, startNY: 0.08, staminaRecovery: staminaRecovery)
            phase = .serving
            servePauseTimer = IM.servePauseDuration
            if !isRated { showNPCSpeech(serveScoreText()) }
        }

        syncAllPositions()
        onScoreUpdate?(playerScore, npcScore, servingSide)

        dbg.logPointStart(
            pointNum: totalPointsPlayed + 1,
            servingSide: servingSide,
            playerScore: playerScore,
            npcScore: npcScore,
            playerNX: controller.playerNX,
            playerNY: controller.playerNY,
            playerStamina: controller.stamina,
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

        serveClockActive = false
        serveClockNode.alpha = 0
        hideSwipeHint()
        hideNPCSpeech()
        hidePlayerSpeech()
        playerServeStallTimer = 0
        serveStallTauntIndex = 0

        run(SoundManager.shared.skAction(for: .serveWhoosh))

        let swipeAngle = atan2(dx, dy)
        let angleDeviation = max(-P.serveSwipeAngleRange, min(P.serveSwipeAngleRange, swipeAngle))
        let rawPowerFactor = distance / P.serveSwipeMaxPower

        let accuracyStat = CGFloat(playerStats.stat(.accuracy))
        let focusStat = CGFloat(playerStats.stat(.focus))
        let scatterReduction = ((accuracyStat + focusStat) / 2.0) / 99.0
        let scatter = (1.0 - scatterReduction * 0.7) * 0.15
        let scatterX = CGFloat.random(in: -scatter...scatter)
        let scatterY = CGFloat.random(in: -scatter...scatter)

        // Service box is 0.682 (kitchen) to 1.0 (baseline), midpoint ~0.84
        // Light swipe → mid-box, strong swipe → deep near baseline
        let baseTargetNY: CGFloat = 0.78 + rawPowerFactor * 0.15
        let targetNX = max(0.15, min(0.85, 0.5 + angleDeviation + scatterX))
        let targetNY = max(0.73, min(0.92, baseTargetNY + scatterY))

        // Power from serve swipe speed: fast swipe = power serve (1.2x), normal = standard
        let isPowerServe = distance > P.serveSwipeMaxPower * 0.7
        let powerMultiplier: CGFloat = isPowerServe ? 1.2 : 1.0
        let servePower = max(0.30, (0.10 + min(rawPowerFactor, 1.3) * 0.75) * powerMultiplier)

        // Physics-based arc: compute exact arc to land at target distance
        let serveDistNY = abs(targetNY - max(0, controller.playerNY))
        let serveArc = DrillShotCalculator.arcToLandAt(
            distanceNY: serveDistNY,
            power: servePower,
            arcMargin: 1.15 // net clearance margin
        )

        // Drain stamina for power serve
        let serveModes: DrillShotCalculator.ShotMode = isPowerServe ? [.power] : []
        if isPowerServe { controller.stamina = max(0, controller.stamina - P.maxStamina * P.powerShotStaminaDrain) }

        dbg.logPlayerServe(
            originNX: controller.playerNX, originNY: max(0, controller.playerNY),
            targetNX: targetNX, targetNY: targetNY,
            power: servePower, arc: serveArc,
            scatter: scatter, modes: serveModes,
            stamina: controller.stamina
        )

        // Play forehand swing animation immediately — ball launches at mid-swing
        controller.playerAnimator.play(.forehand(isNear: true))
        controller.playerShotAnimTimer = shotAnimDuration
        controller.playerSpriteFlipped = false

        let serveAccuracy = 1.0 - scatter * 3
        pendingServeShot = PendingServe(
            origin: CGPoint(x: controller.playerNX, y: max(0, controller.playerNY)),
            target: CGPoint(x: targetNX, y: targetNY),
            power: servePower,
            arc: serveArc,
            spin: angleDeviation * 0.3,
            accuracy: max(0, serveAccuracy),
            intendedNX: targetNX,
            intendedNY: targetNY,
            scatterRadius: 0,
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
        let consistencyStat = CGFloat(P.npcScaledStat(.consistency, base: npc.stats.stat(.consistency), boost: npcBoost, dupr: npc.duprRating))
        let accuracyStat = CGFloat(P.npcScaledStat(.accuracy, base: npc.stats.stat(.accuracy), boost: npcBoost, dupr: npc.duprRating))
        let serveStat = (consistencyStat + accuracyStat) / 2.0
        let baseFaultRate = P.npcBaseServeFaultRate * pow(1.0 - serveStat / 99.0, P.npcServeFaultStatExponent)

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

        // Target: service box (past kitchen line 0.318) on receiver's side
        let evenScore = npcScore % 2 == 0
        var targetNX: CGFloat = evenScore ? 0.25 : 0.75
        var targetNY: CGFloat

        // Fault type determines target AND power override
        var faultPowerOverride: CGFloat? = nil

        if isDoubleFault {
            // Faults: beginners miss long or wide; only skilled spin servers miss short (kitchen)
            let duprFrac = CGFloat(max(0, min(1, (npc.duprRating - 2.0) / 6.0)))
            let hasSpin = modes.contains(.topspin) || modes.contains(.slice)
            let kitchenFaultChance = hasSpin ? duprFrac * 0.4 : 0.0

            if CGFloat.random(in: 0...1) < kitchenFaultChance {
                // Kitchen fault: aggressive spin serve aimed short
                targetNY = CGFloat.random(in: 0.35...0.48)
            } else {
                let longVsWide = CGFloat.random(in: 0...1)
                if longVsWide < 0.6 {
                    // Long: NPC swings too hard → ball sails past baseline
                    targetNY = CGFloat.random(in: 0.05...0.15)
                    faultPowerOverride = CGFloat.random(in: 0.55...0.70)
                } else {
                    // Wide: NPC aims poorly → ball goes past sideline
                    targetNY = CGFloat.random(in: 0.05...0.20)
                    targetNX = evenScore
                        ? CGFloat.random(in: -0.10...(-0.03))
                        : CGFloat.random(in: 1.03...1.10)
                }
            }
        } else {
            // Good serve: aim into the deep service box
            let duprFrac = CGFloat(max(0, min(1, (npc.duprRating - 2.0) / 6.0)))
            let maxNY = S.npcServeTargetMaxNY_Low + duprFrac * (S.npcServeTargetMaxNY_High - S.npcServeTargetMaxNY_Low)
            targetNY = CGFloat.random(in: S.npcServeTargetMinNY...maxNY)
        }

        // Arc is always computed with normal serve power so fault power override
        // creates an intentional overshoot (ball sails long past baseline)
        let normalServePower = max(P.serveMinPower, min(P.servePowerCap, shot.power))
        let servePower = faultPowerOverride ?? normalServePower

        let serveDistNY = abs(npcAI.currentNY - targetNY)
        let serveDistNX = abs(npcAI.currentNX - targetNX)
        let serveArc = DrillShotCalculator.arcToLandAt(
            distanceNY: serveDistNY,
            distanceNX: serveDistNX,
            power: normalServePower
        )

        dbg.logNPCServe(
            originNX: npcAI.currentNX, originNY: npcAI.currentNY,
            targetNX: targetNX, targetNY: targetNY,
            power: servePower, arc: serveArc,
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
        let launchPower = servePower
        let serveAccuracy: CGFloat = isDoubleFault ? 0.0 : 0.8

        // Delay ball launch to mid-swing
        let delay = SKAction.wait(forDuration: TimeInterval(swingContactDelay))
        let launch = SKAction.run { [weak self] in
            guard let self else { return }
            self.phase = .playing
            // Serve launch: flat (no spin/topspin) — spin effects are modeled by stat-based fault rate
            self.ballSim.launch(
                from: launchOrigin, toward: launchTarget,
                power: launchPower, arc: serveArc,
                spin: 0
            )
            self.ballSim.lastHitByPlayer = false
            self.previousBallNY = self.ballSim.courtY
            self.ballNode.alpha = 1
            self.ballShadow.alpha = 1
            let predicted = self.ballSim.predictIdealIntercept()
            self.showShotMarkers(
                intendedNX: targetNX, intendedNY: targetNY,
                scatterRadius: 0,
                interceptNX: predicted.x, interceptNY: predicted.y
            )
        }
        self.run(.sequence([delay, launch]))
    }

    // MARK: - Point Resolution

    private enum PointResult {
        case playerWon
        case npcWon
    }

    private func resolvePoint(_ result: PointResult, reason: String) {
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
        ballTrailOuter.alpha = 0
        ballTrailInner.alpha = 0
        ballTrailHistory.removeAll()
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
            let scatterStr = String(format: "%.3f", lastHitScatter)
            let maxSpeedStr = String(format: "%.2f", maxBallSpeedThisPoint)
            let powerStr = String(format: "%.2f", lastShotPower)
            let debugText = """
            Pt #\(totalPointsPlayed): \(whoWon)
            Reason: \(reason)
            Rally: \(rallyLength) shots
            Ball: (\(ballX), \(ballY)) h=\(ballH) vy=\(ballVY)
            Bounces: \(bounces) LastHit: \(hitByPlayer ? "Player" : "NPC")
            1st Bounce: \(bounceZone)
            Scatter: \(scatterStr) MaxSpd: \(maxSpeedStr) Power: \(powerStr)
            ActiveTime: \(activeT)s
            Server: \(serverStr)\(sideOut)
            Score: You \(playerScore) — \(npcScore) \(npc.name)
            """
            showDebugPanel(debugText)
        }

        // Player personality reaction (~30% of the time)
        if Int.random(in: 0..<10) < 3 {
            let playerContext: PersonalityDialog.Context
            switch result {
            case .playerWon: playerContext = .pointWon
            case .npcWon: playerContext = .pointLost
            }
            let reaction = PersonalityDialog.randomLine(for: player.personality, context: playerContext)
            showPlayerSpeech(reaction)
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
        controller.resetJoystick()
        ballSim.reset()
        ballNode.alpha = 0
        ballShadow.alpha = 0
        ballTrailOuter.alpha = 0
        ballTrailInner.alpha = 0
        ballTrailHistory.removeAll()

        let didPlayerWin: Bool
        if wasResigned {
            didPlayerWin = false
        } else {
            didPlayerWin = playerScore > npcScore
        }

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
                finalEnergy: Double(controller.stamina)
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

        if wasResigned {
            onComplete(result)
        } else {
            playPostMatchAnimation(result: result)
        }
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
                controller.initiateJump()
                continue
            }

            // Swipe to serve (player serving)
            if phase == .serving && servingSide == .player {
                swipeTouchStart = pos
                return
            }

            // Joystick (delegated to controller)
            controller.handleJoystickBegan(touch: touch, location: pos)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch = controller.joystickTouch, touches.contains(activeTouch) else { return }
        let pos = activeTouch.location(in: self)
        controller.handleJoystickMoved(touch: activeTouch, location: pos)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if phase == .serving && servingSide == .player, let startPos = swipeTouchStart {
                let endPos = touch.location(in: self)
                playerServe(from: startPos, to: endPos)
                swipeTouchStart = nil
                return
            }

            if controller.handleJoystickEnded(touch: touch) {
                continue
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        swipeTouchStart = nil
        for touch in touches {
            controller.handleJoystickEnded(touch: touch)
        }
    }

    // MARK: - Swipe Shot Determination

    // Power boost scaling
    private let maxSwipePowerBoost: CGFloat = 0.5

    /// Determine shot modes from joystick state at the moment of contact.
    private func determineShotMode() -> DrillShotCalculator.ShotMode {
        // Joystick released → touch/dink (target chosen by calculator based on stats)
        guard controller.joystickTouch != nil else { return [.touch] }

        if controller.joystickMagnitude > 1.0 {
            // Past the circle → power shot
            return [.power]
        } else {
            // Within the circle → regular directional shot
            return []
        }
    }

    /// Joystick direction mapped to target (NX, NY) on the opponent's court.
    /// Returns nil when joystick is released (let calculator choose by stats).
    /// dx is capped so the shot cone always aims forward, not sideways.
    private func joystickAimTarget() -> (nx: CGFloat, ny: CGFloat)? {
        guard controller.joystickTouch != nil else { return nil }

        let dx = controller.joystickDirection.dx  // -1 to +1
        let dy = controller.joystickDirection.dy  // positive = up (toward opponent court)

        // Cap horizontal spread: abs(dx) can't exceed abs(dy) so shots aim forward
        let cappedDX: CGFloat
        if abs(dy) > 0.01 {
            cappedDX = max(-abs(dy), min(abs(dy), dx))
        } else {
            // Joystick barely moved vertically — minimal horizontal aim
            cappedDX = dx * 0.3
        }

        // NX: center ± horizontal aim (0.15 to 0.85 range)
        let nx = 0.5 + cappedDX * 0.35

        // NY: joystick dy maps depth — up = deeper, neutral = mid-court
        // dy ranges roughly 0 to 1 when pushing up; map to 0.65 (short) to 0.92 (deep)
        let dyUp = max(0, dy)  // only forward direction matters for depth
        let ny = 0.65 + dyUp * 0.27

        return (nx: nx, ny: ny)
    }

    /// Power boost when joystick is past the circle edge.
    /// Scales with how far past the boundary (1.0 = edge, 1.5 = max).
    private func joystickPowerBoost() -> CGFloat {
        guard controller.joystickMagnitude > 1.0 else { return 0 }
        let excessFraction = min((controller.joystickMagnitude - 1.0) / 0.5, 1.0)
        let powerStat = CGFloat(playerStats.stat(.power))
        return excessFraction * maxSwipePowerBoost * (powerStat / 99.0)
    }

    /// Flash shot type label below the player on hit.
    private func showShotTypeFlash(_ text: String, color: UIColor) {
        shotTypeLabel.text = text
        shotTypeLabel.fontColor = color
        shotTypeLabel.alpha = 1.0
        shotTypeLabel.setScale(1.0)
        shotTypeLabelTimer = 0.7  // total flash duration

        // Pulse: scale up then back
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
            controller.updateJump(dt: dt)
            controller.movePlayer(dt: dt)
            let prevBounces = ballSim.bounceCount
            previousBallNY = ballSim.courtY
            // Store previous ball position for swept collision detection
            controller.prevBallX = ballSim.courtX
            controller.prevBallY = ballSim.courtY
            controller.prevBallHeight = ballSim.height
            ballSim.update(dt: dt)
            // Record first bounce position using sub-frame interpolation
            if ballSim.didBounceThisFrame && prevBounces == 0 {
                firstBounceCourtX = ballSim.lastBounceCourtX
                firstBounceCourtY = ballSim.lastBounceCourtY
                // Landing spot removed — color-coded target marker already shows where ball is heading
            }
            // Log when ball crosses player's Y line (NPC shots heading toward player)
            if !ballSim.lastHitByPlayer && controller.prevBallY > controller.playerNY && ballSim.courtY <= controller.playerNY {
                let xDist = abs(ballSim.courtX - controller.playerNX)
                let positioningStat = CGFloat(playerStats.stat(.positioning))
                let hitbox = P.baseHitboxRadius + (positioningStat / 99.0) * P.positioningHitboxBonus
                dbg.logBallAtPlayerY(
                    ballX: ballSim.courtX, ballY: ballSim.courtY, ballHeight: ballSim.height,
                    playerNX: controller.playerNX, playerNY: controller.playerNY,
                    xDistance: xDist,
                    hitboxRadius: hitbox,
                    wouldBeInHitbox: xDist <= hitbox,
                    bounceCount: ballSim.bounceCount
                )
            }

            npcAI.playerPositionNX = controller.playerNX
            npcAI.playerPositionNY = controller.playerNY
            updateNPCPressureHitbox()
            npcAI.update(dt: dt, ball: ballSim)
            checkBallState()
            checkPlayerHit()
            checkNPCHit()

            // Shot animation lock timers (prevent movePlayer from overwriting swing animations)
            if controller.playerShotAnimTimer > 0 { controller.playerShotAnimTimer = max(0, controller.playerShotAnimTimer - dt) }
            if npcShotAnimTimer > 0 { npcShotAnimTimer = max(0, npcShotAnimTimer - dt) }

            // Pending shot timers — launch ball at mid-swing
            tickPendingShots(dt: dt)

            // Dink push animation timers
            if playerDinkPushTimer > 0 { playerDinkPushTimer = max(0, playerDinkPushTimer - dt) }
            if npcDinkPushTimer > 0 { npcDinkPushTimer = max(0, npcDinkPushTimer - dt) }

            syncAllPositions()
            syncHitboxRings()
            updateShotTargetColor()
            updatePlayerStaminaBar()
            updateNPCBossBar()
            updateMovementGuide()
            updateJumpButtonVisual()
            updateSplitSteps()

        case .serving:
            controller.movePlayer(dt: dt)
            tickPendingServe(dt: dt)
            syncAllPositions()
            syncHitboxRings()
            updatePlayerStaminaBar()
            updateNPCBossBar()
            // NPC auto-serve after pause
            if servingSide == .opponent {
                servePauseTimer -= dt
                if servePauseTimer <= 0 {
                    npcServe()
                }
            }
            // Serve clock countdown (player serving only)
            if serveClockActive {
                serveClockTimer -= dt
                if serveClockTimer <= 0 {
                    serveClockTimer = 0
                    serveClockActive = false
                    updateServeClockWidget()
                    showIndicator("Time!", color: .systemRed, duration: 1.5)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.endMatch(wasResigned: true)
                    }
                }
            }
            updateServeClockWidget()

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

    // (Player jump, lunge, and associated methods are in controller)

    // MARK: - Movement Guide

    private func hideAllMoveGuides() {
        for arrow in guideArrows { arrow.alpha = 0 }
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

        // Only show on player's half
        guard activeShotTargetNY < 0.55 else { hideAllMoveGuides(); return }

        // Estimate time until second bounce (urgency driver)
        // First: time to first bounce (if not yet bounced)
        let g = P.gravity
        let gEff = g + ballSim.topspinFactor * 0.6
        var timeToDoubleBounce: CGFloat = 2.0  // default fallback

        if ballSim.bounceCount == 0 {
            // Time to first bounce
            let disc1 = ballSim.vz * ballSim.vz + 2.0 * gEff * ballSim.height
            if disc1 >= 0 {
                let t1 = (ballSim.vz + sqrt(disc1)) / gEff
                // After bounce: vz_after ≈ bounce-speed upward, then second bounce time
                let vzAfter = abs(ballSim.vz - gEff * t1) * P.bounceDamping
                let t2 = 2.0 * vzAfter / gEff  // time for full arc (up and back down)
                timeToDoubleBounce = t1 + t2
            }
        } else if ballSim.bounceCount == 1 {
            // Already bounced once — time to next ground hit
            if ballSim.vz > 0 {
                let disc2 = ballSim.vz * ballSim.vz + 2.0 * gEff * ballSim.height
                if disc2 >= 0 {
                    timeToDoubleBounce = (ballSim.vz + sqrt(disc2)) / gEff
                }
            } else {
                // Already descending after bounce
                let disc2 = ballSim.vz * ballSim.vz + 2.0 * gEff * ballSim.height
                if disc2 >= 0 && gEff > 0.001 {
                    timeToDoubleBounce = (-ballSim.vz + sqrt(disc2)) / gEff
                } else {
                    timeToDoubleBounce = 0.1
                }
            }
        } else {
            hideAllMoveGuides()
            return
        }

        let maxTime: CGFloat = 2.5  // seconds from NPC hit to roughly double bounce
        guard timeToDoubleBounce > 0.02 else { hideAllMoveGuides(); return }

        // Auto-jump for high balls within jump reach
        let ballSpeedY = abs(ballSim.vy)
        if ballSpeedY > 0.01 {
            let timeToPlayerY = abs(ballSim.courtY - controller.playerNY) / ballSpeedY
            let heightAtPlayer = ballSim.height + ballSim.vz * timeToPlayerY
                - 0.5 * g * timeToPlayerY * timeToPlayerY
            let speedStat = CGFloat(playerStats.stat(.speed))
            let reflexesStat = CGFloat(playerStats.stat(.reflexes))
            let athleticism = (speedStat + reflexesStat) / 2.0 / 99.0
            let standingReach = P.baseHeightReach + athleticism * P.maxHeightReachBonus
            let jumpReach = standingReach + P.jumpHeightReachBonus

            if heightAtPlayer > standingReach && heightAtPlayer <= jumpReach && timeToPlayerY < 0.4
                && ballSim.bounceCount == 0 {
                controller.initiateJump()
            }
            if heightAtPlayer > jumpReach {
                wasLobbed = true
            }
        }

        // Smooth in-and-out animation (sine wave, no urgency factor)
        let time = CGFloat(CACurrentMediaTime())
        let slideProgress = 0.5 + 0.5 * sin(time * 2.5)  // 0→1→0 smoothly

        let outerMult: CGFloat = 1.5
        let innerMult: CGFloat = 0.7
        let currentMult = outerMult - (outerMult - innerMult) * slideProgress

        // Project intercept position to screen
        let targetPos = CourtRenderer.courtPoint(nx: activeShotTargetNX, ny: activeShotTargetNY)
        let targetScale = CourtRenderer.perspectiveScale(ny: activeShotTargetNY)

        for i in 0..<min(4, guideArrows.count) {
            let arrow = guideArrows[i]
            let baseOffset = guideArrowBaseOffsets[i]

            let offsetX = baseOffset.x * targetScale * currentMult
            let offsetY = baseOffset.y * targetScale * currentMult * 0.6

            arrow.position = CGPoint(
                x: targetPos.x + offsetX,
                y: targetPos.y + offsetY
            )
            arrow.setScale(targetScale)
            arrow.alpha = 0.85
        }
    }

    private func updateJumpButtonVisual() {
        let canJump = controller.jumpPhase == .grounded
            && controller.jumpCooldownTimer <= 0
            && controller.stamina >= P.jumpMinStamina
        jumpButtonBg.fillColor = canJump
            ? UIColor.systemCyan.withAlphaComponent(0.35)
            : UIColor.gray.withAlphaComponent(0.2)
        jumpButtonBg.strokeColor = canJump
            ? UIColor.systemCyan.withAlphaComponent(0.6)
            : UIColor.gray.withAlphaComponent(0.3)
        jumpButtonLabel.fontColor = canJump ? .white : UIColor.white.withAlphaComponent(0.3)

        // Flash when airborne
        if controller.jumpPhase != .grounded {
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
                    if timeToContact <= leadTime && timeToContact > 0 && controller.joystickMagnitude < 0.1 && controller.playerShotAnimTimer <= 0 {
                        controller.playerAnimator.playSplitStep()
                        controller.playerSpriteFlipped = false
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
                    let distToPlayer = abs(ballSim.courtY - controller.playerNY)
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

    // (movePlayer is in controller)

    // MARK: - Pending Shot Timing

    /// Tick pending player/NPC shots — launches ball at mid-swing
    private func tickPendingShots(dt: CGFloat) {
        if var shot = pendingPlayerShot {
            shot.timer -= dt
            if shot.timer <= 0 {
                ballSim.launch(
                    from: shot.origin, toward: shot.target,
                    power: shot.power, arc: shot.arc,
                    spin: shot.spin, topspin: shot.topspin,
                    allowNetHit: shot.allowNetHit
                )
                ballSim.smashFactor = shot.smashFactor
                ballSim.isPutAway = shot.isPutAway
                ballSim.lastHitByPlayer = true
                previousBallNY = ballSim.courtY
                checkedFirstBounce = false
                ballNode.alpha = 1
                ballShadow.alpha = 1
                let predicted = ballSim.predictIdealIntercept()
                showShotMarkers(
                    intendedNX: shot.intendedNX, intendedNY: shot.intendedNY,
                    scatterRadius: shot.scatterRadius,
                    interceptNX: predicted.x, interceptNY: predicted.y
                )
                lastShotPower = shot.power
                let speed = sqrt(ballSim.vx * ballSim.vx + ballSim.vy * ballSim.vy)
                maxBallSpeedThisPoint = max(maxBallSpeedThisPoint, speed)
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
                    spin: shot.spin, topspin: shot.topspin,
                    allowNetHit: shot.allowNetHit
                )
                ballSim.smashFactor = shot.smashFactor
                ballSim.isPutAway = shot.isPutAway
                ballSim.lastHitByPlayer = false
                previousBallNY = ballSim.courtY
                checkedFirstBounce = false
                ballNode.alpha = 1
                ballShadow.alpha = 1
                let predicted = ballSim.predictIdealIntercept()
                showShotMarkers(
                    intendedNX: shot.intendedNX, intendedNY: shot.intendedNY,
                    scatterRadius: shot.scatterRadius,
                    interceptNX: predicted.x, interceptNY: predicted.y
                )
                lastShotPower = shot.power
                let speed = sqrt(ballSim.vx * ballSim.vx + ballSim.vy * ballSim.vy)
                maxBallSpeedThisPoint = max(maxBallSpeedThisPoint, speed)
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
                let predicted = ballSim.predictIdealIntercept()
                showShotMarkers(
                    intendedNX: serve.intendedNX, intendedNY: serve.intendedNY,
                    scatterRadius: serve.scatterRadius,
                    interceptNX: predicted.x, interceptNY: predicted.y
                )
                lastShotPower = serve.power
                let speed = sqrt(ballSim.vx * ballSim.vx + ballSim.vy * ballSim.vy)
                maxBallSpeedThisPoint = max(maxBallSpeedThisPoint, speed)
                pendingServeShot = nil
            } else {
                pendingServeShot = serve
            }
        }
    }

    // (sweptBallDistance is in controller)

    // MARK: - Hit Detection

    private func checkPlayerHit() {
        guard ballSim.isActive && !ballSim.lastHitByPlayer else { return }
        guard ballSim.bounceCount < 2 else { return }

        let hitboxRadius = controller.hitboxRadius

        // Two-bounce rule: during serve return (rally 0) and 3rd shot (rally 1),
        // the ball MUST bounce before being hit. Instead of penalizing a "volley fault",
        // simply ignore the ball — the player's avatar auto-moves and can't avoid it.
        if rallyLength < 2 && ballSim.bounceCount == 0 { return }

        let heightReach = controller.heightReach + controller.jumpHeightBonus
        let excessHeight_dbg = max(0, ballSim.height - heightReach)

        // Swept collision via controller (anti-tunneling)
        let dist = controller.checkHitDistance(
            ballX: ballSim.courtX, ballY: ballSim.courtY, ballHeight: ballSim.height
        )

        // Also compute simple 2D distance for logging
        let dx_dbg = ballSim.courtX - controller.playerNX
        let dy_dbg = ballSim.courtY - controller.playerNY
        let dist2D_dbg = sqrt(dx_dbg * dx_dbg + dy_dbg * dy_dbg)

        let ballSpeed_dbg = sqrt(ballSim.vx * ballSim.vx + ballSim.vy * ballSim.vy)

        // Log ball approaching player when it's within 2x hitbox (to see near-misses too)
        if dist <= hitboxRadius * 2.0 {
            dbg.logBallApproachingPlayer(
                ballX: ballSim.courtX, ballY: ballSim.courtY, ballHeight: ballSim.height,
                ballVX: ballSim.vx, ballVY: ballSim.vy, ballVZ: ballSim.vz,
                ballSpeed: ballSpeed_dbg, ballSpin: ballSim.spinCurve, ballTopspin: ballSim.topspinFactor,
                bounceCount: ballSim.bounceCount,
                playerNX: controller.playerNX, playerNY: controller.playerNY,
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

        // Determine shot mode from joystick swipe state
        var shotModes = determineShotMode()

        // Auto-upgrade to power at the kitchen when ball is high (put-away opportunity)
        // Touch mode blocks the put-away/smash logic in the calculator, so force power
        let distFromNet = abs(0.5 - controller.playerNY)
        if distFromNet < P.kitchenVolleyRange
            && ballSim.height > P.smashHeightThreshold
            && shotModes.contains(.touch) {
            shotModes = [.power]
        }

        // Power mode stamina drain
        if shotModes.contains(.power) {
            controller.stamina = max(0, controller.stamina - P.maxStamina * P.powerShotStaminaDrain)
        }

        let ballFromLeft = ballSim.courtX < controller.playerNX
        let staminaPct = controller.stamina / P.maxStamina

        // Save shot context for NPC shot quality assessment
        npcAI.lastPlayerShotModes = shotModes
        npcAI.lastPlayerHitBallHeight = ballSim.height
        // Compute player-side difficulty using ball speed / distance
        let pBallSpeed = sqrt(ballSim.vx * ballSim.vx + ballSim.vy * ballSim.vy)
        let pMaxSpeed = P.baseShotSpeed + 2.0 * (P.maxShotSpeed - P.baseShotSpeed)
        let pSpeedFrac = max(0, min(1, (pBallSpeed - P.baseShotSpeed) / (pMaxSpeed - P.baseShotSpeed)))
        let pDX = ballSim.courtX - controller.playerNX
        let pDY = ballSim.courtY - controller.playerNY
        let pDist = sqrt(pDX * pDX + pDY * pDY)
        let pStretch = min(pDist / hitboxRadius, 1.0)
        npcAI.lastPlayerHitDifficulty = pSpeedFrac * 0.5 + pStretch * 0.5

        var shot = DrillShotCalculator.calculatePlayerShot(
            stats: playerStats,
            ballApproachFromLeft: ballFromLeft,
            drillType: .baselineRally,
            ballHeight: ballSim.height,
            ballHeightAtNet: ballSim.heightAtNetCrossing,
            courtNY: controller.playerNY,
            modes: shotModes,
            staminaFraction: staminaPct,
            shooterDUPR: player.duprRating
        )

        lastHitScatter = shot.scatter

        // Apply joystick aim direction (only when touching joystick)
        if let aim = joystickAimTarget() {
            shot.targetNX = max(0.15, min(0.85, aim.nx))
            shot.targetNY = max(0.55, min(0.95, aim.ny))
        }

        // Apply power boost from joystick distance past circle edge
        if shotModes.contains(.power) {
            shot.power = min(shot.power + joystickPowerBoost(), 2.5)
        }

        // --- Net fault: low-stat players hit into the net ---
        let accuracyStat_nf = CGFloat(playerStats.stat(.accuracy))
        let consistencyStat_nf = CGFloat(playerStats.stat(.consistency))
        let focusStat_nf = CGFloat(playerStats.stat(.focus))
        let avgControl_nf = (accuracyStat_nf + consistencyStat_nf + focusStat_nf) / 3.0
        let netFaultRate = PB.netFaultBaseRate * pow(1.0 - avgControl_nf / 99.0, 1.5)
        let netFaultRoll = CGFloat.random(in: 0...1)
        let isNetFault = netFaultRoll < netFaultRate
        if isNetFault {
            shot.arc *= 0.15
        }

        // Flash shot type label
        if shotModes.contains(.power) {
            showShotTypeFlash("POWER!", color: .systemRed)
        } else if shotModes.contains(.touch) {
            showShotTypeFlash("TOUCH", color: .systemTeal)
        }

        dbg.logPlayerHit(
            modes: shotModes,
            stamina: controller.stamina,
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
        let isVolley = ballSim.bounceCount == 0 && controller.jumpPhase == .grounded
        if (controller.jumpPhase != .grounded || shot.smashFactor > 0) && !shotModes.contains(.touch) {
            animState = .smash(isNear: true)
        } else if isVolley && shotModes.contains(.touch) {
            // Touch volley: soft dink push (no swing animation)
            animState = .run(isNear: true)
            playerDinkPushTimer = dinkPushDuration
        } else if isVolley {
            // Volley: show swing animation (forehand/backhand)
            animState = shot.shotType == .forehand
                ? .forehand(isNear: true) : .backhand(isNear: true)
        } else if controller.playerNY > dinkKitchenThreshold && !shotModes.contains(.power) {
            // Dink at kitchen: use run animation + push motion
            animState = .run(isNear: true)
            playerDinkPushTimer = dinkPushDuration
        } else {
            animState = shot.shotType == .forehand
                ? .forehand(isNear: true) : .backhand(isNear: true)
        }
        controller.playerAnimator.play(animState)
        controller.playerShotAnimTimer = shotAnimDuration
        controller.playerSpriteFlipped = false

        // Sound + haptic
        let isSmashShot = (controller.jumpPhase != .grounded || shot.smashFactor > 0) && !shotModes.contains(.touch)
        if isSmashShot {
            run(SoundManager.shared.skAction(for: .paddleHitSmash))
        } else {
            run(SoundManager.shared.skAction(for: .paddleHit))
        }

        // Hide ball during swing wind-up (it reappears on launch)
        ballSim.isActive = false
        ballNode.alpha = 0
        ballShadow.alpha = 0
        ballTrailOuter.alpha = 0
        ballTrailInner.alpha = 0
        ballTrailHistory.removeAll()

        // Push player shot X to NPC pattern memory (keep last 5)
        npcAI.playerShotHistory.append(shot.targetNX)
        if npcAI.playerShotHistory.count > 5 {
            npcAI.playerShotHistory.removeFirst()
        }

        // Accumulate pressure: player at kitchen hitting while NPC is deep
        if controller.playerNY >= P.pressurePlayerKitchenNY && npcAI.currentNY >= P.pressureNPCDeepNY {
            npcAI.pressureShotCount += 1
        }

        // Defer ball launch to mid-swing
        pendingPlayerShot = PendingShot(
            origin: CGPoint(x: controller.playerNX, y: controller.playerNY),
            target: CGPoint(x: shot.targetNX, y: shot.targetNY),
            power: shot.power,
            arc: shot.arc,
            spin: shot.spinCurve,
            topspin: shot.topspinFactor,
            smashFactor: shot.smashFactor,
            isPutAway: shot.isPutAway,
            isPlayer: true,
            targetNX: shot.targetNX,
            targetNY: shot.targetNY,
            accuracy: shot.accuracy,
            allowNetHit: isNetFault,
            intendedNX: shot.intendedNX,
            intendedNY: shot.intendedNY,
            scatterRadius: shot.scatterRadius,
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
            // Pre-select modes so shot type is context-aware
            npcAI.preselectModes(ball: ballSim)

            // NPC errors now come from physics-based scatter pushing targets
            // outside court bounds — no shouldMakeError roll needed.

            rallyLength += 1
            let shot = npcAI.generateShot(ball: ballSim)
            lastHitScatter = shot.scatter

            dbg.logNPCHit(
                modes: npcAI.lastShotModes,
                stamina: npcAI.stamina,
                targetNX: shot.targetNX,
                targetNY: shot.targetNY,
                power: shot.power,
                arc: shot.arc,
                spinCurve: shot.spinCurve,
                topspinFactor: shot.topspinFactor,
                errorRate: 0
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
        ballTrailOuter.alpha = 0
        ballTrailInner.alpha = 0
        ballTrailHistory.removeAll()

            // Defer ball launch to mid-swing
            pendingNPCShot = PendingShot(
                origin: CGPoint(x: npcAI.currentNX, y: npcAI.currentNY),
                target: CGPoint(x: shot.targetNX, y: shot.targetNY),
                power: shot.power,
                arc: shot.arc,
                spin: shot.spinCurve,
                topspin: shot.topspinFactor,
                smashFactor: shot.smashFactor,
                isPutAway: shot.isPutAway,
                isPlayer: false,
                targetNX: shot.targetNX,
                targetNY: shot.targetNY,
                accuracy: shot.accuracy,
                allowNetHit: false,
                intendedNX: shot.intendedNX,
                intendedNY: shot.intendedNY,
                scatterRadius: shot.scatterRadius,
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

    // syncPlayerPosition is now handled by controller.syncPositions(additionalYOffset:)
    private func dinkPushYOffset() -> CGFloat {
        guard playerDinkPushTimer > 0 else { return 0 }
        let pScale = CourtRenderer.perspectiveScale(ny: max(0, min(1, controller.playerNY)))
        let progress = 1.0 - playerDinkPushTimer / dinkPushDuration
        return sin(progress * .pi) * 8.0 * pScale
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
        // Add current position to history
        ballTrailHistory.append(ballScreenPos)

        // Trim by max points
        if ballTrailHistory.count > ballTrailMaxPoints {
            ballTrailHistory.removeFirst(ballTrailHistory.count - ballTrailMaxPoints)
        }

        // Trim by max length — walk backward from head, remove points beyond max distance
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

        // Ball speed → fire intensity (0 = gentle yellow, 1 = fiery red/orange)
        let ballSpeed = sqrt(ballSim.vx * ballSim.vx + ballSim.vy * ballSim.vy)
        let maxSpeed = P.baseShotSpeed + 2.0 * (P.maxShotSpeed - P.baseShotSpeed)
        let fireIntensity = min(ballSpeed / maxSpeed, 1.0)

        // Head half-width = half the ball radius
        let headHalfWidth = AC.Sprites.ballSize * pScale * 0.25
        let count = ballTrailHistory.count

        // Build tapered trail shape with convex (teardrop) profile
        // Outer trail is full width, inner trail is 55% width
        let outerPath = buildTrailPath(halfWidth: headHalfWidth, count: count)
        let innerPath = buildTrailPath(halfWidth: headHalfWidth * 0.55, count: count)

        // Color based on speed: slow = yellow, fast = red edges / orange core
        // Outer layer: yellow → red
        let outerR: CGFloat = 1.0
        let outerG: CGFloat = 0.85 - fireIntensity * 0.65  // 0.85 → 0.20
        let outerB: CGFloat = 0.1 * (1.0 - fireIntensity)
        let outerAlpha: CGFloat = 0.3 + fireIntensity * 0.25
        ballTrailOuter.fillColor = UIColor(red: outerR, green: outerG, blue: outerB, alpha: outerAlpha)
        ballTrailOuter.path = outerPath
        ballTrailOuter.alpha = 1
        ballTrailOuter.zPosition = AC.ZPositions.ball - 0.2 - CGFloat(ballSim.courtY) * 0.1

        // Inner layer: yellow → bright orange
        let innerR: CGFloat = 1.0
        let innerG: CGFloat = 0.92 - fireIntensity * 0.42  // 0.92 → 0.50
        let innerB: CGFloat = 0.2 * (1.0 - fireIntensity)
        let innerAlpha: CGFloat = 0.45 + fireIntensity * 0.25
        ballTrailInner.fillColor = UIColor(red: innerR, green: innerG, blue: innerB, alpha: innerAlpha)
        ballTrailInner.path = innerPath
        ballTrailInner.alpha = 1
        ballTrailInner.zPosition = AC.ZPositions.ball - 0.1 - CGFloat(ballSim.courtY) * 0.1
    }

    /// Build a closed convex (teardrop) trail path from the position history.
    /// `halfWidth` is the half-width at the head (ball end). Tapers to a point at the tail.
    private func buildTrailPath(halfWidth: CGFloat, count: Int) -> CGPath {
        var topEdge: [CGPoint] = []
        var bottomEdge: [CGPoint] = []

        for i in 0..<count {
            let p = ballTrailHistory[i]
            let t = CGFloat(i) / CGFloat(count - 1)  // 0 at tail, 1 at head

            // Convex teardrop taper: bulges wide near head, then converges sharply to a point
            // sin(t * π/2) stays wide longer then drops; pow(..., 0.7) adds extra convexity
            let taper = pow(sin(t * .pi / 2), 0.7)
            let halfW = halfWidth * taper

            // Direction perpendicular to trail at this point
            let next = i < count - 1 ? ballTrailHistory[i + 1] : p
            let prev = i > 0 ? ballTrailHistory[i - 1] : p
            let dx = next.x - prev.x
            let dy = next.y - prev.y
            let len = sqrt(dx * dx + dy * dy)

            let nx: CGFloat, ny: CGFloat
            if len > 0.01 {
                nx = -dy / len  // perpendicular
                ny = dx / len
            } else {
                nx = 0
                ny = 1
            }

            topEdge.append(CGPoint(x: p.x + nx * halfW, y: p.y + ny * halfW))
            bottomEdge.append(CGPoint(x: p.x - nx * halfW, y: p.y - ny * halfW))
        }

        // Build closed path: top edge forward, semicircle cap at head, bottom edge backward
        let path = CGMutablePath()
        path.move(to: topEdge[0])
        for i in 1..<topEdge.count {
            path.addLine(to: topEdge[i])
        }

        // Rounded cap at the head: semicircle from topEdge.last to bottomEdge.last
        let headTop = topEdge[topEdge.count - 1]
        let headBot = bottomEdge[bottomEdge.count - 1]
        let headCenter = CGPoint(x: (headTop.x + headBot.x) / 2,
                                 y: (headTop.y + headBot.y) / 2)
        let capRadius = sqrt(pow(headTop.x - headCenter.x, 2) + pow(headTop.y - headCenter.y, 2))
        if capRadius > 0.5 {
            // Compute the angle from center to top and bottom edges
            let angleTop = atan2(headTop.y - headCenter.y, headTop.x - headCenter.x)
            let angleBot = atan2(headBot.y - headCenter.y, headBot.x - headCenter.x)
            // Arc from top edge around the front to bottom edge (clockwise)
            path.addArc(center: headCenter, radius: capRadius,
                        startAngle: angleTop, endAngle: angleBot, clockwise: true)
        }

        for i in stride(from: bottomEdge.count - 1, through: 0, by: -1) {
            path.addLine(to: bottomEdge[i])
        }
        path.closeSubpath()
        return path
    }

    private func syncHitboxRings() {
        // Player hitbox rings are synced by controller.syncPositions()

        // NPC rings (use effective hitboxRadius which includes pressure)
        let npcEffectiveHitbox = npcAI.hitboxRadius
        let nPos = CourtRenderer.courtPoint(nx: npcAI.currentNX, ny: npcAI.currentNY)
        let nScale = CourtRenderer.perspectiveScale(ny: npcAI.currentNY)
        let nWidth = CourtRenderer.interpolatedWidth(ny: pow(max(0, min(1, npcAI.currentNY)), MatchAnimationConstants.Court.perspectiveExponent))
        let nScreenRadius = npcEffectiveHitbox * nWidth * 0.5
        let nEdgeRadius = nScreenRadius * 1.5

        npcHitboxRing.position = nPos
        npcHitboxRing.setScale(1.0)
        npcHitboxRing.path = CGPath(ellipseIn: CGRect(
            x: -nScreenRadius, y: -nScreenRadius * nScale,
            width: nScreenRadius * 2, height: nScreenRadius * nScale * 2
        ), transform: nil)

        npcHitboxEdge.position = nPos
        npcHitboxEdge.setScale(1.0)
        npcHitboxEdge.path = CGPath(ellipseIn: CGRect(
            x: -nEdgeRadius, y: -nEdgeRadius * nScale,
            width: nEdgeRadius * 2, height: nEdgeRadius * nScale * 2
        ), transform: nil)

        // Pressure visual: NPC ring turns more red/opaque when under pressure
        let pressureCount = npcAI.pressureShotCount
        if pressureCount > 0 {
            let intensity = min(1.0, CGFloat(pressureCount) * 0.35)
            npcHitboxRing.strokeColor = UIColor.systemOrange.withAlphaComponent(0.5 + intensity * 0.3)
            npcHitboxRing.fillColor = UIColor.systemOrange.withAlphaComponent(0.10 + intensity * 0.12)
        } else {
            npcHitboxRing.strokeColor = UIColor.systemRed.withAlphaComponent(0.7)
            npcHitboxRing.fillColor = UIColor.systemRed.withAlphaComponent(0.15)
        }
    }

    private func syncAllPositions() {
        controller.syncPositions(additionalYOffset: dinkPushYOffset())
        syncNPCPosition()
        syncBallPosition()
    }

    private func updatePlayerStaminaBar() {
        // Position above player sprite
        let screenPos = CourtRenderer.courtPoint(nx: controller.playerNX, ny: max(0, controller.playerNY))
        let pScale = CourtRenderer.perspectiveScale(ny: max(0, min(1, controller.playerNY)))
        playerStaminaBar.position = CGPoint(x: screenPos.x, y: screenPos.y + 30 * pScale + 15)

        // Update fill
        let pct = controller.stamina / P.maxStamina
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
            staminaWarningLabel.text = "LOW STAMINA — Sprint locked • Lunge ⅓"
            staminaWarningLabel.fontColor = .systemRed
            staminaWarningLabel.alpha = CGFloat(0.5 + 0.5 * abs(sin(time * 8)))
        } else if pct <= 0.50 {
            staminaWarningLabel.text = "Sprint halved"
            staminaWarningLabel.fontColor = .systemYellow
            staminaWarningLabel.alpha = 1.0
        } else {
            staminaWarningLabel.alpha = 0
        }

        // Shot type label follows player (below feet)
        shotTypeLabel.position = CGPoint(x: screenPos.x, y: screenPos.y - 25 * pScale)
    }

    /// Reset NPC pressure when they come forward to the kitchen.
    private func updateNPCPressureHitbox() {
        let npcDeep = npcAI.currentNY >= P.pressureNPCDeepNY
        if !npcDeep && npcAI.pressureShotCount > 0 {
            npcAI.pressureShotCount = 0
        }
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

    // MARK: - Player Speech Bubble

    private func showPlayerSpeech(_ text: String) {
        hidePlayerSpeech()

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

        // Position above the near player sprite
        let playerScreenPos = CourtRenderer.courtPoint(nx: controller.playerNX, ny: controller.playerNY)
        bubble.position = CGPoint(x: playerScreenPos.x, y: playerScreenPos.y + 120)

        bubble.alpha = 0
        addChild(bubble)

        bubble.run(.sequence([
            .fadeIn(withDuration: 0.2),
            .wait(forDuration: 2.5),
            .fadeOut(withDuration: 0.4),
            .removeFromParent()
        ]))

        playerSpeechBubble = bubble
    }

    private func hidePlayerSpeech() {
        playerSpeechBubble?.removeAllActions()
        playerSpeechBubble?.removeFromParent()
        playerSpeechBubble = nil
    }

    private func serveScoreText() -> String {
        if servingSide == .player {
            return "\(playerScore)-\(npcScore)!"
        } else {
            return "\(npcScore)-\(playerScore)!"
        }
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

    // MARK: - Post-Match Handshake

    // Post-match quips now use PersonalityDialog via NPC.dialogPersonality

    private func showPostMatchBubble(above node: SKSpriteNode, text: String, duration: TimeInterval = 2.5) {
        let bubble = SKNode()
        bubble.zPosition = AC.ZPositions.text + 8

        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 10
        label.fontColor = .white
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = 140
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

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

        bubble.position = CGPoint(x: node.position.x, y: node.position.y + 60)
        bubble.alpha = 0
        addChild(bubble)

        bubble.run(.sequence([
            .fadeIn(withDuration: 0.2),
            .wait(forDuration: duration),
            .fadeOut(withDuration: 0.4),
            .removeFromParent()
        ]))
    }

    private func playPostMatchAnimation(result: MatchResult) {
        phase = .postMatch
        hideSwipeHint()
        hideNPCSpeech()
        hidePlayerSpeech()
        serveClockActive = false
        serveClockNode.alpha = 0

        // Net meet positions (both walk to center near net)
        let playerMeetPos = CourtRenderer.courtPoint(nx: 0.5, ny: 0.42)
        let npcMeetPos = CourtRenderer.courtPoint(nx: 0.5, ny: 0.58)

        // Scale for meet positions
        let playerMeetScale = AC.Sprites.nearPlayerScale * CourtRenderer.perspectiveScale(ny: 0.42)
        let npcMeetScale = AC.Sprites.farPlayerScale * CourtRenderer.perspectiveScale(ny: 0.58)

        // Start walk animations
        controller.playerAnimator.play(.runFront)  // near player walks toward net (away from camera)
        npcAnimator.play(.runFront)     // far player walks toward net (toward camera)

        let walkDuration: TimeInterval = 1.5

        // Player walks to net
        controller.playerNode.run(.group([
            .move(to: playerMeetPos, duration: walkDuration),
            .scale(to: playerMeetScale, duration: walkDuration)
        ]))

        // NPC walks to net
        npcNode.run(.group([
            .move(to: npcMeetPos, duration: walkDuration),
            .scale(to: npcMeetScale, duration: walkDuration)
        ]))

        // Get personality quip via dialog personality
        let didNPCWin = !result.didPlayerWin
        let quipContext: PersonalityDialog.Context = didNPCWin ? .postMatchWin : .postMatchLoss
        let quip = PersonalityDialog.randomLine(for: npc.dialogPersonality, context: quipContext)

        // Timeline using sequence of waits + run blocks
        let playerName = player.name.components(separatedBy: " ").first ?? player.name
        run(.sequence([
            // 1.5s — both arrive, switch to idle
            .wait(forDuration: walkDuration),
            .run { [weak self] in
                self?.controller.playerAnimator.play(.idle(isNear: true))
                self?.npcAnimator.play(.idle(isNear: false))
            },
            // 1.8s — NPC says "Good game, [name]!"
            .wait(forDuration: 0.3),
            .run { [weak self] in
                guard let self else { return }
                self.showPostMatchBubble(above: self.npcNode, text: "Good game, \(playerName)!", duration: 1.8)
            },
            // 3.8s — NPC personality quip
            .wait(forDuration: 2.0),
            .run { [weak self] in
                guard let self else { return }
                self.showPostMatchBubble(above: self.npcNode, text: quip, duration: 2.0)
            },
            // 6.3s — deliver result to SwiftUI
            .wait(forDuration: 2.5),
            .run { [weak self] in
                self?.onComplete(result)
            }
        ]))
    }

    // MARK: - NPC Walkoff

    private func triggerNPCWalkoff() {
        guard !npcIsWalkingOff, phase != .matchOver else { return }
        npcIsWalkingOff = true
        phase = .matchOver // prevent further play
        controller.resetJoystick()
        ballSim.reset()
        ballNode.alpha = 0
        ballShadow.alpha = 0
        ballTrailOuter.alpha = 0
        ballTrailInner.alpha = 0
        ballTrailHistory.removeAll()
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
                finalEnergy: Double(controller.stamina)
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
