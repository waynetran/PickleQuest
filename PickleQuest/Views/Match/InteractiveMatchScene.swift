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

    // Shot mode buttons
    private var activeShotModes: DrillShotCalculator.ShotMode = []
    private var shotModeButtons: [SKNode] = []
    private var shotModeBgs: [SKShapeNode] = []
    private var shotModeTouch: UITouch?

    // Stamina
    private var stamina: CGFloat = P.maxStamina
    private var timeSinceLastSprint: CGFloat = 10

    // HUD
    private var hudContainer: SKNode!
    private var hudBackground: SKShapeNode!
    private var scoreLabel: SKLabelNode!
    private var servingIndicator: SKLabelNode!
    private var hudStaminaBarBg: SKShapeNode!
    private var hudStaminaBarFill: SKShapeNode!
    private var hudStaminaValue: SKLabelNode!
    private var hudStaminaWarning: SKLabelNode!
    private var outcomeLabel: SKLabelNode!

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
    private let onComplete: (MatchResult) -> Void

    // MARK: - Init

    init(
        player: Player,
        npc: NPC,
        npcAppearance: CharacterAppearance,
        isRated: Bool,
        wagerAmount: Int,
        onComplete: @escaping (MatchResult) -> Void
    ) {
        self.player = player
        self.npc = npc
        self.npcAppearance = npcAppearance
        self.isRated = isRated
        self.wagerAmount = wagerAmount
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

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        buildScene()
        setupHUD()
    }

    // MARK: - Public API

    func beginMatch() {
        guard phase == .waitingToStart else { return }
        matchStartTime = Date()
        hudContainer.alpha = 1
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

    // MARK: - Match Flow

    private func startNextPoint() {
        rallyLength = 0
        ballSim.reset()
        ballNode.alpha = 0
        ballShadow.alpha = 0

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
        updateScoreHUD()
    }

    private func playerServe(from startPos: CGPoint, to endPos: CGPoint) {
        let dx = endPos.x - startPos.x
        let dy = endPos.y - startPos.y
        let distance = sqrt(dx * dx + dy * dy)

        guard dy > 0, distance >= P.serveSwipeMinDistance else { return }

        let swipeAngle = atan2(dx, dy)
        let angleDeviation = max(-P.serveSwipeAngleRange, min(P.serveSwipeAngleRange, swipeAngle))
        let rawPowerFactor = distance / P.serveSwipeMaxPower

        let accuracyStat = CGFloat(playerStats.stat(.accuracy))
        let focusStat = CGFloat(playerStats.stat(.focus))
        let scatterReduction = ((accuracyStat + focusStat) / 2.0) / 99.0
        let scatter = (1.0 - scatterReduction * 0.7) * 0.15
        let scatterX = CGFloat.random(in: -scatter...scatter)
        let scatterY = CGFloat.random(in: -scatter...scatter)

        let baseTargetNY: CGFloat = 0.55 + rawPowerFactor * 0.50
        let targetNX = max(0.15, min(0.85, 0.5 + angleDeviation + scatterX))
        let targetNY = max(0.50, min(1.10, baseTargetNY + scatterY))

        let servePower = 0.10 + min(rawPowerFactor, 1.3) * 0.75
        let serveArc: CGFloat = max(0.10, 0.55 - rawPowerFactor * 0.40)

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

        // Target cross-court to player's side
        let evenScore = npcScore % 2 == 0
        let targetNX: CGFloat = evenScore ? 0.25 : 0.75
        let targetNY: CGFloat = CGFloat.random(in: 0.05...0.18)

        phase = .playing
        ballSim.launch(
            from: CGPoint(x: npcAI.currentNX, y: npcAI.currentNY),
            toward: CGPoint(x: targetNX, y: targetNY),
            power: shot.power,
            arc: shot.arc,
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

    private func resolvePoint(_ result: PointResult) {
        ballSim.reset()
        ballNode.alpha = 0
        ballShadow.alpha = 0
        totalPointsPlayed += 1

        // Update rally stats
        if rallyLength > longestRally { longestRally = rallyLength }
        totalRallyShots += rallyLength

        switch result {
        case .playerWon:
            if servingSide == .player {
                playerScore += 1
            } else {
                // Side-out: player gains serve
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
                // Side-out: NPC gains serve
                servingSide = .opponent
            }
            playerCurrentStreak = 0
        }

        updateScoreHUD()

        // Check for match end
        if isMatchOver() {
            endMatch(wasResigned: false)
            return
        }

        phase = .pointOver
        pointOverTimer = IM.pointOverPauseDuration
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

        // Generate loot
        let lootGen = LootGenerator()
        let suprGap = npc.duprRating - player.duprRating
        let loot = lootGen.generateMatchLoot(
            didWin: didPlayerWin,
            opponentDifficulty: npc.difficulty,
            playerLevel: player.progression.level,
            suprGap: suprGap
        )

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

            // Swipe to serve (player serving)
            if phase == .serving && servingSide == .player {
                swipeTouchStart = pos
                return
            }

            guard phase == .playing || phase == .serving else { return }

            // Check shot mode buttons
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
            previousBallNY = ballSim.courtY
            ballSim.update(dt: dt)
            npcAI.update(dt: dt, ball: ballSim)
            checkPlayerHit()
            checkNPCHit()
            checkBallState()
            syncAllPositions()
            updateStaminaBar()
            updateNPCBossBar()

        case .serving:
            movePlayer(dt: dt)
            syncAllPositions()
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

        if npcAI.shouldSwing(ball: ballSim) {
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
            showIndicator("Net!", color: .systemRed)
            resolvePoint(lastHitter)
            return
        }

        // Double bounce
        if ballSim.isDoubleBounce {
            if ballSim.courtY < 0.5 {
                // Ball double-bounced on player's side
                if ballSim.lastHitByPlayer {
                    // Player hit it but it came back and double bounced on their side (shouldn't normally happen)
                    playerErrors += 1
                    showIndicator("Out!", color: .systemOrange)
                } else {
                    // NPC's shot landed on player's side — NPC wins point
                    if rallyLength <= 1 { npcAces += 1 } else { npcWinners += 1 }
                    showIndicator("Double Bounce", color: .systemYellow)
                }
                resolvePoint(.npcWon)
            } else {
                // Ball double-bounced on NPC's side
                if ballSim.lastHitByPlayer {
                    if rallyLength <= 1 { playerAces += 1 } else { playerWinners += 1 }
                    showIndicator("Winner!", color: .systemGreen)
                } else {
                    npcErrors += 1
                    showIndicator("Out!", color: .systemOrange)
                }
                resolvePoint(.playerWon)
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
            resolvePoint(lastHitter)
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
            resolvePoint(lastHitter)
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

    // MARK: - HUD

    private var hudBarWidthCurrent: CGFloat = 100
    private let hudBarHeight: CGFloat = 10

    private func setupHUD() {
        let fontName = AC.Text.fontName
        let margin: CGFloat = 8
        let containerWidth: CGFloat = AC.sceneWidth - margin * 2
        let rowHeight: CGFloat = 20
        let padding: CGFloat = 8
        let rowCount: CGFloat = 3 // score, serving indicator, stamina
        let containerHeight = rowCount * rowHeight + padding * 2
        let barX: CGFloat = 62
        let barWidth = containerWidth - barX - 10

        hudBarWidthCurrent = barWidth

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

        let row1Y = containerHeight - padding - rowHeight * 0.5
        let row2Y = row1Y - rowHeight
        let row3Y = row2Y - rowHeight

        // Row 1: Score
        scoreLabel = SKLabelNode(text: "You  0 — 0  \(npc.name)")
        scoreLabel.fontName = "AvenirNext-Heavy"
        scoreLabel.fontSize = 14
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: containerWidth / 2, y: row1Y)
        scoreLabel.zPosition = 1
        hudContainer.addChild(scoreLabel)

        // Row 2: Serving indicator
        servingIndicator = SKLabelNode(text: "")
        servingIndicator.fontName = fontName
        servingIndicator.fontSize = 10
        servingIndicator.fontColor = UIColor.systemYellow
        servingIndicator.horizontalAlignmentMode = .center
        servingIndicator.verticalAlignmentMode = .center
        servingIndicator.position = CGPoint(x: containerWidth / 2, y: row2Y)
        servingIndicator.zPosition = 1
        hudContainer.addChild(servingIndicator)

        // Row 3: Stamina bar
        let staminaLabel = SKLabelNode(text: "Stamina")
        staminaLabel.fontName = fontName
        staminaLabel.fontSize = 11
        staminaLabel.fontColor = UIColor(white: 0.85, alpha: 1)
        staminaLabel.horizontalAlignmentMode = .left
        staminaLabel.verticalAlignmentMode = .center
        staminaLabel.position = CGPoint(x: 10, y: row3Y)
        staminaLabel.zPosition = 1
        hudContainer.addChild(staminaLabel)

        hudStaminaBarBg = SKShapeNode(rect: CGRect(x: 0, y: -hudBarHeight / 2, width: barWidth, height: hudBarHeight), cornerRadius: 4)
        hudStaminaBarBg.fillColor = UIColor(white: 0.2, alpha: 0.8)
        hudStaminaBarBg.strokeColor = .clear
        hudStaminaBarBg.position = CGPoint(x: barX, y: row3Y)
        hudStaminaBarBg.zPosition = 1
        hudContainer.addChild(hudStaminaBarBg)

        hudStaminaBarFill = SKShapeNode(rect: CGRect(x: 0, y: -hudBarHeight / 2, width: barWidth, height: hudBarHeight), cornerRadius: 4)
        hudStaminaBarFill.fillColor = .systemGreen
        hudStaminaBarFill.strokeColor = .clear
        hudStaminaBarFill.position = CGPoint(x: barX, y: row3Y)
        hudStaminaBarFill.zPosition = 2
        hudContainer.addChild(hudStaminaBarFill)

        hudStaminaValue = SKLabelNode(text: "100%")
        hudStaminaValue.fontName = fontName
        hudStaminaValue.fontSize = 9
        hudStaminaValue.fontColor = .white
        hudStaminaValue.horizontalAlignmentMode = .right
        hudStaminaValue.verticalAlignmentMode = .center
        hudStaminaValue.position = CGPoint(x: barX + barWidth - 4, y: row3Y)
        hudStaminaValue.zPosition = 3
        hudContainer.addChild(hudStaminaValue)

        // Stamina warning (below HUD)
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

        // Outcome label (center of court)
        outcomeLabel = SKLabelNode(text: "")
        outcomeLabel.fontName = fontName
        outcomeLabel.fontSize = 36
        outcomeLabel.fontColor = .white
        outcomeLabel.position = CGPoint(x: AC.sceneWidth / 2, y: AC.sceneHeight * 0.45)
        outcomeLabel.zPosition = AC.ZPositions.text + 1
        outcomeLabel.alpha = 0
        addChild(outcomeLabel)

        updateScoreHUD()
    }

    private func updateScoreHUD() {
        scoreLabel.text = "You  \(playerScore) — \(npcScore)  \(npc.name)"

        let serverName = servingSide == .player ? "You" : npc.name
        servingIndicator.text = "Serving: \(serverName)"
    }

    private func updateStaminaBar() {
        let pct = stamina / P.maxStamina
        hudStaminaValue.text = "\(Int(stamina))%"
        let w = max(1, hudBarWidthCurrent * pct)
        hudStaminaBarFill.path = UIBezierPath(
            roundedRect: CGRect(x: 0, y: -hudBarHeight / 2, width: w, height: hudBarHeight),
            cornerRadius: 4
        ).cgPath

        if pct > 0.5 {
            hudStaminaBarFill.fillColor = .systemGreen
        } else if pct > 0.10 {
            hudStaminaBarFill.fillColor = .systemYellow
        } else {
            hudStaminaBarFill.fillColor = .systemRed
        }

        let time = CACurrentMediaTime()
        if pct <= 0.10 {
            let flash = 0.4 + 0.6 * abs(sin(time * 8))
            hudStaminaBarFill.alpha = CGFloat(flash)
            hudStaminaBarBg.alpha = CGFloat(flash)
        } else if pct <= 0.50 {
            let flash = 0.6 + 0.4 * abs(sin(time * 3))
            hudStaminaBarFill.alpha = CGFloat(flash)
            hudStaminaBarBg.alpha = 1.0
        } else {
            hudStaminaBarFill.alpha = 1.0
            hudStaminaBarBg.alpha = 1.0
        }

        if pct <= 0.10 {
            hudStaminaWarning.text = "LOW STAMINA — Power/Focus OFF • Sprint locked"
            hudStaminaWarning.fontColor = .systemRed
            hudStaminaWarning.alpha = CGFloat(0.5 + 0.5 * abs(sin(time * 8)))
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
