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

        let speedStat = CGFloat(npc.stats.stat(.speed))
        self.moveSpeed = P.baseMoveSpeed + (speedStat / 99.0) * P.maxMoveSpeedBonus
        self.sprintSpeed = moveSpeed * (1.0 + P.maxSprintSpeedBoost)

        let reflexesStat = CGFloat(npc.stats.stat(.reflexes))
        self.hitboxRadius = P.baseHitboxRadius + (reflexesStat / 99.0) * P.positioningHitboxBonus

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

        // Decide whether to sprint
        let staminaPct = stamina / P.maxStamina
        let shouldSprint = dist > 0.2 && staminaPct > 0.30
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
        let lookAhead: CGFloat = 0.5
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

        let dx = ball.courtX - currentNX
        let dy = ball.courtY - currentNY
        let dist = sqrt(dx * dx + dy * dy)
        return dist <= hitboxRadius
    }

    // MARK: - Shot Generation

    /// Generate a shot using the player shot calculator with stat-gated modes.
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
            stats: npcStats,
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
        let powerStat = CGFloat(npcStats.stat(.power))
        var modes: SM = []

        // High power NPCs use power serves
        if powerStat >= 60 && Bool.random() {
            modes.insert(.power)
            stamina = max(0, stamina - 5)
        }

        // Target: cross-court to receiver's side, near baseline
        // The calculatePlayerShot will target opponent's side automatically
        return DrillShotCalculator.calculatePlayerShot(
            stats: npcStats,
            ballApproachFromLeft: false,
            drillType: .baselineRally,
            ballHeight: 0.05,
            courtNY: currentNY,
            modes: modes,
            staminaFraction: stamina / P.maxStamina
        )
    }

    /// Select shot modes based on NPC stats and game state.
    private func selectShotModes(ball: DrillBallSimulation) -> SM {
        var modes: SM = []
        let staminaPct = stamina / P.maxStamina

        // Don't use stamina-draining modes when low
        guard staminaPct > 0.10 else { return modes }

        let powerStat = CGFloat(npcStats.stat(.power))
        let accuracyStat = CGFloat(npcStats.stat(.accuracy))
        let spinStat = CGFloat(npcStats.stat(.spin))
        let positioningStat = CGFloat(npcStats.stat(.positioning))
        let focusStat = CGFloat(npcStats.stat(.focus))

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
