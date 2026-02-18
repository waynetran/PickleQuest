import CoreGraphics

@MainActor
final class DrillCoachAI {
    private typealias P = GameConstants.DrillPhysics

    var currentNX: CGFloat
    var currentNY: CGFloat
    var targetNX: CGFloat
    var targetNY: CGFloat

    let coachLevel: Int
    let drillType: DrillType
    private let config: DrillConfig
    private let playerStatAverage: CGFloat

    /// When true, coach will not miss the next shot (expanded hitbox).
    private var guaranteeNextHit: Bool = false
    /// Alternates serve side each point (rally drill: right then left).
    private var serveFromRight: Bool = true
    /// Tracks how many serves the coach has sent (for return of serve alternating).
    private var serveCount: Int = 0

    /// Synthetic stats derived from coach level.
    var syntheticStats: PlayerStats {
        let v = 10 + coachLevel * 14  // Level 1: 24, Level 5: 80
        return PlayerStats(
            power: v, accuracy: v, spin: v, speed: v,
            defense: v, reflexes: v, positioning: v,
            clutch: v, focus: v, stamina: v, consistency: v
        )
    }

    /// Movement speed in court units per second.
    private var moveSpeed: CGFloat {
        0.3 + CGFloat(coachLevel) * 0.1
    }

    /// Hitbox radius in court-space units.
    private var hitboxRadius: CGFloat {
        let statValue = CGFloat(10 + coachLevel * 14)
        return P.baseHitboxRadius + (statValue / 99.0) * P.positioningHitboxBonus
    }

    init(config: DrillConfig, coachLevel: Int, playerStatAverage: Double = 50.0) {
        self.config = config
        self.coachLevel = coachLevel
        self.drillType = config.drillType
        self.playerStatAverage = CGFloat(playerStatAverage)
        self.currentNX = config.coachStartNX
        self.currentNY = config.coachStartNY
        self.targetNX = config.coachStartNX
        self.targetNY = config.coachStartNY
    }

    /// Where the coach should stand between rallies (varies by drill/serve side).
    private var homeNX: CGFloat {
        if drillType == .baselineRally {
            return serveFromRight ? 0.75 : 0.25
        }
        return config.coachStartNX
    }

    /// Update coach position each frame, moving toward ball's projected landing.
    func update(dt: CGFloat, ball: DrillBallSimulation) {
        if ball.isActive && ball.lastHitByPlayer {
            // Ball heading toward coach — intercept
            predictLanding(ball: ball)
        } else if ball.isActive && !ball.lastHitByPlayer {
            // Ball heading toward player (coach just fed/hit) — move to ready position
            targetNX = config.coachStartNX
            targetNY = config.coachStartNY
        } else {
            // Ball inactive (between rallies) — move to next serve position
            targetNX = homeNX
            targetNY = config.coachStartNY
        }

        // Move toward target
        let dx = targetNX - currentNX
        let dy = targetNY - currentNY
        let dist = sqrt(dx * dx + dy * dy)

        if dist > 0.01 {
            let step = moveSpeed * dt
            if step >= dist {
                currentNX = targetNX
                currentNY = targetNY
            } else {
                currentNX += (dx / dist) * step
                currentNY += (dy / dist) * step
            }
        }

        // Clamp to coach's side of court — never enter kitchen (kitchen line at 0.682)
        // Use 0.78 minimum so the coach sprite doesn't visually overlap the grey kitchen zone
        currentNX = max(0.0, min(1.0, currentNX))
        let minCoachNY: CGFloat = 0.78
        switch drillType {
        case .dinkingDrill:
            currentNY = max(minCoachNY, min(0.92, currentNY))
        default:
            currentNY = max(max(minCoachNY, config.coachStartNY - 0.10), min(1.0, currentNY))
        }
    }

    /// Check if ball is within coach's hitbox and hittable (3D distance).
    func shouldSwing(ball: DrillBallSimulation) -> Bool {
        guard ball.isActive, ball.lastHitByPlayer else { return false }
        guard ball.bounceCount < 2 else { return false }

        // In serve practice and return of serve, coach doesn't return — just catches
        if drillType == .servePractice || drillType == .returnOfServe { return false }

        // Pre-bounce: don't reach forward — wait for ball to arrive at coach's Y
        if ball.bounceCount == 0 && ball.courtY < currentNY { return false }

        // 3D hitbox: coach has high athleticism (stat 80 equivalent reach)
        let coachHeightReach = P.baseHeightReach + 0.8 * P.maxHeightReachBonus // ~0.30
        let excessHeight = max(0, ball.height - coachHeightReach)

        let dx = ball.courtX - currentNX
        let dy = ball.courtY - currentNY
        let dist = sqrt(dx * dx + dy * dy + excessHeight * excessHeight)

        // Guaranteed first return: use very generous hitbox
        let effectiveRadius = guaranteeNextHit ? 0.5 : hitboxRadius
        return dist <= effectiveRadius
    }

    /// Generate a return shot from the coach.
    func generateShot(ball: DrillBallSimulation) -> DrillShotCalculator.ShotResult {
        // Clear guarantee after first return
        guaranteeNextHit = false

        let ballFromLeft = ball.courtX < currentNX
        return DrillShotCalculator.calculateCoachShot(
            stats: syntheticStats,
            ballApproachFromLeft: ballFromLeft,
            drillType: drillType,
            courtNY: currentNY
        )
    }

    /// Predict where the ball will land and set that as the movement target.
    private func predictLanding(ball: DrillBallSimulation) {
        // Simple prediction: extrapolate ball position forward
        let lookAhead: CGFloat = 0.5  // seconds
        let predictedX = ball.courtX + ball.vx * lookAhead
        let predictedY = ball.courtY + ball.vy * lookAhead

        let minCoachNY = config.coachStartNY - 0.10
        targetNX = max(0.05, min(0.95, predictedX))
        targetNY = max(minCoachNY, min(0.98, predictedY))
    }

    /// Reset to starting position.
    func reset() {
        currentNX = config.coachStartNX
        currentNY = config.coachStartNY
        targetNX = config.coachStartNX
        targetNY = config.coachStartNY
    }

    /// Difficulty scale (0.0–1.0) blending coach level with player stats.
    private var difficulty: CGFloat {
        let coachDifficulty = CGFloat(coachLevel - 1) / 4.0
        let playerScale = playerStatAverage / 99.0
        return coachDifficulty * (0.3 + 0.7 * playerScale)
    }

    /// Feed a new ball to start a rally (baseline, dinking modes).
    func feedBall(ball: DrillBallSimulation) {
        // Coach always returns the first shot after feeding
        guaranteeNextHit = true

        let feedPower = 0.5 + difficulty * 0.35
        let feedArc = 0.55 - difficulty * 0.10

        let targetNY: CGFloat
        let targetNX: CGFloat
        switch drillType {
        case .baselineRally:
            // Baseline rally: serve from alternating sides
            let serveNX: CGFloat = serveFromRight ? 0.75 : 0.25
            currentNX = serveNX
            self.targetNX = serveNX
            serveFromRight.toggle()
            targetNX = CGFloat.random(in: 0.25...0.75)
            targetNY = CGFloat.random(in: 0.05...0.20)
        case .dinkingDrill:
            // Dink: soft feeds into player's kitchen zone (between kitchen line 0.318 and net 0.50)
            targetNX = CGFloat.random(in: 0.25...0.75)
            targetNY = CGFloat.random(in: 0.33...0.47)
            ball.launch(
                from: CGPoint(x: currentNX, y: currentNY),
                toward: CGPoint(x: targetNX, y: targetNY),
                power: 0.20 + difficulty * 0.10,
                arc: 0.70,
                spin: 0
            )
            ball.lastHitByPlayer = false
            return
        case .servePractice:
            // Serve practice: coach doesn't feed — player serves
            return
        case .accuracyDrill, .returnOfServe:
            // Coach serves to player
            return
        }

        ball.launch(
            from: CGPoint(x: currentNX, y: currentNY),
            toward: CGPoint(x: targetNX, y: targetNY),
            power: feedPower,
            arc: feedArc,
            spin: 0
        )
        ball.lastHitByPlayer = false
    }

    /// Coach serves to the player.
    /// Accuracy drill: first 5 from right, next 5 from left.
    /// Return of serve: first 5 from LEFT (cross-court), next 5 from RIGHT (cross-court).
    func serveToPlayer(ball: DrillBallSimulation) {
        serveCount += 1

        let serveNX: CGFloat
        let targetNX: CGFloat

        switch drillType {
        case .returnOfServe:
            // Cross-court: LEFT side first (5), then RIGHT side (5)
            let fromLeft = serveCount <= 5
            serveNX = fromLeft ? 0.25 : 0.75
            // Cross-court target: opposite side of where coach is
            targetNX = fromLeft
                ? CGFloat.random(in: 0.55...0.80)
                : CGFloat.random(in: 0.20...0.45)
        default:
            // Accuracy drill: RIGHT side first (5), then LEFT side (5)
            let fromRight = serveCount <= 5
            serveNX = fromRight ? 0.75 : 0.25
            targetNX = CGFloat.random(in: 0.25...0.75)
        }

        currentNX = serveNX
        self.targetNX = serveNX
        currentNY = config.coachStartNY

        let servePower = 0.5 + difficulty * 0.3
        let serveArc: CGFloat = 0.50

        // Target close to player's baseline
        let targetNY = CGFloat.random(in: 0.05...0.18)

        ball.launch(
            from: CGPoint(x: serveNX, y: currentNY),
            toward: CGPoint(x: targetNX, y: targetNY),
            power: servePower,
            arc: serveArc,
            spin: difficulty * 0.2 * (Bool.random() ? 1 : -1)
        )
        ball.lastHitByPlayer = false
    }
}
