import CoreGraphics

/// Strategic AI opponent for interactive matches.
/// Uses `DrillShotCalculator.calculatePlayerShot()` with stat-gated shot modes,
/// its own stamina system, and positioning logic based on NPC stats.
@MainActor
final class MatchAI {
    private typealias P = GameConstants.DrillPhysics
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

    // Serve tracking
    var isServing: Bool = false
    private let startNY: CGFloat = 0.92

    init(npc: NPC) {
        self.npcStats = npc.stats
        self.npcName = npc.name
        self.npcDUPR = npc.duprRating

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
    func positionForReceive(playerScore: Int) {
        let playerServingRight = playerScore % 2 == 0
        // Cross-court: if player serves from right (0.75), NPC goes left (0.25)
        currentNX = playerServingRight ? 0.25 : 0.75
        currentNY = startNY
        targetNX = currentNX
        targetNY = currentNY
    }

    /// Update AI position each frame.
    func update(dt: CGFloat, ball: DrillBallSimulation) {
        if ball.isActive && ball.lastHitByPlayer {
            // Ball heading toward AI — intercept
            predictLanding(ball: ball)
        } else if ball.isActive && !ball.lastHitByPlayer {
            // Ball heading toward player — recover toward center baseline
            targetNX = 0.5
            targetNY = startNY
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

    /// Select shot modes based on NPC stats (boosted) and game state.
    private func selectShotModes(ball: DrillBallSimulation) -> SM {
        var modes: SM = []
        let staminaPct = stamina / P.maxStamina

        // Don't use stamina-draining modes when low
        guard staminaPct > 0.10 else { return modes }

        let boost = P.npcStatBoost
        let powerStat = CGFloat(min(99, npcStats.stat(.power) + boost))
        let accuracyStat = CGFloat(min(99, npcStats.stat(.accuracy) + boost))
        let spinStat = CGFloat(min(99, npcStats.stat(.spin) + boost))
        let positioningStat = CGFloat(min(99, npcStats.stat(.positioning) + boost))
        let focusStat = CGFloat(min(99, npcStats.stat(.focus) + boost))

        // Power: stat-gated usage
        if powerStat >= 70 && ball.height > 0.08 && roll(0.50) {
            modes.insert(.power)
        } else if powerStat >= 50 && ball.courtY < 0.3 && roll(0.30) {
            // Opponent is deep — drive it
            modes.insert(.power)
        }

        // Reset/dink: positioning-gated
        if !modes.contains(.power) && positioningStat >= 50 && roll(0.25) {
            modes.insert(.reset)
        }

        // Spin: stat-gated
        if spinStat >= 70 && roll(0.50) {
            // Strategically choose: topspin for offense, slice for defense
            if ball.height > 0.05 {
                modes.insert(.topspin)
            } else {
                modes.insert(.slice)
            }
        } else if spinStat >= 40 && roll(0.25) {
            modes.insert(Bool.random() ? .slice : .topspin)
        }

        // Angled: accuracy-gated
        if accuracyStat >= 60 && roll(0.30) {
            modes.insert(.angled)
        }

        // Focus: high focus stat on important moments
        if focusStat >= 60 && staminaPct > 0.30 && roll(0.20) {
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
