import Foundation

enum DrillShotCalculator {
    struct ShotResult: Sendable {
        let power: CGFloat         // 0-1 speed magnitude
        let accuracy: CGFloat      // 0-1 deviation from target
        let spinCurve: CGFloat     // -1 to 1 lateral curve
        let arc: CGFloat           // 0-1 initial vertical velocity
        let targetNX: CGFloat      // target X in court space
        let targetNY: CGFloat      // target Y in court space
        let shotType: ShotType
        let topspinFactor: CGFloat // -1 = backspin, 0 = flat, +1 = topspin
    }

    enum ShotType: Sendable {
        case forehand
        case backhand
    }

    /// Player-selected shot modes — combinable toggles.
    struct ShotMode: OptionSet, Sendable {
        let rawValue: UInt
        static let power   = ShotMode(rawValue: 1 << 0) // drive — more speed, more scatter
        static let reset   = ShotMode(rawValue: 1 << 1) // lob to kitchen — mutually exclusive with power
        static let slice   = ShotMode(rawValue: 1 << 2) // backspin — low arc, less power
        static let topspin = ShotMode(rawValue: 1 << 3) // topspin — flatter arc, more power
        static let angled  = ShotMode(rawValue: 1 << 4) // cross-court sideline target
        static let focus   = ShotMode(rawValue: 1 << 5) // accuracy boost, drains stamina
    }

    /// Legacy intensity enum — still used by coach shots internally.
    enum ShotIntensity: Sendable {
        case soft   // dink/drop — targets opponent's kitchen, high arc, low power
        case medium // default rally shot
        case hard   // drive/speed-up — 20% more power, flatter, riskier (more scatter)
    }

    /// Calculate shot parameters from player stats and context.
    static func calculateShot(
        stats: PlayerStats,
        ballApproachFromLeft: Bool,
        drillType: DrillType,
        focusMultiplier: CGFloat = 1.0
    ) -> ShotResult {
        let powerStat = CGFloat(stats.stat(.power))
        let accuracyStat = CGFloat(stats.stat(.accuracy))
        let spinStat = CGFloat(stats.stat(.spin))
        let consistencyStat = CGFloat(stats.stat(.consistency))

        // Consistency reduces variance on all randomized outputs
        let varianceFactor = 1.0 - (consistencyStat / 99.0) * 0.6

        // Power → speed magnitude (0.3 to 1.0)
        let power: CGFloat
        switch drillType {
        case .dinkingDrill:
            // Dink: very soft power — keep ball in kitchen
            power = 0.15 + (powerStat / 99.0) * 0.20
        default:
            power = 0.3 + (powerStat / 99.0) * 0.7
        }

        // Accuracy → aim deviation (0 to 0.3 random offset)
        let baseDeviation = (1.0 - accuracyStat / 99.0) * 0.3 * focusMultiplier
        let deviation = baseDeviation * varianceFactor

        // Apply random scatter to target
        let scatterX = CGFloat.random(in: -deviation...deviation)
        let scatterY = CGFloat.random(in: -deviation...deviation)

        // Spin → lateral curve
        let spinDirection: CGFloat = Bool.random() ? 1.0 : -1.0
        let spinMagnitude = (spinStat / 99.0) * varianceFactor
        let spinCurve = spinDirection * spinMagnitude

        // Arc depends on drill type
        let arc: CGFloat
        switch drillType {
        case .dinkingDrill:
            // Dink: high arc, soft lob
            arc = CGFloat.random(in: 0.6...0.8)
        case .accuracyDrill, .returnOfServe:
            // Return: moderate arc
            arc = CGFloat.random(in: 0.2...0.5)
        default:
            // Baseline rally / serve: moderate arc
            arc = CGFloat.random(in: 0.2...0.5)
        }

        // Target location based on drill type
        let (baseTargetNX, baseTargetNY) = targetForDrill(drillType)
        let targetNX = max(0.05, min(0.95, baseTargetNX + scatterX))
        let targetNY = max(0.05, min(0.95, baseTargetNY + scatterY))

        // Shot type from ball approach direction
        let shotType: ShotType = ballApproachFromLeft ? .backhand : .forehand

        return ShotResult(
            power: power,
            accuracy: 1.0 - deviation,
            spinCurve: spinCurve,
            arc: arc,
            targetNX: targetNX,
            targetNY: targetNY,
            shotType: shotType,
            topspinFactor: 0
        )
    }

    /// Generate a target location appropriate for the drill type.
    /// Returns (nx, ny) in opponent's court half.
    private static func targetForDrill(_ drillType: DrillType) -> (CGFloat, CGFloat) {
        switch drillType {
        case .dinkingDrill:
            // Dink: target opponent's kitchen zone (between net at 0.50 and kitchen line at 0.682)
            return (CGFloat.random(in: 0.25...0.75), CGFloat.random(in: 0.52...0.66))
        case .baselineRally:
            // Rally: varying cross-court locations
            return (CGFloat.random(in: 0.15...0.85), CGFloat.random(in: 0.65...0.95))
        case .accuracyDrill, .returnOfServe:
            // Return: deep cross-court
            return (CGFloat.random(in: 0.15...0.85), CGFloat.random(in: 0.65...0.90))
        case .servePractice:
            // Serve: deep on opponent's side
            return (CGFloat.random(in: 0.20...0.80), CGFloat.random(in: 0.65...0.90))
        }
    }

    /// Calculate the arc value needed so the ball lands at the target distance.
    /// Uses projectile physics: arc is the value passed to launch(), which sets vz = arc * speed * 2.0.
    /// Returns the arc such that h(travelTime) ≈ 0, with a margin for net clearance.
    private static func arcToLandAt(
        distanceNY: CGFloat,
        power: CGFloat,
        initialHeight: CGFloat = 0.05,
        arcMargin: CGFloat = 1.15 // 15% extra arc for net clearance margin
    ) -> CGFloat {
        let P = GameConstants.DrillPhysics.self
        let speed = P.baseShotSpeed + power * (P.maxShotSpeed - P.baseShotSpeed)
        guard speed > 0.01, distanceNY > 0.01 else { return 0.3 }

        // Time for ball to travel to target (horizontal speed ≈ total speed for mostly-forward shots)
        let travelTime = distanceNY / speed

        // Solve for vz so that h(t) = 0 at travelTime:
        // 0 = h0 + vz*t - 0.5*g*t²  →  vz = (0.5*g*t² - h0) / t
        let vzNeeded = (0.5 * P.gravity * travelTime * travelTime - initialHeight) / travelTime

        // Convert vz to arc: launch() does vz = arc * speed * 2.0
        let arc = vzNeeded / (speed * 2.0)
        return max(0.08, arc * arcMargin)
    }

    /// Generate a shot for the player.
    /// - ballHeight: ball height at time of contact (logical units)
    /// - courtNY: player's current court position (0=near baseline, 0.5=net)
    /// - modes: combinable shot mode toggles (power, reset, slice, topspin, angled)
    static func calculatePlayerShot(
        stats: PlayerStats,
        ballApproachFromLeft: Bool,
        drillType: DrillType,
        ballHeight: CGFloat = 0.0,
        courtNY: CGFloat = 0.1,
        modes: ShotMode = [],
        staminaFraction: CGFloat = 1.0
    ) -> ShotResult {
        let P = GameConstants.DrillPhysics.self

        let powerStat = CGFloat(stats.stat(.power))
        let spinStat = CGFloat(stats.stat(.spin))
        let accuracyStat = CGFloat(stats.stat(.accuracy))
        let consistencyStat = CGFloat(stats.stat(.consistency))

        // Shot type from ball approach direction
        let shotType: ShotType = ballApproachFromLeft ? .backhand : .forehand

        // --- Reset mode: soft lob to kitchen (mutually exclusive with power) ---
        if modes.contains(.reset) {
            let resetPower = CGFloat.random(in: 0.15...0.35)
            let resetArc = CGFloat.random(in: 0.55...0.75)
            var targetNX = CGFloat.random(in: 0.25...0.75)
            var targetNY = CGFloat.random(in: 0.52...0.66)

            // Angled modifier on reset
            if modes.contains(.angled) {
                if ballApproachFromLeft { targetNX = 0.90 } else { targetNX = 0.10 }
            }

            let spinDirection: CGFloat = Bool.random() ? 1.0 : -1.0
            let spinCurve = spinDirection * (spinStat / 99.0) * 0.3
            targetNX = max(0.05, min(0.95, targetNX))
            targetNY = max(0.52, min(0.68, targetNY))

            return ShotResult(
                power: resetPower,
                accuracy: 1.0,
                spinCurve: spinCurve,
                arc: resetArc,
                targetNX: targetNX,
                targetNY: targetNY,
                shotType: shotType,
                topspinFactor: 0
            )
        }

        // --- Base shot (default medium behavior) ---
        var power: CGFloat
        var arc: CGFloat
        var scatter: CGFloat = 0
        var topspinFactor: CGFloat = 0
        var targetNX: CGFloat
        var targetNY: CGFloat

        if drillType == .dinkingDrill && modes.isEmpty {
            power = 0.15 + (powerStat / 99.0) * 0.20
        } else if drillType == .baselineRally && modes.isEmpty {
            power = 0.5 + (powerStat / 99.0) * 0.5
        } else {
            power = 0.3 + (powerStat / 99.0) * 0.7
            let heightBonus = min(ballHeight / 0.15, 1.0) * P.heightPowerBonus
            power += heightBonus
        }

        // Default target by drill type
        let (baseNX, baseNY) = targetForDrill(drillType)
        targetNX = baseNX
        if drillType == .dinkingDrill {
            targetNY = max(0.52, min(0.68, baseNY))
        } else if drillType == .baselineRally {
            targetNY = max(0.75, min(0.95, baseNY))
        } else {
            targetNY = max(0.55, min(0.95, baseNY))
        }

        // --- Apply mode modifiers ---

        // Power mode: full power scaled by stamina — low stamina = closer to regular shot
        if modes.contains(.power) {
            let fullPower: CGFloat = 0.85 + (powerStat / 99.0) * 0.15 // 0.85–1.0
            let regularPower = power  // whatever the base shot computed
            // Lerp: at full stamina → full power, at 0 stamina → regular power
            power = regularPower + (fullPower - regularPower) * staminaFraction
            let scatterMultiplier = 1.2 + (1.0 - accuracyStat / 99.0) * 0.3
            let controlFactor = 1.0 - ((accuracyStat + consistencyStat) / 198.0) * 0.7
            scatter = 0.08 * controlFactor * scatterMultiplier
            // Target 1-2ft inside baseline (≈ 0.90–0.95 ny)
            targetNY = CGFloat.random(in: 0.90...0.95)
        }

        // Slice: slightly less power, backspin — skids after bounce
        if modes.contains(.slice) {
            power *= 0.85
            topspinFactor = -0.7
        }

        // Topspin: slightly slower initial, dips in flight, accelerates after bounce
        if modes.contains(.topspin) {
            power *= 0.90
            topspinFactor = 0.8
        }

        // Angled: target sidelines (~2ft from line = ~0.10 or 0.90 nx)
        if modes.contains(.angled) {
            if ballApproachFromLeft {
                targetNX = 0.90
            } else {
                targetNX = 0.10
            }
        }

        // Focus: boost accuracy — significantly reduce scatter
        if modes.contains(.focus) {
            scatter *= 0.3  // 70% less scatter
        }

        power = max(0.15, min(1.0, power))

        // --- Physics-based arc calculation ---
        // Calculate the distance from player to target, then compute the exact arc
        // needed so the ball lands at that distance (with net clearance margin).
        let distToTarget = abs(targetNY - courtNY)

        if drillType == .dinkingDrill && modes.isEmpty {
            // Dinks use high loopy arc (not physics-targeted, they're touch shots)
            arc = CGFloat.random(in: 0.5...0.7)
        } else {
            // Compute arc to land at target
            var margin: CGFloat = 1.15  // 15% net clearance margin
            if modes.contains(.topspin) {
                // Topspin dips in flight (Magnus), so needs ~2x higher initial arc
                // to clear the net, then dips down onto the court
                margin = 1.8
            } else if modes.contains(.slice) {
                // Slice floats slightly (backspin Magnus), can be flatter
                margin = 0.95
            } else if modes.contains(.power) {
                // Power: flat and fast, just enough to clear net
                margin = 1.10
            }
            arc = arcToLandAt(distanceNY: distToTarget, power: power, arcMargin: margin)
        }

        // Apply scatter
        let scatterX = scatter > 0 ? CGFloat.random(in: -scatter...scatter) : 0
        let scatterY = scatter > 0 ? CGFloat.random(in: -scatter...scatter) : 0

        // Spin
        let spinDirection: CGFloat = Bool.random() ? 1.0 : -1.0
        let spinCurve = spinDirection * (spinStat / 99.0)

        targetNX = max(0.05, min(0.95, targetNX + scatterX))
        targetNY = max(0.52, min(0.98, targetNY + scatterY))

        return ShotResult(
            power: power,
            accuracy: scatter > 0 ? max(0, 1.0 - scatter * 5) : 1.0,
            spinCurve: spinCurve,
            arc: arc,
            targetNX: targetNX,
            targetNY: targetNY,
            shotType: shotType,
            topspinFactor: topspinFactor
        )
    }

    /// Generate a shot for the coach (targets player's side of court).
    /// - courtNY: coach's current court position (0.5=net, 1.0=far baseline)
    static func calculateCoachShot(
        stats: PlayerStats,
        ballApproachFromLeft: Bool,
        drillType: DrillType,
        courtNY: CGFloat = 0.9
    ) -> ShotResult {
        let powerStat = CGFloat(stats.stat(.power))
        let accuracyStat = CGFloat(stats.stat(.accuracy))
        let spinStat = CGFloat(stats.stat(.spin))

        // Coach power: moderate, controlled shots
        let power: CGFloat
        switch drillType {
        case .dinkingDrill:
            power = 0.15 + (powerStat / 99.0) * 0.15
        case .accuracyDrill, .returnOfServe:
            power = 0.4 + (powerStat / 99.0) * 0.4
        default:
            power = 0.3 + (powerStat / 99.0) * 0.5
        }

        // Coach scatter is much tighter than generic shots
        let maxDeviation: CGFloat = (1.0 - accuracyStat / 99.0) * 0.08
        let scatterX = CGFloat.random(in: -maxDeviation...maxDeviation)
        let scatterY = CGFloat.random(in: -maxDeviation...maxDeviation)

        // Arc scales with distance from net: farther = higher arc, closer = flatter
        let distFromNet = abs(0.5 - courtNY)  // 0.0 at net, ~0.5 at baseline
        let distanceFactor = min(distFromNet / 0.5, 1.0)  // 0.0 at net, 1.0 at baseline
        let arc: CGFloat
        switch drillType {
        case .dinkingDrill:
            arc = 0.55 + distanceFactor * 0.15  // 0.55–0.70 (soft lob, higher from farther)
        case .accuracyDrill, .returnOfServe:
            arc = 0.25 + distanceFactor * 0.25  // 0.25–0.50 (aggressive, scales with distance)
        default:
            arc = 0.30 + distanceFactor * 0.30  // 0.30–0.60 (rally, scales with distance)
        }

        // Light spin from coach
        let spinDirection: CGFloat = Bool.random() ? 1.0 : -1.0
        let spinCurve = spinDirection * (spinStat / 99.0) * 0.3

        // Target deep on player's side (near baseline)
        let targetNX: CGFloat
        let targetNY: CGFloat
        switch drillType {
        case .accuracyDrill, .returnOfServe:
            // Corners, deep
            let corner = Bool.random()
            targetNX = corner ? CGFloat.random(in: 0.10...0.30) : CGFloat.random(in: 0.70...0.90)
            targetNY = CGFloat.random(in: 0.03...0.18)
        case .dinkingDrill:
            // Player's kitchen zone (between kitchen line at 0.318 and net at 0.50)
            targetNX = CGFloat.random(in: 0.25...0.75)
            targetNY = CGFloat.random(in: 0.33...0.47)
        default:
            // Baseline rally: deep, near baseline
            targetNX = CGFloat.random(in: 0.15...0.85)
            targetNY = CGFloat.random(in: 0.03...0.15)
        }

        let shotType: ShotType = ballApproachFromLeft ? .backhand : .forehand

        return ShotResult(
            power: power,
            accuracy: 1.0 - maxDeviation,
            spinCurve: spinCurve,
            arc: arc,
            targetNX: max(0.05, min(0.95, targetNX + scatterX)),
            targetNY: max(0.05, min(0.45, targetNY + scatterY)),
            shotType: shotType,
            topspinFactor: 0
        )
    }
}
