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
    static func calculatePlayerShot(
        stats: PlayerStats,
        ballApproachFromLeft: Bool,
        drillType: DrillType,
        ballHeight: CGFloat = 0.0
    ) -> ShotResult {
        let P = GameConstants.DrillPhysics.self

        let powerStat = CGFloat(stats.stat(.power))
        let spinStat = CGFloat(stats.stat(.spin))

        // Shot type from ball approach direction
        let shotType: ShotType = ballApproachFromLeft ? .backhand : .forehand

        // Base power from stats
        var power: CGFloat
        if drillType == .dinkingDrill {
            // Dink: soft touch only, no power scaling
            power = 0.15 + (powerStat / 99.0) * 0.20
        } else if drillType == .baselineRally {
            // Baseline rally: hit harder to reach opponent's baseline
            power = 0.5 + (powerStat / 99.0) * 0.5
        } else {
            power = 0.3 + (powerStat / 99.0) * 0.7

            // Height bonus: higher ball at contact = more power (overhead smash)
            let heightBonus = min(ballHeight / 0.15, 1.0) * P.heightPowerBonus
            power += heightBonus
        }

        power = max(0.15, min(1.0, power))

        // Spin
        let spinDirection: CGFloat = Bool.random() ? 1.0 : -1.0
        let spinCurve = spinDirection * (spinStat / 99.0)

        // Arc
        let arc: CGFloat
        switch drillType {
        case .dinkingDrill:
            arc = CGFloat.random(in: 0.5...0.7)
        case .baselineRally:
            // Higher arc to drive ball deep near opponent's baseline
            arc = CGFloat.random(in: 0.40...0.55)
        default:
            arc = CGFloat.random(in: 0.25...0.35)
        }

        // Target on coach's side
        let (baseTargetNX, baseTargetNY) = targetForDrill(drillType)
        let targetNX = max(0.05, min(0.95, baseTargetNX))
        let targetNY: CGFloat
        if drillType == .dinkingDrill {
            // Dink: keep in opponent's kitchen (0.52–0.68, before their kitchen line)
            targetNY = max(0.52, min(0.68, baseTargetNY))
        } else if drillType == .baselineRally {
            // Baseline rally: aim deep near opponent's baseline
            targetNY = max(0.75, min(0.95, baseTargetNY))
        } else {
            targetNY = max(0.55, min(0.95, baseTargetNY))
        }

        return ShotResult(
            power: power,
            accuracy: 1.0,
            spinCurve: spinCurve,
            arc: arc,
            targetNX: targetNX,
            targetNY: targetNY,
            shotType: shotType
        )
    }

    /// Generate a shot for the coach (targets player's side of court).
    static func calculateCoachShot(
        stats: PlayerStats,
        ballApproachFromLeft: Bool,
        drillType: DrillType
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

        // High arc = deep landings near baseline (with gravity 1.2)
        let arc: CGFloat
        switch drillType {
        case .dinkingDrill:
            arc = 0.65  // dink: consistent soft lob
        case .accuracyDrill, .returnOfServe:
            arc = 0.45  // aggressive but still deep
        default:
            arc = 0.55  // rally: high arc, lands near baseline
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
            // Player's kitchen zone (between net and kitchen line at 0.318)
            targetNX = CGFloat.random(in: 0.25...0.75)
            targetNY = CGFloat.random(in: 0.20...0.30)
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
