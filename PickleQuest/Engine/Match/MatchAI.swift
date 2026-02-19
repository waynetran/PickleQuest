import CoreGraphics

// MARK: - NPC Strategy Profile

/// Represents how well an NPC knows/executes various strategies.
/// Each field is 0.0–1.0. Built from DUPR via smooth interpolation, then personality multipliers.
struct NPCStrategyProfile: Sendable {
    var serveReturnDepth: CGFloat    // Stand behind baseline for returns
    var kitchenApproach: CGFloat     // Move forward after soft return shots
    var dinkWhenAppropriate: CGFloat // Knows when to reset/dink
    var driveOnHighBall: CGFloat     // Attack high/sitter balls
    var resetWhenStretched: CGFloat  // Reset instead of going for winner when stretched
    var placementAwareness: CGFloat  // Target away from opponent
    var aggressionControl: CGFloat   // Don't overhit on hard balls

    /// Clamp all fields to 0–1.
    func clamped() -> NPCStrategyProfile {
        NPCStrategyProfile(
            serveReturnDepth: max(0, min(1, serveReturnDepth)),
            kitchenApproach: max(0, min(1, kitchenApproach)),
            dinkWhenAppropriate: max(0, min(1, dinkWhenAppropriate)),
            driveOnHighBall: max(0, min(1, driveOnHighBall)),
            resetWhenStretched: max(0, min(1, resetWhenStretched)),
            placementAwareness: max(0, min(1, placementAwareness)),
            aggressionControl: max(0, min(1, aggressionControl))
        )
    }

    /// Build a strategy profile from DUPR rating and personality.
    /// Uses piecewise linear interpolation across DUPR tiers, then applies personality multipliers.
    static func build(dupr: Double, personality: PlayerType) -> NPCStrategyProfile {
        // Piecewise linear interpolation helper: maps dupr to value across breakpoints
        func lerp(dupr: Double, breakpoints: [(dupr: Double, value: CGFloat)]) -> CGFloat {
            guard let first = breakpoints.first, let last = breakpoints.last else { return 0 }
            if dupr <= first.dupr { return first.value }
            if dupr >= last.dupr { return last.value }
            for i in 0..<(breakpoints.count - 1) {
                let lo = breakpoints[i]
                let hi = breakpoints[i + 1]
                if dupr >= lo.dupr && dupr <= hi.dupr {
                    let t = CGFloat((dupr - lo.dupr) / (hi.dupr - lo.dupr))
                    return lo.value + t * (hi.value - lo.value)
                }
            }
            return last.value
        }

        var profile = NPCStrategyProfile(
            serveReturnDepth: lerp(dupr: dupr, breakpoints: [
                (2.0, 0.0), (3.0, 0.4), (4.5, 0.9), (5.5, 1.0), (8.0, 1.0)
            ]),
            kitchenApproach: lerp(dupr: dupr, breakpoints: [
                (2.0, 0.0), (3.0, 0.1), (4.5, 0.5), (5.5, 0.8), (8.0, 1.0)
            ]),
            dinkWhenAppropriate: lerp(dupr: dupr, breakpoints: [
                (2.0, 0.0), (3.0, 0.2), (4.5, 0.6), (5.5, 0.9), (8.0, 0.95)
            ]),
            driveOnHighBall: lerp(dupr: dupr, breakpoints: [
                (2.0, 0.1), (3.0, 0.3), (4.5, 0.7), (5.5, 0.9), (8.0, 0.95)
            ]),
            resetWhenStretched: lerp(dupr: dupr, breakpoints: [
                (2.0, 0.0), (3.0, 0.1), (4.5, 0.5), (5.5, 0.8), (8.0, 0.9)
            ]),
            placementAwareness: lerp(dupr: dupr, breakpoints: [
                (2.0, 0.0), (3.0, 0.1), (4.5, 0.4), (5.5, 0.8), (8.0, 0.85)
            ]),
            aggressionControl: lerp(dupr: dupr, breakpoints: [
                (2.0, 0.1), (3.0, 0.3), (4.5, 0.6), (5.5, 0.8), (8.0, 0.9)
            ])
        )

        // Apply personality multipliers
        switch personality {
        case .aggressive:
            profile.driveOnHighBall *= 1.3
            profile.dinkWhenAppropriate *= 0.7
            profile.aggressionControl *= 0.8
        case .defensive:
            profile.resetWhenStretched *= 1.3
            profile.dinkWhenAppropriate *= 1.3
            profile.driveOnHighBall *= 0.7
        case .strategist:
            profile.placementAwareness *= 1.3
            profile.aggressionControl *= 1.2
        case .speedster:
            profile.kitchenApproach *= 1.2
        case .allRounder:
            break
        }

        return profile.clamped()
    }
}

// MARK: - NPC Error Type

/// Context-aware error types that correlate with the shot being attempted.
enum NPCErrorType {
    case net   // Dinks/resets clip the net
    case long  // Drives/power shots sail long
    case wide  // Angled shots miss wide
}

// MARK: - Jump Phase (shared by player and NPC)

enum JumpPhase {
    case grounded
    case rising
    case hanging
    case falling
}

// MARK: - Match AI

/// Strategic AI opponent for interactive matches.
/// Uses `DrillShotCalculator.calculatePlayerShot()` with stat-gated shot modes,
/// its own stamina system, and positioning logic based on NPC stats.
final class MatchAI {
    private typealias P = GameConstants.DrillPhysics
    private typealias S = GameConstants.NPCStrategy
    private typealias SM = DrillShotCalculator.ShotMode

    let npcStats: PlayerStats
    let npcName: String
    let npcDUPR: Double
    let playerDUPR: Double
    let isHeadless: Bool

    // Position in court space (NPC is on the far side: ny ~0.85–1.0)
    var currentNX: CGFloat
    var currentNY: CGFloat
    private var targetNX: CGFloat
    private var targetNY: CGFloat

    // Stamina
    var stamina: CGFloat = P.maxStamina
    private var timeSinceLastSprint: CGFloat = 10 // start recovered

    // Jump state
    private(set) var jumpPhase: JumpPhase = .grounded
    private var jumpTimer: CGFloat = 0
    private var jumpCooldownTimer: CGFloat = 0
    /// Current height reach bonus from jump (0 when grounded, up to jumpHeightReachBonus at peak)
    private(set) var jumpHeightBonus: CGFloat = 0

    // Derived movement speed
    private let moveSpeed: CGFloat
    private let sprintSpeed: CGFloat

    // Hitbox
    let baseHitboxRadius: CGFloat
    /// Number of consecutive kitchen shots the opponent has hit while this NPC is deep.
    /// Each shot shrinks the effective hitbox. Resets when NPC reaches the kitchen or between points.
    var pressureShotCount: Int = 0
    var hitboxRadius: CGFloat {
        guard pressureShotCount > 0 else { return baseHitboxRadius }
        // Each pressure shot shrinks hitbox; accuracy stat resists shrink
        let accuracyStat = CGFloat(npcStats.stat(.accuracy))
        let touchResist = accuracyStat / 99.0 * P.pressureTouchResistMax
        let shrinkPerShot = P.pressureShrinkPerShot * (1.0 - touchResist)
        let multiplier = max(P.pressureHitboxMinMultiplier, 1.0 - CGFloat(pressureShotCount) * shrinkPerShot)
        return baseHitboxRadius * multiplier
    }

    // Strategy profile (built from DUPR + personality)
    let strategy: NPCStrategyProfile

    // Shot quality context (set by InteractiveMatchScene before NPC hits)
    var lastPlayerShotModes: DrillShotCalculator.ShotMode = []
    var lastPlayerHitBallHeight: CGFloat = 0
    var lastPlayerHitDifficulty: CGFloat = 0

    // Serve tracking
    var isServing: Bool = false
    private(set) var lastServeModes: DrillShotCalculator.ShotMode = []
    private(set) var lastShotModes: DrillShotCalculator.ShotMode = []
    private var shotCountThisPoint: Int = 0
    private let startNY: CGFloat = 0.92

    // Kitchen approach tracking
    private var lastShotWasTouch: Bool = false
    private var shouldApproachKitchenAfterDrop: Bool = false

    // Player position for tactical placement (updated by scene each frame)
    var playerPositionNX: CGFloat = 0.5
    var playerPositionNY: CGFloat = 0.0

    // Rally pattern memory (tracks player's recent shot X positions)
    var playerShotHistory: [CGFloat] = []

    /// Serve target hint — receiver tracks the serve landing zone instead of predicting.
    /// Cleared after the ball bounces (receiver has locked onto landing zone).
    var serveTargetHint: CGPoint?

    /// Effective stat boost: DUPR-scaled for interactive, zero for headless.
    private let statBoost: Int

    // Headless mode: reaction delay + positioning noise (mirrors SimulatedPlayerAI)
    private let reactionDelay: CGFloat
    private let positioningNoise: CGFloat
    private var reactionTimer: CGFloat = 0
    private var hasReacted: Bool = false
    private var noiseOffsetX: CGFloat = 0
    private var noiseOffsetY: CGFloat = 0
    private var hasComputedNoise: Bool = false

    init(npc: NPC, playerDUPR: Double = 3.0, headless: Bool = false, moveSpeedScale: CGFloat? = nil) {
        self.npcStats = npc.stats
        self.npcName = npc.name
        self.npcDUPR = npc.duprRating
        self.playerDUPR = playerDUPR
        self.isHeadless = headless
        self.strategy = NPCStrategyProfile.build(dupr: npc.duprRating, personality: npc.playerType)

        // In headless mode, skip stat boost — SimulatedPlayerAI already models human imperfection
        // via reaction delay, positioning noise, and smaller hitbox.
        // In interactive mode, scale boost by NPC's base stat average (low DUPR = small boost).
        let boost: Int
        if headless {
            boost = 0
        } else {
            boost = P.npcStatBoost(forBaseStatAverage: CGFloat(npc.stats.average))
        }
        self.statBoost = boost
        let dupr = npc.duprRating
        let speedStat = CGFloat(P.npcScaledStat(.speed, base: npc.stats.stat(.speed), boost: boost, dupr: dupr))
        let scale = moveSpeedScale ?? P.npcMoveSpeedScale(dupr: dupr)
        self.moveSpeed = (P.baseMoveSpeed + (speedStat / 99.0) * P.maxMoveSpeedBonus) * scale
        self.sprintSpeed = moveSpeed * (1.0 + P.maxSprintSpeedBoost)

        if headless {
            // Use player-equivalent hitbox formula (no compensatory inflation)
            let positioningStat = CGFloat(npc.stats.stat(.positioning))
            self.baseHitboxRadius = P.baseHitboxRadius + (positioningStat / 99.0) * P.positioningHitboxBonus
        } else {
            // Interactive: larger hitbox compensates for human joystick advantage
            let reflexesStat = CGFloat(P.npcScaledStat(.reflexes, base: npc.stats.stat(.reflexes), boost: boost, dupr: dupr))
            let positioningStat = CGFloat(P.npcScaledStat(.positioning, base: npc.stats.stat(.positioning), boost: boost, dupr: dupr))
            let reachStat = max(reflexesStat, positioningStat)
            self.baseHitboxRadius = P.npcBaseHitboxRadius + (reachStat / 99.0) * P.npcHitboxBonus
        }

        // Headless mode: add reaction delay and positioning noise (mirrors SimulatedPlayerAI)
        if headless {
            let fraction = CGFloat(max(0, min(1, (npc.duprRating - 2.0) / 6.0)))
            self.reactionDelay = 0.10 - fraction * 0.08
            self.positioningNoise = 0.08 - fraction * 0.07
        } else {
            self.reactionDelay = 0
            self.positioningNoise = 0
        }

        // Start at center far baseline
        self.currentNX = 0.5
        self.currentNY = startNY
        self.targetNX = 0.5
        self.targetNY = startNY
    }

    // MARK: - Jump

    /// Attempt to jump. Returns true if jump started.
    @discardableResult
    func initiateJump() -> Bool {
        guard jumpPhase == .grounded else { return false }
        guard jumpCooldownTimer <= 0 else { return false }
        guard stamina >= P.jumpMinStamina else { return false }
        stamina -= P.jumpStaminaCost
        jumpPhase = .rising
        jumpTimer = 0
        return true
    }

    /// Update jump state machine. Call each frame.
    func updateJump(dt: CGFloat) {
        // Cooldown timer ticks even when grounded
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

    /// Fraction through the jump animation (0 = start, 1 = landing). Used for sprite Y-offset.
    var jumpAnimationFraction: CGFloat {
        guard jumpPhase != .grounded else { return 0 }
        return min(jumpTimer / P.jumpDuration, 1.0)
    }

    /// Sprite Y-offset for jump visual. Follows a sine arc: 0 → peak → 0.
    var jumpSpriteYOffset: CGFloat {
        guard jumpPhase != .grounded else { return 0 }
        let fraction = jumpAnimationFraction
        // Sine curve: smooth rise and fall
        return sin(fraction * .pi) * P.jumpSpriteYOffset
    }

    /// NPC jump decision: should the NPC jump to reach a high ball?
    /// Called in update() when ball is approaching and within decision range.
    private func shouldJump(ball: DrillBallSimulation) -> Bool {
        guard jumpPhase == .grounded && jumpCooldownTimer <= 0 else { return false }
        guard stamina >= P.jumpMinStamina else { return false }

        // Only interactive NPCs jump (headless AI doesn't need it)
        guard !isHeadless else { return false }

        // Athleticism gate
        let athleticism = (scaledStat(.speed) + scaledStat(.reflexes)) / 2.0 / 99.0
        guard athleticism >= P.npcJumpAthleticismThreshold else { return false }

        // Check if ball will be too high for standing reach
        let heightReach = P.baseHeightReach + athleticism * P.maxHeightReachBonus
        let predictedHeight = ball.height + ball.vz * P.npcJumpDecisionLeadTime
            - 0.5 * P.gravity * P.npcJumpDecisionLeadTime * P.npcJumpDecisionLeadTime
        let excessHeight = predictedHeight - heightReach
        guard excessHeight > 0 else { return false }

        // Check if jump would bring ball into range
        let jumpReach = heightReach + P.jumpHeightReachBonus
        guard predictedHeight <= jumpReach else { return false }

        // Roll against athleticism-scaled chance
        let jumpChance = athleticism * P.npcJumpChanceScale
        return CGFloat.random(in: 0...1) < jumpChance
    }

    // MARK: - Positioning

    /// Position for serving: right side when score is even, left when odd.
    func positionForServe(npcScore: Int) {
        let evenScore = npcScore % 2 == 0
        currentNX = evenScore ? 0.75 : 0.25
        currentNY = 1.0  // Behind baseline (NPC baseline = Y=1.0)
        targetNX = currentNX
        targetNY = currentNY
    }

    /// Position for receiving: cross-court from server.
    /// Smart NPCs stand deep behind baseline to handle fast serves (interactive only).
    func positionForReceive(playerScore: Int) {
        let playerServingRight = playerScore % 2 == 0
        // Cross-court: if player serves from right (0.75), NPC goes left (0.25)
        currentNX = playerServingRight ? 0.25 : 0.75

        if isHeadless {
            // Headless: symmetric with SimulatedPlayerAI — always stand at startNY
            currentNY = startNY
        } else {
            // Interactive: roll against serveReturnDepth — smart NPCs stand deep for returns
            if CGFloat.random(in: 0...1) < strategy.serveReturnDepth {
                currentNY = CGFloat.random(in: S.deepReturnNYMin...S.deepReturnNYMax)
            } else {
                currentNY = S.defaultReturnNY
            }
        }

        targetNX = currentNX
        targetNY = currentNY
    }

    /// Update AI position each frame.
    func update(dt: CGFloat, ball: DrillBallSimulation) {
        // Update jump state machine
        updateJump(dt: dt)

        // NPC jump decision: when ball is approaching and high
        if ball.isActive && ball.lastHitByPlayer && jumpPhase == .grounded {
            // Estimate time to contact
            let dy = currentNY - ball.courtY
            let ballSpeedY = abs(ball.vy)
            if ballSpeedY > 0.01 {
                let timeToContact = dy / ballSpeedY
                if timeToContact > 0 && timeToContact < P.npcJumpDecisionLeadTime * 2 {
                    if shouldJump(ball: ball) {
                        initiateJump()
                    }
                }
            }
        }

        if ball.isActive && ball.lastHitByPlayer {
            // Ball heading toward AI — intercept
            if isHeadless {
                if let hint = serveTargetHint {
                    // Serve tracking: skip reaction delay — receiver reads the slow
                    // underhand serve and moves directly to the landing zone.
                    targetNX = max(0.05, min(0.95, hint.x))
                    targetNY = max(0.72, min(1.0, hint.y))
                    hasReacted = true
                } else {
                    // Headless: apply reaction delay (mirrors SimulatedPlayerAI)
                    if !hasReacted {
                        reactionTimer += dt
                        if reactionTimer >= reactionDelay {
                            hasReacted = true
                            if !hasComputedNoise {
                                noiseOffsetX = CGFloat.random(in: -positioningNoise...positioningNoise)
                                noiseOffsetY = CGFloat.random(in: -positioningNoise...positioningNoise)
                                hasComputedNoise = true
                            }
                        }
                    }
                    if hasReacted {
                        predictLanding(ball: ball)
                    }
                }
            } else {
                predictLanding(ball: ball)
            }
        } else if ball.isActive && !ball.lastHitByPlayer {
            // Reset reaction state for next incoming ball
            if isHeadless {
                hasReacted = false
                reactionTimer = 0
                hasComputedNoise = false

                // Headless: symmetric recovery (mirrors SimulatedPlayerAI)
                let fraction = CGFloat(max(0, min(1, (npcDUPR - 2.0) / 6.0)))
                let recovery = 0.5 + fraction * 0.5
                targetNX = currentNX + (0.5 - currentNX) * recovery
                targetNY = currentNY + (startNY - currentNY) * recovery
            } else {
                // Interactive: strategy-based recovery with kitchen approach
                let recoveryStrength = strategy.aggressionControl

                // Use pre-computed kitchen approach decision (set once in generateShot)
                let recoveryNY: CGFloat = shouldApproachKitchenAfterDrop ? 0.69 : startNY

                targetNX = currentNX + (0.5 - currentNX) * recoveryStrength
                targetNY = currentNY + (recoveryNY - currentNY) * recoveryStrength

                // Backpedal if ball is high and behind NPC (lob defense)
                if ball.height > 0.20 && ball.courtY > currentNY + 0.05 {
                    targetNY = ball.courtY + 0.03
                }
            }
        } else {
            // Ball inactive — hold position
        }

        // Move toward target
        let dx = targetNX - currentNX
        let dy = targetNY - currentNY
        let dist = sqrt(dx * dx + dy * dy)

        guard dist > 0.01 else {
            // Standing still — recover stamina
            recoverStamina(dt: dt)
            return
        }

        // Decide whether to sprint — lower threshold so AI chases more aggressively
        let staminaPct = stamina / P.maxStamina
        let shouldSprint = dist > 0.10 && staminaPct > 0.20
        let effectiveSpeed: CGFloat

        if shouldSprint {
            // Sprint with stamina scaling
            let sprintFactor: CGFloat = staminaPct < 0.50 ? 0.5 : 1.0
            effectiveSpeed = moveSpeed + (sprintSpeed - moveSpeed) * sprintFactor
            stamina = max(0, stamina - P.sprintDrainRate * dt)
            timeSinceLastSprint = 0
        } else {
            effectiveSpeed = moveSpeed
            recoverStamina(dt: dt)
        }

        let step = effectiveSpeed * dt
        if step >= dist {
            currentNX = targetNX
            currentNY = targetNY
        } else {
            currentNX += (dx / dist) * step
            currentNY += (dy / dist) * step
        }

        currentNX = max(0.0, min(1.0, currentNX))
        if isHeadless {
            // Headless: symmetric Y range — mirrors player's max(0.0, min(0.30, ...))
            currentNY = max(0.70, min(1.0, currentNY))
        } else {
            // Interactive: skilled NPCs can approach kitchen line (0.69), others stay back (0.72)
            let minNY: CGFloat = strategy.kitchenApproach > 0.5 ? 0.69 : 0.72
            currentNY = max(minNY, min(1.0, currentNY))
        }
    }

    private func recoverStamina(dt: CGFloat) {
        timeSinceLastSprint += dt
        if timeSinceLastSprint >= P.staminaRecoveryDelay {
            stamina = min(P.maxStamina, stamina + P.staminaRecoveryRate * dt)
        }
    }

    /// Predict where the ball will land and set as movement target.
    private func predictLanding(ball: DrillBallSimulation) {
        // Scale lookahead with positioning stat — better players read the ball earlier
        let positioningStat = scaledStat(.positioning)
        let baseLookAhead: CGFloat = 0.6
        let statBonus: CGFloat = (positioningStat / 99.0) * 0.5
        let lookAhead = baseLookAhead + statBonus  // 0.6 to 1.1 seconds

        var predictedX = ball.courtX + ball.vx * lookAhead
        let predictedY = ball.courtY + ball.vy * lookAhead

        // Rally adaptation: interactive only (headless uses symmetric prediction)
        if !isHeadless, let anticipated = anticipatedPlayerSide(), roll(Double(strategy.placementAwareness)) {
            let bias: CGFloat = 0.15
            predictedX += (anticipated - predictedX) * bias
        }

        if isHeadless {
            // Headless: symmetric with SimulatedPlayerAI prediction range
            // Player uses max(0.0, min(0.28, ...)) → 0.20 forward from startNY=0.08
            // NPC mirror: max(0.72, min(1.0, ...)) → 0.20 forward from startNY=0.92
            targetNX = max(0.05, min(0.95, predictedX + noiseOffsetX))
            targetNY = max(0.72, min(1.0, predictedY + noiseOffsetY))
        } else {
            let minNY: CGFloat = strategy.kitchenApproach > 0.5 ? 0.69 : 0.72
            targetNX = max(0.05, min(0.95, predictedX))
            targetNY = max(minNY, min(0.98, predictedY))
        }
    }

    /// Detect if the player has been consistently hitting to one side.
    /// Returns the anticipated X position if last 3+ shots all went to the same half.
    private func anticipatedPlayerSide() -> CGFloat? {
        guard playerShotHistory.count >= 3 else { return nil }
        let recent = playerShotHistory.suffix(3)
        let allRight = recent.allSatisfy { $0 > 0.55 }
        let allLeft = recent.allSatisfy { $0 < 0.45 }
        guard allRight || allLeft else { return nil }
        return recent.reduce(0, +) / CGFloat(recent.count)
    }

    // MARK: - Hit Detection

    /// Check if ball is within AI's hitbox and hittable (3D distance with stat-gated height reach).
    func shouldSwing(ball: DrillBallSimulation) -> Bool {
        guard ball.isActive, ball.lastHitByPlayer else { return false }
        guard ball.bounceCount < 2 else { return false }

        // Pre-bounce: don't reach forward — wait for ball to arrive at NPC's Y
        if ball.bounceCount == 0 && ball.courtY < currentNY { return false }

        // 3D hitbox: height reach based on athleticism (speed + reflexes) + jump bonus
        let athleticism = (scaledStat(.speed) + scaledStat(.reflexes)) / 2.0 / 99.0
        let heightReach = P.baseHeightReach + athleticism * P.maxHeightReachBonus + jumpHeightBonus
        let excessHeight = max(0, ball.height - heightReach)

        let dx = ball.courtX - currentNX
        let dy = ball.courtY - currentNY
        let dist = sqrt(dx * dx + dy * dy + excessHeight * excessHeight)
        return dist <= hitboxRadius
    }

    // MARK: - Unforced Errors

    /// Whether the NPC makes an unforced error on this shot (whiff, frame, mis-hit).
    /// Error rate factors in incoming ball speed + spin (shot difficulty), NPC stats,
    /// player shot quality, and DUPR gap.
    func shouldMakeError(ball: DrillBallSimulation) -> Bool {
        let consistencyStat = scaledStat(.consistency)
        let focusStat = scaledStat(.focus)
        let reflexesStat = scaledStat(.reflexes)
        let avgStat = (consistencyStat + focusStat + reflexesStat) / 3.0
        let statFraction = avgStat / 99.0

        // Base error rate on neutral/easy shots
        let baseError: CGFloat = P.npcBaseErrorRate * (1.0 - statFraction)

        // Stretch: compute early so speed discount can use it
        let dx = ball.courtX - currentNX
        let dy = ball.courtY - currentNY
        let dist = sqrt(dx * dx + dy * dy)
        let stretchFraction = min(dist / hitboxRadius, 1.0)

        // Shot difficulty from incoming ball speed and spin
        let ballSpeed = sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
        let maxBallSpeed = P.baseShotSpeed + 2.0 * (P.maxShotSpeed - P.baseShotSpeed)
        let speedFraction = max(0, min(1, (ballSpeed - P.baseShotSpeed) / (maxBallSpeed - P.baseShotSpeed)))
        let spinPressure = min(abs(ball.spinCurve) + abs(ball.topspinFactor) * 0.5, 1.0)
        // Speed is only dangerous at reach — a fast ball straight at you is easy to return
        let stretchMultiplier = 0.2 + stretchFraction * 0.8
        let shotDifficulty = min(1.0, speedFraction * 0.8 * stretchMultiplier + spinPressure * 0.3)

        // Pressure error: harder shots cause more errors for lower-skilled NPCs
        let pressureError: CGFloat = shotDifficulty * P.npcPowerErrorScale * (1.0 - statFraction)

        // Floor: even top NPCs can miss truly powerful shots occasionally
        var errorRate = max(shotDifficulty * P.npcMinPowerErrorFloor, baseError + pressureError)

        // Fatigue increases errors: below 30% stamina, error rate doubles at 0%
        let staminaPct = stamina / P.maxStamina
        if staminaPct < 0.30 {
            let fatiguePenalty = 1.0 + (1.0 - staminaPct / 0.30)
            errorRate *= fatiguePenalty
        }

        // Stretch shots (ball far from NPC center) are harder to return cleanly
        if stretchFraction > 0.6 {
            errorRate *= 1.0 + (stretchFraction - 0.6) * 1.5 // up to 60% more errors at max reach
        }

        // Shot quality modifier: good player shots → more NPC errors, bad → fewer
        // Skip in headless mode — both sides are AI, no asymmetric quality assessment
        if !isHeadless {
            let shotQuality = assessPlayerShotQuality(ball: ball)
            errorRate *= (1.0 + shotQuality)
        }

        // DUPR gap scaling: exponential error adjustment
        let duprGap = npcDUPR - playerDUPR
        if duprGap > 0 {
            // NPC is stronger — exponential error reduction
            let multiplier = max(S.duprErrorFloor, CGFloat(exp(-Double(duprGap) * Double(S.duprErrorDecayRate))))
            errorRate *= multiplier
        } else if duprGap < 0 {
            // NPC is weaker — exponential error increase
            let multiplier = min(S.duprErrorCeiling, CGFloat(exp(Double(abs(duprGap)) * Double(S.duprErrorGrowthRate))))
            errorRate *= multiplier
        }

        // Smash: high ball from any position → reduced return rate (less punishing than put-away)
        if ball.smashFactor > 0 && !ball.isPutAway {
            let SM = GameConstants.Smash.self
            let rawReturn = SM.baseReturnRate + CGFloat(npcDUPR - 4.0) * SM.returnDUPRScale
            let clampedReturn = max(SM.returnFloor, min(SM.returnCeiling, rawReturn))
            let adjustedReturn = clampedReturn * (1.0 - stretchFraction * SM.stretchPenalty)
            let smashErrorFloor = 1.0 - adjustedReturn * ball.smashFactor
            errorRate = max(errorRate, smashErrorFloor)
        }

        // Put-away: continuous DUPR-scaled return rate (replaces old 2-tier system)
        if ball.isPutAway {
            let PA = GameConstants.PutAway.self
            let rawReturn = PA.baseReturnRate + CGFloat(npcDUPR - 4.0) * PA.returnDUPRScale
            let clampedReturn = max(PA.returnFloor, min(PA.returnCeiling, rawReturn))
            let adjustedReturn = clampedReturn * (1.0 - stretchFraction * PA.stretchPenalty)
            errorRate = max(errorRate, 1.0 - adjustedReturn)
        }

        // Pressure drop quality: when NPC is under pressure and chose touch/drop,
        // apply DUPR-scaled drop error rate (net/out whiff)
        if !isHeadless && lastShotModes.contains(.touch) {
            let PS = GameConstants.PressureShots.self
            let isUnderPressure = currentNY > PS.deepThresholdNY
                && playerPositionNY < PS.opponentAtNetThresholdNY
                && playerPositionNY > 0
            if isUnderPressure {
                let dropErrorRate = Self.pressureRate(
                    dupr: npcDUPR, base: PS.dropErrorBase, slope: PS.dropErrorSlope,
                    floor: PS.dropErrorFloor, ceiling: PS.dropErrorCeiling
                )
                // Stat modifier: higher touch stats reduce error
                let avgTouchStat = CGFloat(npcStats.stat(.accuracy) + npcStats.stat(.consistency)
                    + npcStats.stat(.focus) + npcStats.stat(.spin)) / 4.0
                let statMod = avgTouchStat / 99.0
                let adjustedDropError = dropErrorRate * (1.3 - 0.3 * statMod)
                errorRate = max(errorRate, adjustedDropError)
            }
        }

        return CGFloat.random(in: 0...1) < errorRate
    }

    /// Debug info from the last `shouldMakeError` call. Call `computeErrorDebugInfo` to populate.
    struct ErrorDebugInfo {
        let errorRate: CGFloat
        let baseError: CGFloat
        let pressureError: CGFloat
        let shotDifficulty: CGFloat
        let speedFrac: CGFloat
        let spinPressure: CGFloat
        let stretchFrac: CGFloat
        let stretchMultiplier: CGFloat
        let staminaPct: CGFloat
        let shotQuality: CGFloat
        let duprMultiplier: CGFloat
        let isPutAway: Bool
        let smashFactor: CGFloat
        let finalErrorRate: CGFloat
    }

    /// Compute error debug info without rolling the dice (non-mutating snapshot).
    func computeErrorDebugInfo(ball: DrillBallSimulation) -> ErrorDebugInfo {
        let consistencyDbg = scaledStat(.consistency)
        let focusDbg = scaledStat(.focus)
        let reflexesDbg = scaledStat(.reflexes)
        let avgStat = (consistencyDbg + focusDbg + reflexesDbg) / 3.0
        let statFraction = avgStat / 99.0
        let baseError: CGFloat = P.npcBaseErrorRate * (1.0 - statFraction)

        let dx = ball.courtX - currentNX
        let dy = ball.courtY - currentNY
        let dist = sqrt(dx * dx + dy * dy)
        let stretchFraction = min(dist / hitboxRadius, 1.0)

        let ballSpeed = sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
        let maxBallSpeed = P.baseShotSpeed + 2.0 * (P.maxShotSpeed - P.baseShotSpeed)
        let speedFraction = max(0, min(1, (ballSpeed - P.baseShotSpeed) / (maxBallSpeed - P.baseShotSpeed)))
        let spinPressure = min(abs(ball.spinCurve) + abs(ball.topspinFactor) * 0.5, 1.0)
        let stretchMultiplier = 0.2 + stretchFraction * 0.8
        let shotDifficulty = min(1.0, speedFraction * 0.8 * stretchMultiplier + spinPressure * 0.3)
        let pressureError: CGFloat = shotDifficulty * P.npcPowerErrorScale * (1.0 - statFraction)
        var errorRate = max(shotDifficulty * P.npcMinPowerErrorFloor, baseError + pressureError)

        let staminaPct = stamina / P.maxStamina
        if staminaPct < 0.30 {
            let fatiguePenalty = 1.0 + (1.0 - staminaPct / 0.30)
            errorRate *= fatiguePenalty
        }
        if stretchFraction > 0.6 {
            errorRate *= 1.0 + (stretchFraction - 0.6) * 1.5
        }
        var shotQuality: CGFloat = 0
        if !isHeadless {
            shotQuality = assessPlayerShotQuality(ball: ball)
            errorRate *= (1.0 + shotQuality)
        }
        var duprMultiplier: CGFloat = 1.0
        let duprGap = npcDUPR - playerDUPR
        if duprGap > 0 {
            duprMultiplier = max(S.duprErrorFloor, CGFloat(exp(-Double(duprGap) * Double(S.duprErrorDecayRate))))
            errorRate *= duprMultiplier
        } else if duprGap < 0 {
            duprMultiplier = min(S.duprErrorCeiling, CGFloat(exp(Double(abs(duprGap)) * Double(S.duprErrorGrowthRate))))
            errorRate *= duprMultiplier
        }
        // Smash override (mirrors shouldMakeError)
        if ball.smashFactor > 0 && !ball.isPutAway {
            let SM = GameConstants.Smash.self
            let rawReturn = SM.baseReturnRate + CGFloat(npcDUPR - 4.0) * SM.returnDUPRScale
            let clampedReturn = max(SM.returnFloor, min(SM.returnCeiling, rawReturn))
            let adjustedReturn = clampedReturn * (1.0 - stretchFraction * SM.stretchPenalty)
            let smashErrorFloor = 1.0 - adjustedReturn * ball.smashFactor
            errorRate = max(errorRate, smashErrorFloor)
        }

        // Put-away override (mirrors shouldMakeError)
        if ball.isPutAway {
            let PA = GameConstants.PutAway.self
            let rawReturn = PA.baseReturnRate + CGFloat(npcDUPR - 4.0) * PA.returnDUPRScale
            let clampedReturn = max(PA.returnFloor, min(PA.returnCeiling, rawReturn))
            let adjustedReturn = clampedReturn * (1.0 - stretchFraction * PA.stretchPenalty)
            errorRate = max(errorRate, 1.0 - adjustedReturn)
        }

        return ErrorDebugInfo(
            errorRate: errorRate, baseError: baseError, pressureError: pressureError,
            shotDifficulty: shotDifficulty, speedFrac: speedFraction, spinPressure: spinPressure,
            stretchFrac: stretchFraction, stretchMultiplier: stretchMultiplier,
            staminaPct: staminaPct, shotQuality: shotQuality, duprMultiplier: duprMultiplier,
            isPutAway: ball.isPutAway, smashFactor: ball.smashFactor, finalErrorRate: errorRate
        )
    }

    // MARK: - Shot Quality Assessment

    /// Assess how well the player chose their shot based on the ball situation.
    /// Returns -0.5 (bad shot) to +0.5 (great shot).
    private func assessPlayerShotQuality(ball: DrillBallSimulation) -> CGFloat {
        let modes = lastPlayerShotModes
        let ballHeight = lastPlayerHitBallHeight

        var quality: CGFloat = 0

        let isHighBall = ballHeight > S.highBallThreshold
        let isLowBall = ballHeight < S.lowBallThreshold
        let ballSpeed = sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
        let isFastIncoming = ballSpeed > (P.baseShotSpeed + P.maxShotSpeed) * 0.5

        // Good: Power on a high ball (overhead opportunity)
        if modes.contains(.power) && isHighBall {
            quality += S.goodShotErrorBonus
        }

        // Good: Topspin/angled cross-court pressure
        if (modes.contains(.topspin) || modes.contains(.angled)) && !isLowBall {
            quality += S.goodShotErrorBonus * 0.6
        }

        // Good: Touch/slice when under pressure (fast incoming or stretched)
        if modes.contains(.touch) && (isFastIncoming || lastPlayerHitDifficulty > 0.5) {
            quality += S.goodShotErrorBonus * 0.5
        }

        // Good: Focus on a manageable ball — tighter shot
        if modes.contains(.focus) && lastPlayerHitDifficulty < 0.4 {
            quality += S.goodShotErrorBonus * 0.4
        }

        // Bad: Power on a low, fast incoming ball — over-hitting
        if modes.contains(.power) && isLowBall && isFastIncoming {
            quality += S.badShotErrorPenalty
        }

        // Bad: Reset on a sitter — gives NPC free attack
        if modes.contains(.touch) && isHighBall && lastPlayerHitDifficulty < 0.3 {
            quality += S.badShotErrorPenalty * 0.8
        }

        // Bad: No modes at all on a high ball — missed opportunity
        if modes.isEmpty && isHighBall {
            quality += S.badShotErrorPenalty * 0.5
        }

        return max(-0.5, min(0.5, quality))
    }

    // MARK: - Shot Generation

    /// Pre-select shot modes for the current ball situation.
    /// Call this before `shouldMakeError` so `lastShotModes` is populated for error type.
    func preselectModes(ball: DrillBallSimulation) {
        var modes = selectShotModes(ball: ball)
        // Overhead smash: interactive only (headless uses competence-gated mode selection)
        if !isHeadless && ball.height > 0.20 {
            modes.insert(.power)
            modes.remove(.touch)
        }
        lastShotModes = modes
    }

    /// Generate a shot using the player shot calculator with stat-gated modes.
    /// The NPC gets boosted stats to compensate for perfect human joystick positioning.
    func generateShot(ball: DrillBallSimulation) -> DrillShotCalculator.ShotResult {
        serveTargetHint = nil  // Clear serve tracking after contact
        // Use pre-selected modes if available, otherwise select fresh
        var modes = lastShotModes.isEmpty ? selectShotModes(ball: ball) : lastShotModes
        shotCountThisPoint += 1
        let staminaFraction = stamina / P.maxStamina

        // Overhead smash: hitting a high ball always adds power (interactive only)
        // In headless mode, SimulatedPlayerAI handles this via selectShotModes competence gate
        if !isHeadless && ball.height > 0.20 {
            modes.insert(.power)
            modes.remove(.touch)
        }

        // Track whether this shot was a touch (for kitchen approach logic)
        lastShotWasTouch = modes.contains(.touch)
        lastShotModes = modes

        // Decide once whether to approach kitchen after a drop shot
        if lastShotWasTouch && !isHeadless {
            let PS = GameConstants.PressureShots.self
            let pressureApproachRate = Self.pressureRate(
                dupr: npcDUPR, base: PS.kitchenApproachAfterDropBase,
                slope: PS.kitchenApproachAfterDropSlope,
                floor: PS.kitchenApproachAfterDropFloor,
                ceiling: PS.kitchenApproachAfterDropCeiling
            )
            let approachChance = max(strategy.kitchenApproach, pressureApproachRate)
            shouldApproachKitchenAfterDrop = roll(Double(approachChance))
        } else {
            shouldApproachKitchenAfterDrop = false
        }

        // Drain stamina for power/focus shots
        if modes.contains(.power) {
            stamina = max(0, stamina - 5)
        }
        if modes.contains(.focus) {
            stamina = max(0, stamina - 3)
        }

        // In headless mode, skip tactical placement — SimulatedPlayerAI doesn't use it,
        // so both sides should generate random targets for symmetric balance.
        let oppNX: CGFloat? = isHeadless ? nil : playerPositionNX
        let placeFrac: CGFloat = isHeadless ? 0 : strategy.placementAwareness

        return DrillShotCalculator.calculatePlayerShot(
            stats: effectiveStats,
            ballApproachFromLeft: ball.courtX < currentNX,
            drillType: .baselineRally,
            ballHeight: ball.height,
            ballHeightAtNet: ball.heightAtNetCrossing,
            courtNX: currentNX,
            courtNY: currentNY,
            modes: modes,
            staminaFraction: staminaFraction,
            opponentNX: oppNX,
            placementFraction: placeFrac,
            shooterDUPR: npcDUPR
        )
    }

    /// Generate a serve shot.
    /// 4.5+ NPCs use power and spin on serves but with controlled power to reduce faults.
    /// Beginners serve flat with occasional wild power attempts.
    func generateServe(npcScore: Int) -> DrillShotCalculator.ShotResult {
        var modes: SM = []

        if isHeadless {
            // Headless: symmetric with SimulatedPlayerAI.generateServe()
            let fraction = CGFloat(max(0, min(1, (npcDUPR - 2.0) / 6.0)))
            let shotModeCompetence = fraction * fraction
            if CGFloat.random(in: 0...1) < shotModeCompetence * 0.5 {
                modes.insert(.power)
                stamina = max(0, stamina - 5)
            }
            if CGFloat.random(in: 0...1) < shotModeCompetence * 0.3 {
                modes.insert(Bool.random() ? .topspin : .slice)
            }
        } else {
            // Interactive: strategy-based serve mode selection
            if roll(Double(strategy.driveOnHighBall)) {
                modes.insert(.power)
                stamina = max(0, stamina - 5)
            }
            if roll(Double(strategy.placementAwareness * 0.8)) {
                modes.insert(Bool.random() ? .topspin : .slice)
            }
            if roll(Double(strategy.placementAwareness * 0.5)) {
                modes.insert(.angled)
            }
        }

        lastServeModes = modes
        lastShotModes = modes

        var result = DrillShotCalculator.calculatePlayerShot(
            stats: effectiveStats,
            ballApproachFromLeft: false,
            drillType: .baselineRally,
            ballHeight: 0.05,
            courtNX: currentNX,
            courtNY: currentNY,
            modes: modes,
            staminaFraction: stamina / P.maxStamina
        )

        // 4.5+ NPCs reduce serve power for control (interactive only)
        if !isHeadless {
            let powerReduction = 1.0 - strategy.aggressionControl * 0.45
            result.power *= powerReduction
        }

        return result
    }

    /// NPC stats boosted to compensate for human joystick advantage.
    /// A human with a joystick has "perfect positioning intelligence" — they always
    /// know exactly where to go. The NPC needs inflated stats to make its shots
    /// challenging enough that the human's low stats (small hitbox, slow speed,
    /// weak shots) actually matter.
    private var effectiveStats: PlayerStats {
        let boost = statBoost
        let dupr = npcDUPR
        func s(_ stat: StatType, _ base: Int) -> Int {
            P.npcScaledStat(stat, base: base, boost: boost, dupr: dupr)
        }
        return PlayerStats(
            power: s(.power, npcStats.power),
            accuracy: s(.accuracy, npcStats.accuracy),
            spin: s(.spin, npcStats.spin),
            speed: s(.speed, npcStats.speed),
            defense: s(.defense, npcStats.defense),
            reflexes: s(.reflexes, npcStats.reflexes),
            positioning: s(.positioning, npcStats.positioning),
            clutch: s(.clutch, npcStats.clutch),
            focus: s(.focus, npcStats.focus),
            stamina: s(.stamina, npcStats.stamina),
            consistency: s(.consistency, npcStats.consistency)
        )
    }

    /// Single scaled stat value (boosted + DUPR global multiplier).
    /// Use for one-off stat lookups outside effectiveStats.
    private func scaledStat(_ stat: StatType) -> CGFloat {
        CGFloat(P.npcScaledStat(stat, base: npcStats.stat(stat), boost: statBoost, dupr: npcDUPR))
    }

    // MARK: - Situational Shot Assessment

    /// Assess how difficult the incoming ball is to return.
    /// Returns 0.0 (easy sitter) to 1.0 (desperate stretch).
    private func assessShotDifficulty(ball: DrillBallSimulation) -> CGFloat {
        // Reach stretch: how far is the ball from NPC center relative to hitbox
        let dx = ball.courtX - currentNX
        let dy = ball.courtY - currentNY
        let dist = sqrt(dx * dx + dy * dy)
        let reachStretch = min(dist / hitboxRadius, 1.0)

        // Incoming speed as fraction of max shot speed
        let ballSpeed = sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
        let speedFraction = max(0, min(1, (ballSpeed - P.baseShotSpeed) / (P.maxShotSpeed - P.baseShotSpeed)))

        // Ball height (inverted): low balls are harder, high balls are easier sitters
        let heightDifficulty: CGFloat
        if ball.height < S.lowBallThreshold {
            heightDifficulty = 1.0
        } else if ball.height > S.highBallThreshold {
            heightDifficulty = 0.0
        } else {
            heightDifficulty = 1.0 - (ball.height - S.lowBallThreshold) / (S.highBallThreshold - S.lowBallThreshold)
        }

        // Spin pressure
        let spinPressure = min(abs(ball.spinCurve) + abs(ball.topspinFactor) * 0.5, 1.0)

        return reachStretch * S.reachStretchWeight
             + speedFraction * S.incomingSpeedWeight
             + heightDifficulty * S.ballHeightWeight
             + spinPressure * S.spinPressureWeight
    }

    /// Select shot modes based on situational difficulty and NPC strategy profile.
    private func selectShotModes(ball: DrillBallSimulation) -> SM {
        // Headless mode: use symmetric skill-gated selection (mirrors SimulatedPlayerAI)
        // This ensures both sides have the same scatter behavior at equal DUPR.
        if isHeadless {
            return selectShotModesHeadless(ball: ball)
        }

        // Positional pressure: NPC deep + opponent at net → use pressure shot selection
        let PS = GameConstants.PressureShots.self
        let isUnderPressure = currentNY > PS.deepThresholdNY
            && playerPositionNY < PS.opponentAtNetThresholdNY
            && playerPositionNY > 0  // 0 means not tracked
        if isUnderPressure {
            return selectPressureShotModes(ball: ball)
        }

        var modes: SM = []
        let staminaPct = stamina / P.maxStamina

        // Don't use stamina-draining modes when low
        guard staminaPct > 0.10 else { return modes }

        // Serve return: first shot when receiving — smart NPCs play a deep, controlled return
        // No power/spin scatter, just a clean medium shot deep to the baseline.
        // In real pickleball, the return is almost always controlled and deep at 4.0+.
        // Higher-level NPCs target the backhand (left side for right-handed opponents).
        let isServeReturn = shotCountThisPoint == 0 && !isServing
        if isServeReturn {
            // Smart NPCs play clean returns; dumb NPCs fall through to normal selection
            // and often overhit → errors via error model.
            // Scale by DUPR: 5.0+ NPCs almost always return cleanly.
            let returnChance = max(strategy.aggressionControl, strategy.serveReturnDepth)
            if roll(Double(returnChance)) {
                // Focus for tighter placement on manageable returns
                if roll(Double(strategy.aggressionControl * 0.6)) {
                    modes.insert(.focus)
                }
                // Higher-level NPCs angle the return to the backhand side
                if roll(Double(strategy.placementAwareness)) {
                    modes.insert(.angled)
                }
                // No power, no reset (dink), no spin — just a clean deep return
                return modes
            }
            // Failed the roll → beginner behavior, fall through to normal selection
        }

        let difficulty = assessShotDifficulty(ball: ball)

        // Aggression: easy balls + smart NPCs → high aggression; hard balls + smart NPCs → low
        // Dumb NPCs (low aggressionControl) stay aggressive even on hard balls → more errors via error model
        let aggression = (1.0 - difficulty) * (S.baseAggressionFloor + strategy.aggressionControl * S.baseAggressionFloor)

        let powerStat = scaledStat(.power) / 99.0
        let accuracyStat = scaledStat(.accuracy) / 99.0
        let spinStat = scaledStat(.spin) / 99.0
        let positioningStat = scaledStat(.positioning) / 99.0
        let focusStat = scaledStat(.focus) / 99.0

        // Power: drive high balls when aggression allows
        let powerChance = strategy.driveOnHighBall * powerStat * aggression
        if ball.height > 0.06 && roll(Double(powerChance)) {
            modes.insert(.power)
        }

        // Reset/dink (mutually exclusive with power)
        if !modes.contains(.power) {
            if difficulty > S.hardShotDifficultyThreshold {
                // Hard incoming shot — smart NPCs reset to protect themselves
                let resetChance = strategy.resetWhenStretched * positioningStat
                if roll(Double(resetChance)) {
                    modes.insert(.touch)
                }
            } else if aggression < 0.4 {
                // Low aggression situation (near kitchen, defensive play) — dink
                let dinkChance = strategy.dinkWhenAppropriate * 0.5
                if roll(Double(dinkChance)) {
                    modes.insert(.touch)
                }
            }
        }

        // Spin: topspin for offense (high ball + aggressive), slice for defense
        if aggression > 0.5 && ball.height > 0.05 {
            let topspinChance = strategy.driveOnHighBall * spinStat * aggression
            if roll(Double(topspinChance)) {
                modes.insert(.topspin)
            }
        } else {
            let sliceChance = strategy.aggressionControl * spinStat * (1.0 - aggression)
            if roll(Double(sliceChance * 0.5)) {
                modes.insert(.slice)
            }
        }

        // Angled: smart aggressive NPCs target sidelines
        let angledChance = strategy.placementAwareness * accuracyStat * aggression
        if roll(Double(angledChance)) {
            modes.insert(.angled)
        }

        // Focus: smart NPCs boost accuracy on easier balls
        let focusChance = strategy.aggressionControl * focusStat * (1.0 - difficulty)
        if staminaPct > 0.30 && roll(Double(focusChance * 0.3)) {
            modes.insert(.focus)
        }

        // Lob: low-level NPCs panic-lob often, high-level NPCs lob tactically
        // DUPR fraction: 0 = beginner (2.0), 1 = expert (8.0)
        if !modes.contains(.power) && !modes.contains(.touch) {
            let duprFrac = CGFloat(max(0, min(1, (npcDUPR - 2.0) / 6.0)))
            let isAtKitchen = abs(currentNY - 0.5) < 0.25

            // Beginners: panic lob when under any pressure (high chance, scales down with skill)
            // Experts: tactical lob only when stretched at kitchen (low chance, very deliberate)
            let beginnerLobChance = (1.0 - duprFrac) * 0.35 * difficulty  // up to 35% at DUPR 2.0
            let expertLobChance = duprFrac * strategy.resetWhenStretched * 0.15 * difficulty
            let lobChance = isAtKitchen ? (beginnerLobChance + expertLobChance) : beginnerLobChance * 0.3

            if roll(Double(lobChance)) {
                modes.insert(.lob)
            }
        }

        // Enforce mutual exclusivity
        if modes.contains(.power) && modes.contains(.touch) {
            modes.remove(.touch)
        }
        if modes.contains(.power) && modes.contains(.lob) {
            modes.remove(.lob)
        }
        if modes.contains(.touch) && modes.contains(.lob) {
            modes.remove(.lob)
        }
        if modes.contains(.topspin) && modes.contains(.slice) {
            modes.remove(.slice)
        }

        return modes
    }

    /// Pressure-aware shot selection when NPC is deep and opponent is at the net.
    /// Uses PressureShots constants for DUPR-scaled drop/drive/lob selection.
    private func selectPressureShotModes(ball: DrillBallSimulation) -> SM {
        var modes: SM = []
        let PS = GameConstants.PressureShots.self

        let dropRate = Self.pressureRate(
            dupr: npcDUPR, base: PS.dropSelectBase, slope: PS.dropSelectSlope,
            floor: PS.dropSelectFloor, ceiling: PS.dropSelectCeiling
        )
        let lobRate = Self.pressureRate(
            dupr: npcDUPR, base: PS.lobSelectBase, slope: PS.lobSelectSlope,
            floor: PS.lobSelectFloor, ceiling: PS.lobSelectCeiling
        )

        let roll = CGFloat.random(in: 0...1)
        if roll < dropRate {
            // Drop shot: touch mode
            modes.insert(.touch)
            // Smart NPCs add slice for more control on drops
            if self.roll(Double(strategy.aggressionControl * 0.5)) {
                modes.insert(.slice)
            }
        } else if roll < dropRate + lobRate {
            // Lob
            modes.insert(.lob)
        } else {
            // Drive: power + topspin for aggressive passing shot
            modes.insert(.power)
            let spinStat = scaledStat(.spin) / 99.0
            if self.roll(Double(spinStat * strategy.driveOnHighBall * 0.6)) {
                modes.insert(.topspin)
            }
            // Angled cross-court drives
            if self.roll(Double(strategy.placementAwareness * 0.5)) {
                modes.insert(.angled)
            }
        }

        return modes
    }

    /// Compute a DUPR-scaled rate: base + (dupr - 4.0) * slope, clamped.
    private static func pressureRate(
        dupr: Double, base: CGFloat, slope: CGFloat,
        floor: CGFloat, ceiling: CGFloat
    ) -> CGFloat {
        let raw = base + CGFloat(dupr - 4.0) * slope
        return max(floor, min(ceiling, raw))
    }

    /// Symmetric skill-gated mode selection for headless mode.
    /// Mirrors SimulatedPlayerAI.selectShotModes so both sides have identical scatter behavior.
    private func selectShotModesHeadless(ball: DrillBallSimulation) -> SM {
        var modes: SM = []
        let staminaPct = stamina / P.maxStamina
        guard staminaPct > 0.10 else { return modes }

        // Headless pressure detection: NPC deep + opponent at net
        let PS = GameConstants.PressureShots.self
        let isUnderPressure = currentNY > PS.deepThresholdNY
            && playerPositionNY < PS.opponentAtNetThresholdNY
            && playerPositionNY > 0
        if isUnderPressure {
            // Apply pressure shot selection with DUPR-scaled probabilities
            let dropRate = Self.pressureRate(
                dupr: npcDUPR, base: PS.dropSelectBase, slope: PS.dropSelectSlope,
                floor: PS.dropSelectFloor, ceiling: PS.dropSelectCeiling
            )
            let lobRate = Self.pressureRate(
                dupr: npcDUPR, base: PS.lobSelectBase, slope: PS.lobSelectSlope,
                floor: PS.lobSelectFloor, ceiling: PS.lobSelectCeiling
            )
            let roll = CGFloat.random(in: 0...1)
            if roll < dropRate {
                modes.insert(.touch)
            } else if roll < dropRate + lobRate {
                modes.insert(.lob)
            } else {
                modes.insert(.power)
            }
            return modes
        }

        // Skill competence: same formula as SimulatedPlayerAI (fraction²)
        let fraction = CGFloat(max(0, min(1, (npcDUPR - 2.0) / 6.0)))
        let shotModeCompetence = fraction * fraction
        guard CGFloat.random(in: 0...1) < shotModeCompetence else { return modes }

        let ballHeight = ball.height
        let isHighBall = ballHeight > 0.06

        // Power on high balls
        if isHighBall && CGFloat.random(in: 0...1) < fraction * 0.6 {
            modes.insert(.power)
        }

        // Topspin or slice
        if !modes.contains(.power) && CGFloat.random(in: 0...1) < fraction * 0.3 {
            modes.insert(Bool.random() ? .topspin : .slice)
        }

        // Angled shots
        if CGFloat.random(in: 0...1) < fraction * 0.3 {
            modes.insert(.angled)
        }

        // Focus
        if staminaPct > 0.30 && CGFloat.random(in: 0...1) < fraction * 0.2 {
            modes.insert(.focus)
        }

        return modes
    }

    private func roll(_ chance: Double) -> Bool {
        Double.random(in: 0...1) < chance
    }

    // MARK: - Reset

    /// Reset stamina between points (recovery scaled by stamina stat).
    func recoverBetweenPoints() {
        let staminaStat = scaledStat(.stamina)
        let baseRecovery: CGFloat = 8
        let staminaBonus = (staminaStat / 99.0) * 12  // stat 10 → +1.2, stat 85 → +10.3
        stamina = min(P.maxStamina, stamina + baseRecovery + staminaBonus)
    }

    func reset(npcScore: Int, isServing: Bool) {
        self.isServing = isServing
        self.pressureShotCount = 0
        self.shotCountThisPoint = 0
        self.lastShotWasTouch = false
        self.shouldApproachKitchenAfterDrop = false
        self.playerShotHistory = []
        self.lastShotModes = []
        self.hasReacted = false
        self.reactionTimer = 0
        self.hasComputedNoise = false
        self.serveTargetHint = nil
        self.jumpPhase = .grounded
        self.jumpTimer = 0
        self.jumpCooldownTimer = 0
        self.jumpHeightBonus = 0
        if isServing {
            positionForServe(npcScore: npcScore)
        }
    }

    // MARK: - Error Type

    /// Return a context-aware error type based on the last shot modes attempted.
    func errorType(for modes: DrillShotCalculator.ShotMode) -> NPCErrorType {
        // Headless: use symmetric distribution matching SimulatedPlayerAI.errorType
        if isHeadless {
            let roll = CGFloat.random(in: 0...1)
            if modes.contains(.power) {
                return roll < 0.6 ? .long : .wide
            }
            if modes.contains(.touch) || modes.contains(.slice) {
                return roll < 0.7 ? .net : .wide
            }
            if modes.contains(.angled) {
                return roll < 0.6 ? .wide : .net
            }
            if roll < 0.4 { return .net }
            if roll < 0.7 { return .long }
            return .wide
        }

        // Interactive: NPC-specific distributions
        let roll = CGFloat.random(in: 0...1)
        if modes.contains(.touch) {
            if roll < 0.70 { return .net }
            if roll < 0.90 { return .long }
            return .wide
        }
        if modes.contains(.power) {
            if roll < 0.20 { return .net }
            if roll < 0.70 { return .long }
            return .wide
        }
        if modes.contains(.angled) {
            if roll < 0.10 { return .net }
            if roll < 0.30 { return .long }
            return .wide
        }
        if roll < 0.40 { return .net }
        if roll < 0.80 { return .long }
        return .wide
    }
}
