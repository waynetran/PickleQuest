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
    }

    enum ShotType: Sendable {
        case forehand
        case backhand
    }

    /// Player-selected shot intensity from Soft/Hard buttons.
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
            shotType: shotType
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

    /// Generate a shot for the player.
    /// - ballHeight: ball height at time of contact (logical units)
    /// - courtNY: player's current court position (0=near baseline, 0.5=net)
    /// - intensity: soft (drop/dink), medium (default), hard (drive/speed-up)
    static func calculatePlayerShot(
        stats: PlayerStats,
        ballApproachFromLeft: Bool,
        drillType: DrillType,
        ballHeight: CGFloat = 0.0,
        courtNY: CGFloat = 0.1,
        intensity: ShotIntensity = .medium
    ) -> ShotResult {
        let P = GameConstants.DrillPhysics.self

        let powerStat = CGFloat(stats.stat(.power))
        let spinStat = CGFloat(stats.stat(.spin))
        let accuracyStat = CGFloat(stats.stat(.accuracy))
        let consistencyStat = CGFloat(stats.stat(.consistency))

        // Shot type from ball approach direction
        let shotType: ShotType = ballApproachFromLeft ? .backhand : .forehand

        // Distance from net (0.5) — closer to net = shorter distance to cover
        let distFromNet = abs(0.5 - courtNY)  // 0.0 at net, ~0.5 at baseline

        // Base power from stats
        var power: CGFloat
        if intensity == .soft || drillType == .dinkingDrill {
            // Soft: dink/drop shot — low power, touch-based
            power = 0.15 + (powerStat / 99.0) * 0.20
        } else if drillType == .baselineRally && intensity == .medium {
            power = 0.5 + (powerStat / 99.0) * 0.5
        } else if intensity == .hard {
            // Hard: 20% more power — drive/speed-up
            let basePower = 0.5 + (powerStat / 99.0) * 0.5
            power = basePower * 1.2
        } else {
            power = 0.3 + (powerStat / 99.0) * 0.7

            // Height bonus: higher ball at contact = more power (overhead smash)
            let heightBonus = min(ballHeight / 0.15, 1.0) * P.heightPowerBonus
            power += heightBonus
        }

        power = max(0.15, min(1.0, power))

        // Scatter: hard shots are riskier — more deviation inversely scaled by accuracy/consistency
        var scatter: CGFloat = 0
        if intensity == .hard {
            let controlFactor = 1.0 - ((accuracyStat + consistencyStat) / 198.0) * 0.7
            scatter = 0.08 * controlFactor  // max ±0.08 scatter, reduced by stats
        }
        let scatterX = scatter > 0 ? CGFloat.random(in: -scatter...scatter) : 0
        let scatterY = scatter > 0 ? CGFloat.random(in: -scatter...scatter) : 0

        // Spin
        let spinDirection: CGFloat = Bool.random() ? 1.0 : -1.0
        let spinCurve = spinDirection * (spinStat / 99.0)

        // Arc scales with distance from net and intensity
        let distanceFactor = min(distFromNet / 0.5, 1.0)  // 0.0 at net, 1.0 at baseline
        var arc: CGFloat
        if intensity == .soft {
            // Soft: high arc (lob/drop), always floaty
            arc = CGFloat.random(in: 0.55...0.75)
        } else if intensity == .hard {
            // Hard: flat and fast
            let baseArc: CGFloat = 0.10 + distanceFactor * 0.15  // 0.10–0.25
            arc = baseArc + CGFloat.random(in: -0.03...0.03)
        } else {
            switch drillType {
            case .dinkingDrill:
                arc = CGFloat.random(in: 0.5...0.7)
            case .baselineRally:
                let baseArc: CGFloat = 0.30 + distanceFactor * 0.30
                arc = baseArc + CGFloat.random(in: -0.05...0.05)
            default:
                let baseArc: CGFloat = 0.20 + distanceFactor * 0.20
                arc = baseArc + CGFloat.random(in: -0.05...0.05)
            }
        }

        // Target: intensity overrides drill-type defaults
        var targetNX: CGFloat
        var targetNY: CGFloat
        if intensity == .soft {
            // Soft: aim for opponent's kitchen zone (0.52–0.66)
            targetNX = CGFloat.random(in: 0.25...0.75)
            targetNY = CGFloat.random(in: 0.52...0.66)
        } else if intensity == .hard {
            // Hard: aim deep + toward sidelines (passing shot)
            let side = Bool.random()
            targetNX = side ? CGFloat.random(in: 0.10...0.30) : CGFloat.random(in: 0.70...0.90)
            targetNY = CGFloat.random(in: 0.75...0.98)
        } else {
            let (baseNX, baseNY) = targetForDrill(drillType)
            targetNX = baseNX
            if drillType == .dinkingDrill {
                targetNY = max(0.52, min(0.68, baseNY))
            } else if drillType == .baselineRally {
                targetNY = max(0.75, min(0.95, baseNY))
            } else {
                targetNY = max(0.55, min(0.95, baseNY))
            }
        }

        targetNX = max(0.05, min(0.95, targetNX + scatterX))
        targetNY = max(0.52, min(0.98, targetNY + scatterY))

        return ShotResult(
            power: power,
            accuracy: scatter > 0 ? max(0, 1.0 - scatter * 5) : 1.0,
            spinCurve: spinCurve,
            arc: arc,
            targetNX: targetNX,
            targetNY: targetNY,
            shotType: shotType
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
            shotType: shotType
        )
    }
}
