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
    static func build(dupr: Double, personality: NPCPersonality) -> NPCStrategyProfile {
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

    // Position in court space (NPC is on the far side: ny ~0.85–1.0)
    var currentNX: CGFloat
    var currentNY: CGFloat
    private var targetNX: CGFloat
    private var targetNY: CGFloat

    // Stamina
    var stamina: CGFloat = P.maxStamina
    private var timeSinceLastSprint: CGFloat = 10 // start recovered

    // Derived movement speed
    private let moveSpeed: CGFloat
    private let sprintSpeed: CGFloat

    // Hitbox
    let hitboxRadius: CGFloat

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
    private var lastShotWasReset: Bool = false

    // Player position for tactical placement (updated by scene each frame)
    var playerPositionNX: CGFloat = 0.5

    // Rally pattern memory (tracks player's recent shot X positions)
    var playerShotHistory: [CGFloat] = []

    init(npc: NPC, playerDUPR: Double = 3.0) {
        self.npcStats = npc.stats
        self.npcName = npc.name
        self.npcDUPR = npc.duprRating
        self.playerDUPR = playerDUPR
        self.strategy = NPCStrategyProfile.build(dupr: npc.duprRating, personality: npc.personality)

        // Use boosted stats for movement and hitbox (compensate for human joystick advantage)
        let boost = P.npcStatBoost
        let speedStat = CGFloat(min(99, npc.stats.stat(.speed) + boost))
        self.moveSpeed = P.baseMoveSpeed + (speedStat / 99.0) * P.maxMoveSpeedBonus
        self.sprintSpeed = moveSpeed * (1.0 + P.maxSprintSpeedBoost)

        // Hitbox uses the better of reflexes and positioning (boosted)
        let reflexesStat = CGFloat(min(99, npc.stats.stat(.reflexes) + boost))
        let positioningStat = CGFloat(min(99, npc.stats.stat(.positioning) + boost))
        let reachStat = max(reflexesStat, positioningStat)
        self.hitboxRadius = P.npcBaseHitboxRadius + (reachStat / 99.0) * P.npcHitboxBonus

        // Start at center far baseline
        self.currentNX = 0.5
        self.currentNY = startNY
        self.targetNX = 0.5
        self.targetNY = startNY
    }

    // MARK: - Positioning

    /// Position for serving: right side when score is even, left when odd.
    func positionForServe(npcScore: Int) {
        let evenScore = npcScore % 2 == 0
        currentNX = evenScore ? 0.75 : 0.25
        currentNY = startNY
        targetNX = currentNX
        targetNY = currentNY
    }

    /// Position for receiving: cross-court from server.
    /// Smart NPCs stand deep behind baseline to handle fast serves.
    func positionForReceive(playerScore: Int) {
        let playerServingRight = playerScore % 2 == 0
        // Cross-court: if player serves from right (0.75), NPC goes left (0.25)
        currentNX = playerServingRight ? 0.25 : 0.75

        // Roll against serveReturnDepth — smart NPCs stand deep for returns
        if CGFloat.random(in: 0...1) < strategy.serveReturnDepth {
            currentNY = CGFloat.random(in: S.deepReturnNYMin...S.deepReturnNYMax)
        } else {
            currentNY = S.defaultReturnNY
        }

        targetNX = currentNX
        targetNY = currentNY
    }

    /// Update AI position each frame.
    func update(dt: CGFloat, ball: DrillBallSimulation) {
        if ball.isActive && ball.lastHitByPlayer {
            // Ball heading toward AI — intercept
            predictLanding(ball: ball)
        } else if ball.isActive && !ball.lastHitByPlayer {
            // Ball heading toward player — smart NPCs recover toward center, beginners stay put
            let recoveryStrength = strategy.aggressionControl

            // Kitchen approach: after a reset/dink, skilled NPCs advance to kitchen line
            let recoveryNY: CGFloat
            if lastShotWasReset && roll(Double(strategy.kitchenApproach)) {
                recoveryNY = 0.69 // kitchen line
            } else {
                recoveryNY = startNY
            }

            targetNX = currentNX + (0.5 - currentNX) * recoveryStrength
            targetNY = currentNY + (recoveryNY - currentNY) * recoveryStrength

            // Backpedal if ball is high and behind NPC (lob defense)
            if ball.height > 0.20 && ball.courtY > currentNY + 0.05 {
                targetNY = ball.courtY + 0.03
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

        // Dynamic NY clamp: skilled NPCs can approach kitchen line (0.69), others stay back (0.72)
        let minNY: CGFloat = strategy.kitchenApproach > 0.5 ? 0.69 : 0.72
        currentNX = max(0.0, min(1.0, currentNX))
        currentNY = max(minNY, min(1.0, currentNY))
    }

    private func recoverStamina(dt: CGFloat) {
        timeSinceLastSprint += dt
        if timeSinceLastSprint >= P.staminaRecoveryDelay {
            stamina = min(P.maxStamina, stamina + P.staminaRecoveryRate * dt)
        }
    }

    /// Predict where the ball will land and set as movement target.
    private func predictLanding(ball: DrillBallSimulation) {
        // Scale lookahead with positioning stat (boosted) — better players read the ball earlier
        let positioningStat = CGFloat(min(99, npcStats.stat(.positioning) + P.npcStatBoost))
        let baseLookAhead: CGFloat = 0.6
        let statBonus: CGFloat = (positioningStat / 99.0) * 0.5
        let lookAhead = baseLookAhead + statBonus  // 0.6 to 1.1 seconds

        var predictedX = ball.courtX + ball.vx * lookAhead
        let predictedY = ball.courtY + ball.vy * lookAhead

        // Rally adaptation: if player tends to hit to one side, shade toward it
        if let anticipated = anticipatedPlayerSide(), roll(Double(strategy.placementAwareness)) {
            let bias: CGFloat = 0.15
            predictedX += (anticipated - predictedX) * bias
        }

        let minNY: CGFloat = strategy.kitchenApproach > 0.5 ? 0.69 : 0.72
        targetNX = max(0.05, min(0.95, predictedX))
        targetNY = max(minNY, min(0.98, predictedY))
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

    /// Check if ball is within AI's hitbox and hittable.
    func shouldSwing(ball: DrillBallSimulation) -> Bool {
        guard ball.isActive, ball.lastHitByPlayer else { return false }
        guard ball.bounceCount < 2 else { return false }

        // Stat-gated overhead reach: skilled NPCs can hit high balls (lob defense)
        let maxSwingHeight: CGFloat = 0.20 + strategy.driveOnHighBall * 0.15
        guard ball.height < maxSwingHeight else { return false }

        // Pre-bounce: don't reach forward — wait for ball to arrive at NPC's Y
        if ball.bounceCount == 0 && ball.courtY < currentNY { return false }

        let dx = ball.courtX - currentNX
        let dy = ball.courtY - currentNY
        let dist = sqrt(dx * dx + dy * dy)
        return dist <= hitboxRadius
    }

    // MARK: - Unforced Errors

    /// Whether the NPC makes an unforced error on this shot (whiff, frame, mis-hit).
    /// Error rate factors in incoming ball speed + spin (shot difficulty), NPC stats,
    /// player shot quality, and DUPR gap.
    func shouldMakeError(ball: DrillBallSimulation) -> Bool {
        let boost = P.npcStatBoost
        let consistencyStat = CGFloat(min(99, npcStats.stat(.consistency) + boost))
        let focusStat = CGFloat(min(99, npcStats.stat(.focus) + boost))
        let reflexesStat = CGFloat(min(99, npcStats.stat(.reflexes) + boost))
        let avgStat = (consistencyStat + focusStat + reflexesStat) / 3.0
        let statFraction = avgStat / 99.0

        // Base error rate on neutral/easy shots
        let baseError: CGFloat = P.npcBaseErrorRate * (1.0 - statFraction)

        // Shot difficulty from incoming ball speed and spin
        let ballSpeed = sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
        let maxBallSpeed = P.baseShotSpeed + 2.0 * (P.maxShotSpeed - P.baseShotSpeed)
        let speedFraction = max(0, min(1, (ballSpeed - P.baseShotSpeed) / (maxBallSpeed - P.baseShotSpeed)))
        let spinPressure = min(abs(ball.spinCurve) + abs(ball.topspinFactor) * 0.5, 1.0)
        let shotDifficulty = min(1.0, speedFraction * 0.8 + spinPressure * 0.3)

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
        let dx = ball.courtX - currentNX
        let dy = ball.courtY - currentNY
        let dist = sqrt(dx * dx + dy * dy)
        let stretchFraction = min(dist / hitboxRadius, 1.0)
        if stretchFraction > 0.6 {
            errorRate *= 1.0 + (stretchFraction - 0.6) * 1.5 // up to 60% more errors at max reach
        }

        // Shot quality modifier: good player shots → more NPC errors, bad → fewer
        let shotQuality = assessPlayerShotQuality(ball: ball)
        errorRate *= (1.0 + shotQuality)

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

        return CGFloat.random(in: 0...1) < errorRate
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

        // Good: Reset/slice when under pressure (fast incoming or stretched)
        if modes.contains(.reset) && (isFastIncoming || lastPlayerHitDifficulty > 0.5) {
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
        if modes.contains(.reset) && isHighBall && lastPlayerHitDifficulty < 0.3 {
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
        if ball.height > 0.20 {
            modes.insert(.power)
            modes.remove(.reset)
        }
        lastShotModes = modes
    }

    /// Generate a shot using the player shot calculator with stat-gated modes.
    /// The NPC gets boosted stats to compensate for perfect human joystick positioning.
    func generateShot(ball: DrillBallSimulation) -> DrillShotCalculator.ShotResult {
        // Use pre-selected modes if available, otherwise select fresh
        var modes = lastShotModes.isEmpty ? selectShotModes(ball: ball) : lastShotModes
        shotCountThisPoint += 1
        let staminaFraction = stamina / P.maxStamina

        // Overhead smash: hitting a high ball always adds power
        if ball.height > 0.20 {
            modes.insert(.power)
            modes.remove(.reset)
        }

        // Track whether this shot was a reset (for kitchen approach logic)
        lastShotWasReset = modes.contains(.reset)
        lastShotModes = modes

        // Drain stamina for power/focus shots
        if modes.contains(.power) {
            stamina = max(0, stamina - 5)
        }
        if modes.contains(.focus) {
            stamina = max(0, stamina - 3)
        }

        return DrillShotCalculator.calculatePlayerShot(
            stats: effectiveStats,
            ballApproachFromLeft: ball.courtX < currentNX,
            drillType: .baselineRally,
            ballHeight: ball.height,
            courtNY: currentNY,
            modes: modes,
            staminaFraction: staminaFraction,
            opponentNX: playerPositionNX,
            placementFraction: strategy.placementAwareness
        )
    }

    /// Generate a serve shot.
    /// 4.5+ NPCs use power and spin on serves but with controlled power to reduce faults.
    /// Beginners serve flat with occasional wild power attempts.
    func generateServe(npcScore: Int) -> DrillShotCalculator.ShotResult {
        var modes: SM = []

        // Strategy-based serve mode selection:
        // driveOnHighBall gates willingness to add power to serves
        // aggressionControl gates whether they use controlled vs wild power
        if roll(Double(strategy.driveOnHighBall)) {
            modes.insert(.power)
            stamina = max(0, stamina - 5)
        }

        // Spin on serves: smart NPCs add spin for movement
        if roll(Double(strategy.placementAwareness * 0.8)) {
            modes.insert(Bool.random() ? .topspin : .slice)
        }

        // Smart NPCs add placement to target corners
        if roll(Double(strategy.placementAwareness * 0.5)) {
            modes.insert(.angled)
        }

        lastServeModes = modes
        lastShotModes = modes

        var result = DrillShotCalculator.calculatePlayerShot(
            stats: effectiveStats,
            ballApproachFromLeft: false,
            drillType: .baselineRally,
            ballHeight: 0.05,
            courtNY: currentNY,
            modes: modes,
            staminaFraction: stamina / P.maxStamina,
            opponentNX: playerPositionNX,
            placementFraction: strategy.placementAwareness
        )

        // 4.5+ NPCs reduce serve power for control — they place serves, not blast them.
        // aggressionControl scales how much power is dialed back.
        // High aggressionControl (0.6-0.9) → multiply power by 0.55-0.7 (controlled)
        // Low aggressionControl (0.1-0.3) → multiply power by 0.85-0.95 (still wild)
        let powerReduction = 1.0 - strategy.aggressionControl * 0.45
        result.power *= powerReduction

        return result
    }

    /// NPC stats boosted to compensate for human joystick advantage.
    /// A human with a joystick has "perfect positioning intelligence" — they always
    /// know exactly where to go. The NPC needs inflated stats to make its shots
    /// challenging enough that the human's low stats (small hitbox, slow speed,
    /// weak shots) actually matter.
    private var effectiveStats: PlayerStats {
        let boost = P.npcStatBoost
        return PlayerStats(
            power: min(99, npcStats.power + boost),
            accuracy: min(99, npcStats.accuracy + boost),
            spin: min(99, npcStats.spin + boost),
            speed: min(99, npcStats.speed + boost),
            defense: min(99, npcStats.defense + boost),
            reflexes: min(99, npcStats.reflexes + boost),
            positioning: min(99, npcStats.positioning + boost),
            clutch: min(99, npcStats.clutch + boost),
            focus: min(99, npcStats.focus + boost),
            stamina: min(99, npcStats.stamina + boost),
            consistency: min(99, npcStats.consistency + boost)
        )
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

        let boost = P.npcStatBoost
        let powerStat = CGFloat(min(99, npcStats.stat(.power) + boost)) / 99.0
        let accuracyStat = CGFloat(min(99, npcStats.stat(.accuracy) + boost)) / 99.0
        let spinStat = CGFloat(min(99, npcStats.stat(.spin) + boost)) / 99.0
        let positioningStat = CGFloat(min(99, npcStats.stat(.positioning) + boost)) / 99.0
        let focusStat = CGFloat(min(99, npcStats.stat(.focus) + boost)) / 99.0

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
                    modes.insert(.reset)
                }
            } else if aggression < 0.4 {
                // Low aggression situation (near kitchen, defensive play) — dink
                let dinkChance = strategy.dinkWhenAppropriate * 0.5
                if roll(Double(dinkChance)) {
                    modes.insert(.reset)
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

        // Enforce mutual exclusivity
        if modes.contains(.power) && modes.contains(.reset) {
            modes.remove(.reset)
        }
        if modes.contains(.topspin) && modes.contains(.slice) {
            modes.remove(.slice)
        }

        return modes
    }

    private func roll(_ chance: Double) -> Bool {
        Double.random(in: 0...1) < chance
    }

    // MARK: - Reset

    /// Reset stamina between points (recovery scaled by stamina stat).
    func recoverBetweenPoints() {
        let staminaStat = CGFloat(npcStats.stat(.stamina))
        let baseRecovery: CGFloat = 8
        let staminaBonus = (staminaStat / 99.0) * 12  // stat 10 → +1.2, stat 85 → +10.3
        stamina = min(P.maxStamina, stamina + baseRecovery + staminaBonus)
    }

    func reset(npcScore: Int, isServing: Bool) {
        self.isServing = isServing
        self.shotCountThisPoint = 0
        self.lastShotWasReset = false
        self.playerShotHistory = []
        self.lastShotModes = []
        if isServing {
            positionForServe(npcScore: npcScore)
        }
    }

    // MARK: - Error Type

    /// Return a context-aware error type based on the last shot modes attempted.
    func errorType(for modes: DrillShotCalculator.ShotMode) -> NPCErrorType {
        let roll = CGFloat.random(in: 0...1)
        if modes.contains(.reset) {
            // Dinks/resets → mostly net errors
            if roll < 0.70 { return .net }
            if roll < 0.90 { return .long }
            return .wide
        }
        if modes.contains(.power) {
            // Power shots → mostly long errors
            if roll < 0.20 { return .net }
            if roll < 0.70 { return .long }
            return .wide
        }
        if modes.contains(.angled) {
            // Angled shots → mostly wide errors
            if roll < 0.10 { return .net }
            if roll < 0.30 { return .long }
            return .wide
        }
        // Default
        if roll < 0.40 { return .net }
        if roll < 0.80 { return .long }
        return .wide
    }
}
