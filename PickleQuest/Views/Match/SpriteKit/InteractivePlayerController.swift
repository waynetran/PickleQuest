import SpriteKit
import UIKit

// MARK: - Configuration

struct PlayerControllerConfig {
    var minNX: CGFloat = 0.0
    var maxNX: CGFloat = 1.0
    var minNY: CGFloat = -0.05
    var maxNY: CGFloat = 0.48
    var jumpEnabled: Bool = true
    var lungeEnabled: Bool = true
    var hitboxRingsVisible: Bool = true
}

// MARK: - Lunge Phase

enum LungePhase {
    case none, loading, jumping, landing
}

// MARK: - Interactive Player Controller

/// Shared player physics controller used by both InteractiveMatchScene and InteractiveDrillScene.
/// Owns: position, movement (sprint + stamina), jump state machine, lunge state machine,
/// swept collision hitbox, hitbox rings, joystick input, footstep sounds.
@MainActor
final class InteractivePlayerController {
    private typealias AC = MatchAnimationConstants
    private typealias P = GameConstants.DrillPhysics

    // MARK: - Configuration

    let config: PlayerControllerConfig
    let playerStats: PlayerStats

    // MARK: - Position

    var playerNX: CGFloat
    var playerNY: CGFloat

    // MARK: - Movement

    let playerMoveSpeed: CGFloat
    let playerSprintSpeed: CGFloat  // stat-based: 0.5 + athleticism * 1.0

    // MARK: - Stamina

    var stamina: CGFloat = P.maxStamina
    var timeSinceLastSprint: CGFloat = 10

    // MARK: - Joystick State

    var joystickTouch: UITouch?
    var joystickDirection: CGVector = .zero
    var joystickMagnitude: CGFloat = 0
    var joystickSwipeVelocity: CGVector = .zero
    var joystickOrigin: CGPoint = .zero
    var prevTouchPos: CGPoint = .zero
    var prevTouchTimestamp: TimeInterval = 0
    var prevJoystickMagnitude: CGFloat = 0

    // MARK: - Jump State

    var jumpPhase: JumpPhase = .grounded
    var jumpTimer: CGFloat = 0
    var jumpCooldownTimer: CGFloat = 0
    var jumpHeightBonus: CGFloat = 0

    // MARK: - Lunge State

    var lungePhase: LungePhase = .none
    var lungeTimer: CGFloat = 0
    var lungeDirection: CGFloat = 0  // +1 right, -1 left
    private let lungeLoadDuration: CGFloat = 0.08
    private let lungeJumpDuration: CGFloat = 0.18
    private let lungeLandDuration: CGFloat = 0.08
    private let lungeDistance: CGFloat = 0.50
    private let lungeJumpPeak: CGFloat = 10.0

    // MARK: - Shot Animation Lock

    var playerShotAnimTimer: CGFloat = 0
    let shotAnimDuration: CGFloat = 0.40

    // MARK: - Sprite Flipping

    var playerSpriteFlipped: Bool = false

    // MARK: - Swept Collision State

    var prevBallX: CGFloat = 0.5
    var prevBallY: CGFloat = 0.5
    var prevBallHeight: CGFloat = 0.0

    // MARK: - Hitbox Stats (computed once at init)

    let hitboxRadius: CGFloat
    let heightReach: CGFloat  // base height reach (without jump bonus)

    // MARK: - Footstep Sound

    var footstepTimer: CGFloat = 0
    let footstepInterval: CGFloat = 0.28
    let footstepSprintInterval: CGFloat = 0.18

    // MARK: - Scene Communication

    /// Scene sets true when in playable phase (gates lunge trigger).
    var isPlayable: Bool = false
    /// Scene updates each frame for lunge overshoot prevention.
    var currentBallX: CGFloat = 0.5
    /// Scene updates each frame — lunge stops early if ball is active.
    var isBallActive: Bool = false

    // MARK: - Nodes

    var playerNode: SKSpriteNode!
    var playerAnimator: SpriteSheetAnimator!
    var joystickBase: SKShapeNode!
    var joystickKnob: SKShapeNode!
    var playerHitboxRing: SKShapeNode?
    var playerHitboxEdge: SKShapeNode?

    let joystickBaseRadius: CGFloat = 50
    let joystickKnobRadius: CGFloat = 30
    let joystickDefaultPosition = CGPoint(x: MatchAnimationConstants.sceneWidth / 2, y: 100)

    /// Weak reference to parent scene for running footstep sound actions.
    weak var parentScene: SKScene?

    // MARK: - Init

    init(
        playerStats: PlayerStats,
        appearance: CharacterAppearance,
        startNX: CGFloat,
        startNY: CGFloat,
        config: PlayerControllerConfig = PlayerControllerConfig()
    ) {
        self.playerStats = playerStats
        self.config = config
        self.playerNX = startNX
        self.playerNY = startNY

        let speedStat = CGFloat(playerStats.stat(.speed))
        let reflexesStat = CGFloat(playerStats.stat(.reflexes))
        let athleticism = (speedStat + reflexesStat) / 2.0 / 99.0

        self.playerMoveSpeed = P.baseMoveSpeed + (speedStat / 99.0) * P.maxMoveSpeedBonus
        self.playerSprintSpeed = 0.5 + athleticism * 1.0

        let positioningStat = CGFloat(playerStats.stat(.positioning))
        self.hitboxRadius = P.baseHitboxRadius + (positioningStat / 99.0) * P.positioningHitboxBonus
        self.heightReach = P.baseHeightReach + athleticism * P.maxHeightReachBonus
    }

    // MARK: - Node Building

    /// Creates all SKNodes (player sprite, joystick, hitbox rings) and adds them to parent.
    func buildNodes(parent: SKScene, appearance: CharacterAppearance) {
        self.parentScene = parent

        // Player sprite
        let (pNode, pTextures) = SpriteFactory.makeCharacterNode(appearance: appearance, isNearPlayer: true)
        playerNode = pNode
        playerNode.setScale(AC.Sprites.nearPlayerScale)
        playerNode.zPosition = AC.ZPositions.nearPlayer
        parent.addChild(playerNode)
        playerAnimator = SpriteSheetAnimator(node: playerNode, textures: pTextures, isNear: true)

        // Joystick
        joystickBase = SKShapeNode(circleOfRadius: joystickBaseRadius)
        joystickBase.fillColor = UIColor(white: 0.15, alpha: 0.5)
        joystickBase.strokeColor = UIColor(white: 0.6, alpha: 0.3)
        joystickBase.lineWidth = 2
        joystickBase.zPosition = 15
        joystickBase.position = joystickDefaultPosition
        joystickBase.alpha = 0.4
        parent.addChild(joystickBase)

        joystickKnob = SKShapeNode(circleOfRadius: joystickKnobRadius)
        joystickKnob.fillColor = UIColor(white: 0.8, alpha: 0.6)
        joystickKnob.strokeColor = UIColor(white: 1.0, alpha: 0.4)
        joystickKnob.lineWidth = 1.5
        joystickKnob.zPosition = 16
        joystickKnob.position = joystickDefaultPosition
        joystickKnob.alpha = 0.4
        parent.addChild(joystickKnob)

        // Hitbox visualization rings
        if config.hitboxRingsVisible {
            let hitboxZ = AC.ZPositions.nearPlayer + 1

            let ring = SKShapeNode(circleOfRadius: 1)
            ring.strokeColor = UIColor.systemCyan.withAlphaComponent(0.7)
            ring.fillColor = UIColor.systemCyan.withAlphaComponent(0.15)
            ring.lineWidth = 2.0
            ring.zPosition = hitboxZ
            parent.addChild(ring)
            playerHitboxRing = ring

            let edge = SKShapeNode(circleOfRadius: 1)
            edge.strokeColor = UIColor.systemCyan.withAlphaComponent(0.35)
            edge.fillColor = .clear
            edge.lineWidth = 1.5
            edge.zPosition = hitboxZ
            parent.addChild(edge)
            playerHitboxEdge = edge
        }
    }

    // MARK: - Movement

    /// Main movement method called each frame. Handles joystick input, sprint, stamina, animation, footsteps.
    func movePlayer(dt: CGFloat) {
        let canChangeAnim = playerShotAnimTimer <= 0

        // Tick active lunge regardless of joystick state
        if lungePhase != .none {
            tickLunge(dt: dt)
            return
        }

        guard joystickMagnitude > 0.1 else {
            if canChangeAnim { playerAnimator?.play(.idle(isNear: true)) }
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
        if config.jumpEnabled && jumpPhase != .grounded {
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

        // Joystick sprint visual
        if isSprinting {
            joystickBase?.strokeColor = UIColor.systemRed.withAlphaComponent(0.8)
            joystickBase?.fillColor = UIColor.systemRed.withAlphaComponent(0.2)
            joystickKnob?.fillColor = UIColor.systemRed.withAlphaComponent(0.7)
        } else if joystickTouch != nil {
            joystickBase?.strokeColor = UIColor(white: 0.6, alpha: 0.3)
            joystickBase?.fillColor = UIColor(white: 0.15, alpha: 0.5)
            joystickKnob?.fillColor = UIColor(white: 0.8, alpha: 0.6)
        }

        // Movement animation: direction-aware sprint vs shuffle
        let dx = joystickDirection.dx
        let dy = joystickDirection.dy
        let isMainlyHorizontal = abs(dx) > abs(dy)

        // Apply movement
        playerNX += joystickDirection.dx * speed * dt
        playerNY += joystickDirection.dy * speed * dt

        // Clamp to config bounds
        playerNX = max(config.minNX, min(config.maxNX, playerNX))
        playerNY = max(config.minNY, min(config.maxNY, playerNY))

        if canChangeAnim && lungePhase == .none {
            if isSprinting {
                if isMainlyHorizontal {
                    playerAnimator?.play(.runSide)
                    playerSpriteFlipped = dx < 0
                } else if dy > 0 {
                    playerAnimator?.play(.run(isNear: true))
                    playerSpriteFlipped = false
                } else {
                    playerAnimator?.play(.shuffle(isNear: true))
                    playerSpriteFlipped = false
                }
            } else {
                playerAnimator?.play(.shuffle(isNear: true))
                if abs(dx) > 0.3 {
                    playerSpriteFlipped = dx < 0
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
            parentScene?.run(SoundManager.shared.skAction(for: soundID))
        }
    }

    // MARK: - Jump

    /// Initiate a player jump (called by scene on button tap or auto-jump).
    func initiateJump() {
        guard config.jumpEnabled else { return }
        guard jumpPhase == .grounded else { return }
        guard jumpCooldownTimer <= 0 else { return }
        guard stamina >= P.jumpMinStamina else { return }
        stamina -= P.jumpStaminaCost
        jumpPhase = .rising
        jumpTimer = 0
    }

    /// Update jump state machine each frame.
    func updateJump(dt: CGFloat) {
        guard config.jumpEnabled else { return }

        // Cooldown
        if jumpCooldownTimer > 0 {
            jumpCooldownTimer = max(0, jumpCooldownTimer - dt)
        }

        guard jumpPhase != .grounded else {
            jumpHeightBonus = 0
            return
        }

        jumpTimer += dt
        let totalDuration = P.jumpDuration
        let riseEnd = totalDuration * P.jumpRiseFraction
        let hangEnd = riseEnd + totalDuration * P.jumpHangFraction

        switch jumpPhase {
        case .rising:
            let riseFraction = min(jumpTimer / riseEnd, 1.0)
            jumpHeightBonus = P.jumpHeightReachBonus * riseFraction
            if jumpTimer >= riseEnd {
                jumpPhase = .hanging
            }
        case .hanging:
            jumpHeightBonus = P.jumpHeightReachBonus
            if jumpTimer >= hangEnd {
                jumpPhase = .falling
            }
        case .falling:
            let fallStart = hangEnd
            let fallDuration = totalDuration * P.jumpFallFraction
            let fallFraction = min((jumpTimer - fallStart) / fallDuration, 1.0)
            jumpHeightBonus = P.jumpHeightReachBonus * (1.0 - fallFraction)
            if jumpTimer >= totalDuration {
                jumpPhase = .grounded
                jumpHeightBonus = 0
                jumpCooldownTimer = P.jumpCooldown
            }
        case .grounded:
            break
        }
    }

    /// Sprite Y-offset for player jump visual. Sine arc: 0 → peak → 0.
    var jumpSpriteYOffset: CGFloat {
        guard jumpPhase != .grounded else { return 0 }
        let fraction = min(jumpTimer / P.jumpDuration, 1.0)
        return sin(fraction * .pi) * P.jumpSpriteYOffset
    }

    // MARK: - Lunge

    /// Lunge Y-offset: crouch down during load, hop up during jump, back to 0 on land.
    var lungeSpriteYOffset: CGFloat {
        switch lungePhase {
        case .none:
            return 0
        case .loading:
            let fraction = min(lungeTimer / lungeLoadDuration, 1.0)
            return -3.0 * fraction
        case .jumping:
            let fraction = min(lungeTimer / lungeJumpDuration, 1.0)
            return sin(fraction * .pi) * lungeJumpPeak - 3.0 * (1.0 - fraction)
        case .landing:
            let fraction = min(lungeTimer / lungeLandDuration, 1.0)
            return -2.0 * (1.0 - fraction)
        }
    }

    /// Tick active lunge each frame. Called internally by movePlayer when lungePhase != .none.
    private func tickLunge(dt: CGFloat) {
        lungeTimer += dt
        switch lungePhase {
        case .loading:
            playerAnimator?.play(.idle(isNear: true))
            if lungeTimer >= lungeLoadDuration {
                lungePhase = .jumping
                lungeTimer = 0
                playerAnimator?.play(.shuffle(isNear: true))
                playerSpriteFlipped = lungeDirection < 0
            }
        case .jumping:
            // Airborne — move sideways (stamina < 10% → 1/3 distance)
            let staminaPctLunge = stamina / P.maxStamina
            let effectiveLungeDistance = staminaPctLunge <= 0.10 ? lungeDistance / 3.0 : lungeDistance
            let lungeSpeed = effectiveLungeDistance / lungeJumpDuration
            playerNX += lungeDirection * lungeSpeed * dt
            playerNX = max(config.minNX, min(config.maxNX, playerNX))

            // Stop at ball's X so we don't overshoot
            let overshoot = lungeDirection > 0
                ? playerNX > currentBallX
                : playerNX < currentBallX
            if overshoot && isBallActive {
                playerNX = currentBallX
            }

            let reachedBall = overshoot && isBallActive
            if reachedBall || lungeTimer >= lungeJumpDuration {
                lungePhase = .landing
                lungeTimer = 0
                playerAnimator?.play(.idle(isNear: true))
            }
        case .landing:
            if lungeTimer >= lungeLandDuration {
                lungePhase = .none
                lungeTimer = 0
            }
        case .none:
            break
        }
    }

    /// Start a lunge in the given direction. Called by scene touch handling.
    func startLunge(direction: CGFloat) {
        guard config.lungeEnabled else { return }
        guard lungePhase == .none else { return }
        guard jumpPhase == .grounded else { return }
        lungePhase = .loading
        lungeTimer = 0
        lungeDirection = direction
        playerSpriteFlipped = direction < 0
    }

    // MARK: - Swept Collision

    /// Store previous ball position before ballSim.update(). Called by scene each frame.
    func storeBallPosition(courtX: CGFloat, courtY: CGFloat, height: CGFloat) {
        prevBallX = courtX
        prevBallY = courtY
        prevBallHeight = height
    }

    /// Find minimum 3D distance from ball's path segment (prev→curr) to the player.
    /// Uses closest-point-on-segment in 2D, then evaluates interpolated height.
    /// Prevents fast balls from tunneling through the hitbox between frames.
    func checkHitDistance(ballX: CGFloat, ballY: CGFloat, ballHeight: CGFloat) -> CGFloat {
        let totalHeightReach = heightReach + jumpHeightBonus
        return sweptBallDistance(
            prevX: prevBallX, prevY: prevBallY, prevH: prevBallHeight,
            currX: ballX, currY: ballY, currH: ballHeight,
            targetX: playerNX, targetY: playerNY,
            heightReach: totalHeightReach
        )
    }

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
            t = 1.0
        } else {
            let toTargetX = targetX - prevX
            let toTargetY = targetY - prevY
            t = max(0, min(1, (toTargetX * segDX + toTargetY * segDY) / segLenSq))
        }

        let closestX = prevX + t * segDX
        let closestY = prevY + t * segDY
        let closestH = prevH + t * (currH - prevH)

        let dx = closestX - targetX
        let dy = closestY - targetY
        let excessHeight = max(0, closestH - heightReach)
        return sqrt(dx * dx + dy * dy + excessHeight * excessHeight)
    }

    // MARK: - Position Syncing

    /// Sync player node position, scale, flipping, and hitbox rings.
    /// `additionalYOffset` is used by match scene for dink push.
    func syncPositions(additionalYOffset: CGFloat = 0) {
        guard let playerNode else { return }

        let screenPos = CourtRenderer.courtPoint(nx: playerNX, ny: max(0, playerNY))
        let pScale = CourtRenderer.perspectiveScale(ny: max(0, min(1, playerNY)))

        // Jump Y-offset
        let jumpOffset = jumpSpriteYOffset * pScale

        // Lunge hop Y-offset
        let lungeOffset = lungeSpriteYOffset * pScale

        playerNode.position = CGPoint(
            x: screenPos.x,
            y: screenPos.y + jumpOffset + lungeOffset + additionalYOffset
        )

        // Squash/stretch during jump + sprite flipping
        let baseScale = AC.Sprites.nearPlayerScale * pScale
        if jumpPhase != .grounded {
            let fraction = min(jumpTimer / P.jumpDuration, 1.0)
            let sinVal = sin(fraction * .pi)
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

        // Hitbox rings
        syncHitboxRings(screenPos: screenPos, pScale: pScale)
    }

    private func syncHitboxRings(screenPos: CGPoint, pScale: CGFloat) {
        guard let ring = playerHitboxRing, let edge = playerHitboxEdge else { return }

        let pWidth = CourtRenderer.interpolatedWidth(
            ny: pow(max(0, min(1, playerNY)), AC.Court.perspectiveExponent)
        )
        let pScreenRadius = hitboxRadius * pWidth * 0.5
        let pEdgeRadius = pScreenRadius * 1.5

        ring.position = screenPos
        ring.setScale(1.0)
        ring.path = CGPath(ellipseIn: CGRect(
            x: -pScreenRadius, y: -pScreenRadius * pScale,
            width: pScreenRadius * 2, height: pScreenRadius * pScale * 2
        ), transform: nil)

        edge.position = screenPos
        edge.setScale(1.0)
        edge.path = CGPath(ellipseIn: CGRect(
            x: -pEdgeRadius, y: -pEdgeRadius * pScale,
            width: pEdgeRadius * 2, height: pEdgeRadius * pScale * 2
        ), transform: nil)
    }

    // MARK: - Joystick Touch Handling

    /// Handle touch began for joystick. Returns true if the touch was claimed.
    @discardableResult
    func handleJoystickBegan(touch: UITouch, location: CGPoint) -> Bool {
        guard joystickTouch == nil else { return false }
        joystickTouch = touch
        joystickOrigin = location
        prevJoystickMagnitude = 0
        prevTouchPos = location
        prevTouchTimestamp = CACurrentMediaTime()
        joystickSwipeVelocity = .zero
        joystickBase?.position = location
        joystickKnob?.position = location
        joystickBase?.alpha = 1
        joystickKnob?.alpha = 1
        return true
    }

    /// Handle touch moved for joystick. Also handles lunge trigger detection.
    func handleJoystickMoved(touch: UITouch, location: CGPoint) {
        guard touch === joystickTouch else { return }

        let pos = location

        // Compute swipe velocity with exponential smoothing
        let now = CACurrentMediaTime()
        let dt = now - prevTouchTimestamp
        if dt > 0.001 {
            let rawVX = (pos.x - prevTouchPos.x) / CGFloat(dt)
            let rawVY = (pos.y - prevTouchPos.y) / CGFloat(dt)
            let smoothing: CGFloat = 0.3
            joystickSwipeVelocity = CGVector(
                dx: joystickSwipeVelocity.dx * (1 - smoothing) + rawVX * smoothing,
                dy: joystickSwipeVelocity.dy * (1 - smoothing) + rawVY * smoothing
            )
        }
        prevTouchPos = pos
        prevTouchTimestamp = now

        let dx = pos.x - joystickOrigin.x
        let dy = pos.y - joystickOrigin.y
        let dist = sqrt(dx * dx + dy * dy)

        let maxVisualDist = joystickBaseRadius * 1.5
        if dist <= maxVisualDist {
            joystickKnob?.position = pos
        } else {
            joystickKnob?.position = CGPoint(
                x: joystickOrigin.x + (dx / dist) * maxVisualDist,
                y: joystickOrigin.y + (dy / dist) * maxVisualDist
            )
        }

        joystickMagnitude = min(dist / joystickBaseRadius, 1.5)
        if dist > 1.0 {
            joystickDirection = CGVector(dx: dx / dist, dy: dy / dist)
        }

        // Lunge trigger: joystick crosses boundary while mainly horizontal
        if config.lungeEnabled {
            let prevMag = prevJoystickMagnitude
            prevJoystickMagnitude = joystickMagnitude
            if prevMag < 1.0 && joystickMagnitude >= 1.0
                && abs(dx) > abs(dy) * 1.5
                && lungePhase == .none
                && jumpPhase == .grounded
                && isPlayable {
                startLunge(direction: dx > 0 ? 1.0 : -1.0)
            }
        } else {
            prevJoystickMagnitude = joystickMagnitude
        }
    }

    /// Handle touch ended for joystick. Returns true if the touch was the joystick touch.
    @discardableResult
    func handleJoystickEnded(touch: UITouch) -> Bool {
        guard touch === joystickTouch else { return false }
        resetJoystick()
        return true
    }

    /// Reset joystick state and visuals.
    func resetJoystick() {
        joystickTouch = nil
        joystickDirection = .zero
        joystickMagnitude = 0
        prevJoystickMagnitude = 0
        joystickSwipeVelocity = .zero
        joystickBase?.position = joystickDefaultPosition
        joystickKnob?.position = joystickDefaultPosition
        joystickBase?.alpha = 0.4
        joystickKnob?.alpha = 0.4
    }

    // MARK: - Shot Anim Lock

    /// Lock shot animation for standard duration.
    func setShotAnimLock() {
        playerShotAnimTimer = shotAnimDuration
    }

    // MARK: - Reset

    /// Reset player state for a new point/round. Recovers stamina by `staminaRecovery` amount.
    func resetForNewPoint(startNX: CGFloat, startNY: CGFloat, staminaRecovery: CGFloat = 0) {
        playerNX = startNX
        playerNY = startNY
        jumpPhase = .grounded
        jumpTimer = 0
        jumpCooldownTimer = 0
        jumpHeightBonus = 0
        playerSpriteFlipped = false
        playerShotAnimTimer = 0
        lungePhase = .none
        lungeTimer = 0
        lungeDirection = 0
        joystickSwipeVelocity = .zero
        prevBallX = 0.5
        prevBallY = 0.5
        prevBallHeight = 0.0
        footstepTimer = 0
        stamina = min(P.maxStamina, stamina + staminaRecovery)
    }

    // MARK: - Test Helpers

    #if DEBUG
    func _testSetJoystickInput(direction: CGVector, magnitude: CGFloat) {
        joystickDirection = direction
        joystickMagnitude = magnitude
        // Simulate touch being active
        prevJoystickMagnitude = magnitude
    }

    func _testStartLunge(direction: CGFloat) {
        startLunge(direction: direction)
    }
    #endif
}
