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

// MARK: - Match AI

/// Strategic AI opponent for interactive matches.
/// Uses `DrillShotCalculator.calculatePlayerShot()` with stat-gated shot modes,
/// its own stamina system, and positioning logic based on NPC stats.
@MainActor
final class MatchAI {
    private typealias P = GameConstants.DrillPhysics
    private typealias S = GameConstants.NPCStrategy
    private typealias SM = DrillShotCalculator.ShotMode

    let npcStats: PlayerStats
    let npcName: String
    let npcDUPR: Double

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

    // Serve tracking
    var isServing: Bool = false
    private let startNY: CGFloat = 0.92

    init(npc: NPC) {
        self.npcStats = npc.stats
        self.npcName = npc.name
        self.npcDUPR = npc.duprRating
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
            targetNX = currentNX + (0.5 - currentNX) * recoveryStrength
            targetNY = currentNY + (startNY - currentNY) * recoveryStrength
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

        // Clamp to AI's side of court (behind kitchen line at 0.682)
        currentNX = max(0.0, min(1.0, currentNX))
        currentNY = max(0.72, min(1.0, currentNY))
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

        let predictedX = ball.courtX + ball.vx * lookAhead
        let predictedY = ball.courtY + ball.vy * lookAhead

        targetNX = max(0.05, min(0.95, predictedX))
        targetNY = max(0.72, min(0.98, predictedY))
    }

    // MARK: - Hit Detection

    /// Check if ball is within AI's hitbox and hittable.
    func shouldSwing(ball: DrillBallSimulation) -> Bool {
        guard ball.isActive, ball.lastHitByPlayer else { return false }
        guard ball.bounceCount < 2 else { return false }
        guard ball.height < 0.20 else { return false }

        // Pre-bounce: don't reach forward — wait for ball to arrive at NPC's Y
        if ball.bounceCount == 0 && ball.courtY < currentNY { return false }

        let dx = ball.courtX - currentNX
        let dy = ball.courtY - currentNY
        let dist = sqrt(dx * dx + dy * dy)
        return dist <= hitboxRadius
    }

    // MARK: - Unforced Errors

    /// Whether the NPC makes an unforced error on this shot (whiff, frame, mis-hit).
    /// Error rate factors in incoming ball speed + spin (shot difficulty) and NPC stats.
    /// Harder shots cause dramatically more errors for lower-skilled NPCs.
    ///
    /// Approximate error rates on full power shots:
    /// DUPR 2-3 (~boosted stat 40): ~48%
    /// DUPR 3-4 (~boosted stat 55): ~36%
    /// DUPR 4-5 (~boosted stat 75): ~19%
    /// DUPR 5-6 (~boosted stat 90): ~7%
    /// DUPR 7-8 (~boosted stat 99): ~2-5%
    ///
    /// Soft/neutral shots produce much lower error rates (~2-10%).
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

        return CGFloat.random(in: 0...1) < errorRate
    }

    // MARK: - Shot Generation

    /// Generate a shot using the player shot calculator with stat-gated modes.
    /// The NPC gets boosted stats to compensate for perfect human joystick positioning.
    func generateShot(ball: DrillBallSimulation) -> DrillShotCalculator.ShotResult {
        let modes = selectShotModes(ball: ball)
        let staminaFraction = stamina / P.maxStamina

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
            staminaFraction: staminaFraction
        )
    }

    /// Generate a serve shot.
    func generateServe(npcScore: Int) -> DrillShotCalculator.ShotResult {
        let powerStat = CGFloat(effectiveStats.stat(.power))
        var modes: SM = []

        // High power NPCs use power serves
        if powerStat >= 50 && Bool.random() {
            modes.insert(.power)
            stamina = max(0, stamina - 5)
        }

        return DrillShotCalculator.calculatePlayerShot(
            stats: effectiveStats,
            ballApproachFromLeft: false,
            drillType: .baselineRally,
            ballHeight: 0.05,
            courtNY: currentNY,
            modes: modes,
            staminaFraction: stamina / P.maxStamina
        )
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

    /// Reset stamina between points (partial recovery).
    func recoverBetweenPoints() {
        stamina = min(P.maxStamina, stamina + 15)
    }

    func reset(npcScore: Int, isServing: Bool) {
        self.isServing = isServing
        if isServing {
            positionForServe(npcScore: npcScore)
        }
    }
}
