import CoreGraphics

/// Simulates a human player for headless match testing.
/// Unlike `MatchAI` (which compensates for human joystick advantage with stat boosts
/// and larger hitbox), `SimulatedPlayerAI` models a human at a given DUPR skill level
/// with reaction delay, positioning noise, and skill-gated shot mode selection.
final class SimulatedPlayerAI {
    private typealias P = GameConstants.DrillPhysics
    private typealias PB = GameConstants.PlayerBalance
    typealias SM = DrillShotCalculator.ShotMode

    let stats: PlayerStats
    let dupr: Double

    // Position in court space (player is on the near side: ny ~0.0–0.318)
    var currentNX: CGFloat
    var currentNY: CGFloat
    private var targetNX: CGFloat
    private var targetNY: CGFloat

    // Stamina
    var stamina: CGFloat = P.maxStamina
    private var timeSinceLastSprint: CGFloat = 10

    // Derived movement speed (no stat boost — raw stats)
    private let moveSpeed: CGFloat
    private let sprintSpeed: CGFloat

    // Hitbox (player-side constants — smaller than NPC)
    let hitboxRadius: CGFloat

    // Skill parameters derived from DUPR
    private let skillFraction: CGFloat     // 0.0 at DUPR 2.0, 1.0 at DUPR 8.0
    private let reactionDelay: CGFloat     // time before starting to move toward ball
    private let positioningNoise: CGFloat  // noise in landing prediction
    private let shotModeCompetence: CGFloat // probability of using advanced shot modes

    // Rally tracking
    private var shotCountThisPoint: Int = 0
    var isServing: Bool = false
    private let startNY: CGFloat = 0.08

    /// Serve target hint — receiver tracks the serve landing zone instead of predicting.
    /// Cleared after the ball bounces (receiver has locked onto landing zone).
    var serveTargetHint: CGPoint?

    // Reaction delay tracking
    private var reactionTimer: CGFloat = 0
    private var hasReacted: Bool = false

    // Positioning noise: computed once per ball approach, not every frame
    private var noiseOffsetX: CGFloat = 0
    private var noiseOffsetY: CGFloat = 0
    private var hasComputedNoise: Bool = false

    // Rally pressure (mirrors InteractiveMatchScene)
    var rallyPressure: CGFloat = 0

    init(stats: PlayerStats, dupr: Double, moveSpeedScale: CGFloat? = nil) {
        self.stats = stats
        self.dupr = dupr

        // Skill parameters
        let fraction = CGFloat(max(0, min(1, (dupr - 2.0) / 6.0)))
        self.skillFraction = fraction
        self.reactionDelay = 0.10 - fraction * 0.08   // 0.10s beginner → 0.02s expert
        self.positioningNoise = 0.08 - fraction * 0.07 // 0.08 beginner → 0.01 expert
        self.shotModeCompetence = fraction * fraction   // 0.0 beginner → 1.0 expert

        // Movement speed from raw stats, scaled by DUPR
        let speedStat = CGFloat(stats.stat(.speed))
        let scale = moveSpeedScale ?? StatProfileLoader.shared.moveSpeedScale(dupr: dupr)
        self.moveSpeed = (P.baseMoveSpeed + (speedStat / 99.0) * P.maxMoveSpeedBonus) * scale
        self.sprintSpeed = moveSpeed * (1.0 + P.maxSprintSpeedBoost)

        // Hitbox from raw positioning stat (player-side constants)
        let positioningStat = CGFloat(stats.stat(.positioning))
        self.hitboxRadius = P.baseHitboxRadius + (positioningStat / 99.0) * P.positioningHitboxBonus

        // Start at center near baseline
        self.currentNX = 0.5
        self.currentNY = startNY
        self.targetNX = 0.5
        self.targetNY = startNY
    }

    // MARK: - Positioning

    func positionForServe(playerScore: Int) {
        let evenScore = playerScore % 2 == 0
        currentNX = evenScore ? 0.75 : 0.25
        currentNY = 0.0  // Behind baseline (player baseline = Y=0)
        targetNX = currentNX
        targetNY = currentNY
    }

    func positionForReceive(npcScore: Int) {
        let npcServingRight = npcScore % 2 == 0
        // Cross-court from NPC server
        currentNX = npcServingRight ? 0.25 : 0.75
        currentNY = startNY
        targetNX = currentNX
        targetNY = currentNY
    }

    // MARK: - Update

    func update(dt: CGFloat, ball: DrillBallSimulation) {
        if ball.isActive && !ball.lastHitByPlayer {
            // Ball heading toward player — intercept
            if let hint = serveTargetHint {
                // Serve tracking: skip reaction delay — receiver reads the slow
                // underhand serve and moves directly to the landing zone.
                targetNX = max(0.05, min(0.95, hint.x))
                targetNY = max(0.0, min(0.28, hint.y))
                hasReacted = true
            } else {
                // Normal rally: apply reaction delay
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
        } else if ball.isActive && ball.lastHitByPlayer {
            // Ball heading toward NPC — recover toward center and reset reaction for next approach
            hasReacted = false
            reactionTimer = 0
            hasComputedNoise = false
            // In real pickleball, players immediately move to ready position after hitting.
            // Beginners recover 50% toward center, experts go all the way.
            let recovery = 0.5 + skillFraction * 0.5
            targetNX = currentNX + (0.5 - currentNX) * recovery
            targetNY = currentNY + (startNY - currentNY) * recovery
        }

        // Move toward target
        let dx = targetNX - currentNX
        let dy = targetNY - currentNY
        let dist = sqrt(dx * dx + dy * dy)

        guard dist > 0.01 else {
            recoverStamina(dt: dt)
            return
        }

        let staminaPct = stamina / P.maxStamina
        let shouldSprint = dist > 0.10 && staminaPct > 0.20
        let effectiveSpeed: CGFloat

        if shouldSprint {
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

        // Clamp to player's side of court (in front of kitchen line at 0.318)
        currentNX = max(0.0, min(1.0, currentNX))
        currentNY = max(0.0, min(0.30, currentNY))
    }

    private func recoverStamina(dt: CGFloat) {
        timeSinceLastSprint += dt
        if timeSinceLastSprint >= P.staminaRecoveryDelay {
            stamina = min(P.maxStamina, stamina + P.staminaRecoveryRate * dt)
        }
    }

    private func predictLanding(ball: DrillBallSimulation) {
        let positioningStat = CGFloat(stats.stat(.positioning))
        let baseLookAhead: CGFloat = 0.6
        let statBonus: CGFloat = (positioningStat / 99.0) * 0.5
        let lookAhead = baseLookAhead + statBonus

        let predictedX = ball.courtX + ball.vx * lookAhead
        let predictedY = ball.courtY + ball.vy * lookAhead

        // Use pre-computed noise offset (stable per ball approach)
        targetNX = max(0.05, min(0.95, predictedX + noiseOffsetX))
        targetNY = max(0.0, min(0.28, predictedY + noiseOffsetY))
    }

    // MARK: - Hit Detection

    /// Check if ball is within player's hitbox and hittable (3D distance with stat-gated height reach).
    func canHit(ball: DrillBallSimulation) -> Bool {
        guard ball.isActive, !ball.lastHitByPlayer else { return false }
        guard ball.bounceCount < 2 else { return false }

        // Pre-bounce: don't reach forward
        if ball.bounceCount == 0 && ball.courtY > currentNY { return false }

        // 3D hitbox: height reach based on athleticism (speed + reflexes)
        let speedStat = CGFloat(stats.stat(.speed))
        let reflexesStat = CGFloat(stats.stat(.reflexes))
        let athleticism = (speedStat + reflexesStat) / 2.0 / 99.0
        let heightReach = P.baseHeightReach + athleticism * P.maxHeightReachBonus
        let excessHeight = max(0, ball.height - heightReach)

        let dx = ball.courtX - currentNX
        let dy = ball.courtY - currentNY
        let dist = sqrt(dx * dx + dy * dy + excessHeight * excessHeight)
        return dist <= hitboxRadius
    }

    // MARK: - Symmetric Error (headless mode — mirrors MatchAI.shouldMakeError exactly)

    /// Symmetric error check for headless mode. Uses the same formula as NPC's `shouldMakeError`
    /// so both sides have identical error resolution mechanics.
    func shouldMakeError(ball: DrillBallSimulation, npcDUPR: Double) -> Bool {
        let P = GameConstants.DrillPhysics.self
        let S = GameConstants.NPCStrategy.self

        let consistencyStat = CGFloat(stats.stat(.consistency))
        let focusStat = CGFloat(stats.stat(.focus))
        let reflexesStat = CGFloat(stats.stat(.reflexes))
        let avgStat = (consistencyStat + focusStat + reflexesStat) / 3.0
        let statFraction = avgStat / 99.0

        let baseError: CGFloat = P.npcBaseErrorRate * (1.0 - statFraction)

        // Stretch: compute early so speed discount can use it
        let dx = ball.courtX - currentNX
        let dy = ball.courtY - currentNY
        let dist = sqrt(dx * dx + dy * dy)
        let stretchFraction = min(dist / hitboxRadius, 1.0)

        let ballSpeed = sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
        let maxBallSpeed = P.baseShotSpeed + 2.0 * (P.maxShotSpeed - P.baseShotSpeed)
        let speedFraction = max(0, min(1, (ballSpeed - P.baseShotSpeed) / (maxBallSpeed - P.baseShotSpeed)))
        let spinPressure = min(abs(ball.spinCurve) + abs(ball.topspinFactor) * 0.5, 1.0)
        // Speed is only dangerous at reach — a fast ball straight at you is easy to return
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

        // DUPR gap scaling (symmetric with NPC)
        let duprGap = dupr - npcDUPR
        if duprGap > 0 {
            // Player is stronger — error reduction
            let multiplier = max(S.duprErrorFloor, CGFloat(exp(-Double(duprGap) * Double(S.duprErrorDecayRate))))
            errorRate *= multiplier
        } else if duprGap < 0 {
            // Player is weaker — error increase
            let multiplier = min(S.duprErrorCeiling, CGFloat(exp(Double(abs(duprGap)) * Double(S.duprErrorGrowthRate))))
            errorRate *= multiplier
        }

        // Put-away: kitchen slam — error rate scales with receiver's DUPR.
        // Below 4.5: can't handle full power put-aways, ~90% error floor.
        // 4.5+: need placement away from receiver to get a winner.
        if ball.isPutAway {
            if dupr < 4.5 {
                errorRate = max(errorRate, 0.90)
            } else {
                let putAwayFloor: CGFloat = 0.50 + stretchFraction * 0.40
                errorRate = max(errorRate, putAwayFloor)
            }
        }

        return CGFloat.random(in: 0...1) < errorRate
    }

    /// Return a context-aware error type based on the last shot modes attempted.
    func errorType(for modes: DrillShotCalculator.ShotMode) -> NPCErrorType {
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
        // Default: even split
        if roll < 0.4 { return .net }
        if roll < 0.7 { return .long }
        return .wide
    }

    // MARK: - Forced Error (interactive mode — mirrors InteractiveMatchScene checkPlayerHit)

    func shouldCommitForcedError(ball: DrillBallSimulation, npcDUPR: Double) -> Bool {
        let ballSpeed = sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
        let maxSpeed = P.baseShotSpeed + 2.0 * (P.maxShotSpeed - P.baseShotSpeed)
        let speedFrac = max(0, min(1, (ballSpeed - P.baseShotSpeed) / (maxSpeed - P.baseShotSpeed)))
        let spinPressure = min(abs(ball.spinCurve) / P.spinCurveFactor, 1.0)

        let dx = ball.courtX - currentNX
        let dy = ball.courtY - currentNY
        let dist = sqrt(dx * dx + dy * dy)
        let stretchFrac = min(dist / hitboxRadius, 1.0)

        let shotDifficulty = speedFrac * PB.forcedErrorSpeedWeight
            + spinPressure * PB.forcedErrorSpinWeight
            + stretchFrac * PB.forcedErrorStretchWeight

        let reflexesStat = CGFloat(stats.stat(.reflexes))
        let consistencyStat = CGFloat(stats.stat(.consistency))
        let defenseStat = CGFloat(stats.stat(.defense))
        let avgDefense = (reflexesStat + consistencyStat + defenseStat) / 3.0 / 99.0
        var forcedErrorRate = shotDifficulty * PB.forcedErrorScale * pow(1.0 - avgDefense, PB.forcedErrorExponent)

        // Rally pressure
        let NPCS = GameConstants.NPCStrategy.self
        rallyPressure = max(0, rallyPressure - NPCS.pressureDecayPerShot)
        rallyPressure += shotDifficulty
        let pressureThreshold = NPCS.pressureBaseThreshold + avgDefense * NPCS.pressureStatScale
        let pressureOverflow = max(0, rallyPressure - pressureThreshold)
        let pressureBonus = pressureOverflow * NPCS.pressureErrorScale

        // DUPR gap amplifier (when NPC is stronger)
        let duprGapForPlayer = max(0, npcDUPR - dupr)
        let gapAmplifier = 1.0 + CGFloat(duprGapForPlayer) * NPCS.duprForcedErrorAmplifier
        forcedErrorRate = (forcedErrorRate + pressureBonus) * gapAmplifier

        // DUPR gap reduction (when player is stronger — weaker NPC shots are easier to return)
        let duprAdvantage = max(0, dupr - npcDUPR)
        if duprAdvantage > 0 {
            let reduction = max(CGFloat(NPCS.duprErrorFloor),
                                CGFloat(exp(-Double(duprAdvantage) * Double(NPCS.duprErrorGrowthRate))))
            forcedErrorRate *= reduction
        }

        return CGFloat.random(in: 0...1) < forcedErrorRate
    }

    // MARK: - Net Fault

    func shouldCommitNetFault(npcDUPR: Double) -> Bool {
        let accuracyStat = CGFloat(stats.stat(.accuracy))
        let consistencyStat = CGFloat(stats.stat(.consistency))
        let focusStat = CGFloat(stats.stat(.focus))
        let avgControl = (accuracyStat + consistencyStat + focusStat) / 3.0
        var netFaultRate = PB.netFaultBaseRate * pow(1.0 - avgControl / 99.0, 1.5)

        // DUPR gap reduction: stronger players make fewer net faults vs weaker opponents
        let NPCS = GameConstants.NPCStrategy.self
        let duprAdvantage = max(0, dupr - npcDUPR)
        if duprAdvantage > 0 {
            let reduction = max(CGFloat(NPCS.duprErrorFloor),
                                CGFloat(exp(-Double(duprAdvantage) * Double(NPCS.duprErrorGrowthRate))))
            netFaultRate *= reduction
        }

        return CGFloat.random(in: 0...1) < netFaultRate
    }

    // MARK: - Shot Mode Selection

    func selectShotModes(ball: DrillBallSimulation) -> SM {
        var modes: SM = []
        let staminaPct = stamina / P.maxStamina
        guard staminaPct > 0.10 else { return modes }

        // Skill-gated: beginners rarely use modes
        guard CGFloat.random(in: 0...1) < shotModeCompetence else { return modes }

        let ballHeight = ball.height
        let isHighBall = ballHeight > 0.06

        // Power on high balls
        if isHighBall && CGFloat.random(in: 0...1) < skillFraction * 0.6 {
            modes.insert(.power)
        }

        // Topspin or slice
        if !modes.contains(.power) && CGFloat.random(in: 0...1) < skillFraction * 0.3 {
            modes.insert(Bool.random() ? .topspin : .slice)
        }

        // Angled shots
        if CGFloat.random(in: 0...1) < skillFraction * 0.3 {
            modes.insert(.angled)
        }

        // Focus
        if staminaPct > 0.30 && CGFloat.random(in: 0...1) < skillFraction * 0.2 {
            modes.insert(.focus)
        }

        return modes
    }

    // MARK: - Shot Generation

    func generateShot(ball: DrillBallSimulation) -> DrillShotCalculator.ShotResult {
        serveTargetHint = nil  // Clear serve tracking after contact
        let modes = selectShotModes(ball: ball)
        shotCountThisPoint += 1
        let staminaFraction = stamina / P.maxStamina

        // Symmetric with NPC drain (MatchAI uses 5/3 for power/focus)
        if modes.contains(.power) {
            stamina = max(0, stamina - 5)
        }
        if modes.contains(.focus) {
            stamina = max(0, stamina - 3)
        }

        return DrillShotCalculator.calculatePlayerShot(
            stats: stats,
            ballApproachFromLeft: ball.courtX < currentNX,
            drillType: .baselineRally,
            ballHeight: ball.height,
            courtNX: currentNX,
            courtNY: currentNY,
            modes: modes,
            staminaFraction: staminaFraction,
            shooterDUPR: dupr
        )
    }

    func generateServe(playerScore: Int) -> DrillShotCalculator.ShotResult {
        // Simulated player serve: skill-gated power/spin
        var modes: SM = []

        if CGFloat.random(in: 0...1) < shotModeCompetence * 0.5 {
            modes.insert(.power)
            stamina = max(0, stamina - 5)
        }
        if CGFloat.random(in: 0...1) < shotModeCompetence * 0.3 {
            modes.insert(Bool.random() ? .topspin : .slice)
        }

        return DrillShotCalculator.calculatePlayerShot(
            stats: stats,
            ballApproachFromLeft: false,
            drillType: .baselineRally,
            ballHeight: 0.05,
            courtNX: currentNX,
            courtNY: currentNY,
            modes: modes,
            staminaFraction: stamina / P.maxStamina
        )
    }

    // MARK: - Reset

    func recoverBetweenPoints() {
        // Symmetric with NPC recovery (MatchAI uses 8 + staminaStat/99 * 12)
        let staminaStat = CGFloat(stats.stat(.stamina))
        let baseRecovery: CGFloat = 8
        let staminaBonus = (staminaStat / 99.0) * 12
        stamina = min(P.maxStamina, stamina + baseRecovery + staminaBonus)
    }

    func reset(isServing: Bool, playerScore: Int, npcScore: Int) {
        self.isServing = isServing
        self.shotCountThisPoint = 0
        self.rallyPressure = 0
        self.hasReacted = false
        self.reactionTimer = 0
        self.hasComputedNoise = false
        self.serveTargetHint = nil
        if isServing {
            positionForServe(playerScore: playerScore)
        } else {
            positionForReceive(npcScore: npcScore)
        }
    }
}
