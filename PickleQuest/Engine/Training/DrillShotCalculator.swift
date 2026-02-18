import Foundation

enum DrillShotCalculator {
    struct ShotResult: Sendable {
        var power: CGFloat         // 0-1 speed magnitude
        var accuracy: CGFloat      // 0-1 deviation from target
        var spinCurve: CGFloat     // -1 to 1 lateral curve
        var arc: CGFloat           // 0-1 initial vertical velocity
        var targetNX: CGFloat      // target X in court space
        var targetNY: CGFloat      // target Y in court space
        let shotType: ShotType
        var topspinFactor: CGFloat // -1 = backspin, 0 = flat, +1 = topspin
        var smashFactor: CGFloat = 0 // 0 = normal, 1 = full overhead smash
    }

    enum ShotType: Sendable {
        case forehand
        case backhand
    }

    /// Player-selected shot modes — combinable toggles.
    struct ShotMode: OptionSet, Sendable {
        let rawValue: UInt
        static let power   = ShotMode(rawValue: 1 << 0) // drive — more speed, more scatter
        static let touch   = ShotMode(rawValue: 1 << 1) // dink/drop/reset — mutually exclusive with power
        static let slice   = ShotMode(rawValue: 1 << 2) // backspin — low arc, less power
        static let topspin = ShotMode(rawValue: 1 << 3) // topspin — flatter arc, more power
        static let angled  = ShotMode(rawValue: 1 << 4) // cross-court sideline target
        static let focus   = ShotMode(rawValue: 1 << 5) // accuracy boost, drains stamina
        static let lob    = ShotMode(rawValue: 1 << 6) // high lob to baseline — mutually exclusive with touch/power
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
    /// - distanceNX: X distance to target (used for accurate travel time on cross-court shots)
    static func arcToLandAt(
        distanceNY: CGFloat,
        distanceNX: CGFloat = 0,
        power: CGFloat,
        initialHeight: CGFloat = 0.05,
        arcMargin: CGFloat = 1.0 // ensureNetClearance() handles net safety
    ) -> CGFloat {
        let P = GameConstants.DrillPhysics.self
        let speed = P.baseShotSpeed + power * (P.maxShotSpeed - P.baseShotSpeed)
        guard speed > 0.01, distanceNY > 0.01 else { return 0.3 }

        // Travel time based on total distance (launch() splits speed by direction vector)
        let totalDist = sqrt(distanceNX * distanceNX + distanceNY * distanceNY)
        let travelTime = totalDist / speed

        // Solve for vz so that h(t) = 0 at travelTime:
        // 0 = h0 + vz*t - 0.5*g*t²  →  vz = (0.5*g*t² - h0) / t
        let vzNeeded = (0.5 * P.gravity * travelTime * travelTime - initialHeight) / travelTime

        // Convert vz to arc: launch() does vz = arc * speed * 2.0
        let arc = vzNeeded / (speed * 2.0)
        // Cap arc to prevent absurdly floaty trajectories at low power
        return min(0.85, max(0.08, arc * arcMargin))
    }

    /// Generate a shot for the player.
    /// - ballHeight: ball height at time of contact (logical units)
    /// - courtNY: player's current court position (0=near baseline, 0.5=net)
    /// - modes: combinable shot mode toggles (power, reset, slice, topspin, angled)
    /// - opponentNX: opponent's X position in court space (nil = no tactical bias)
    /// - placementFraction: 0 = full random, 1 = full bias toward opponent's weak side
    static func calculatePlayerShot(
        stats: PlayerStats,
        ballApproachFromLeft: Bool,
        drillType: DrillType,
        ballHeight: CGFloat = 0.0,
        ballHeightAtNet: CGFloat = 0.0,
        courtNX: CGFloat = 0.5,
        courtNY: CGFloat = 0.1,
        modes: ShotMode = [],
        staminaFraction: CGFloat = 1.0,
        opponentNX: CGFloat? = nil,
        placementFraction: CGFloat = 0
    ) -> ShotResult {
        let P = GameConstants.DrillPhysics.self

        let powerStat = CGFloat(stats.stat(.power))
        let spinStat = CGFloat(stats.stat(.spin))
        let accuracyStat = CGFloat(stats.stat(.accuracy))
        let consistencyStat = CGFloat(stats.stat(.consistency))

        // Shot type from ball approach direction
        let shotType: ShotType = ballApproachFromLeft ? .backhand : .forehand

        // Far-side shooters (NPC at ny>0.5): targets must be mirrored to opponent's court half
        let shootingFromFarSide = courtNY > 0.5

        // --- Touch mode: dink/drop/reset to kitchen (mutually exclusive with power) ---
        if modes.contains(.touch) {
            let touchPower = CGFloat.random(in: 0.15...0.35)
            var targetNX = CGFloat.random(in: 0.25...0.75)
            // Target the kitchen zone (net to kitchen line)
            var targetNY = CGFloat.random(in: 0.52...0.68)

            // Angled modifier on touch
            if modes.contains(.angled) {
                if ballApproachFromLeft { targetNX = 0.82 } else { targetNX = 0.18 }
            }

            let spinDirection: CGFloat = Bool.random() ? 1.0 : -1.0
            let spinCurve = spinDirection * (spinStat / 99.0) * 0.3
            targetNX = max(0.05, min(0.95, targetNX))

            // Mirror target for far-side shooter
            if shootingFromFarSide {
                targetNY = 1.0 - targetNY
                targetNY = max(0.32, min(0.48, targetNY))
            } else {
                targetNY = max(0.52, min(0.68, targetNY))
            }

            // Always use physics-based arc so the ball actually lands at the target
            let touchDistNY = abs(targetNY - courtNY)
            let touchDistNX = abs(targetNX - courtNX)
            let touchArc = arcToLandAt(
                distanceNY: touchDistNY,
                distanceNX: touchDistNX,
                power: touchPower,
                arcMargin: shootingFromFarSide ? 1.05 : 1.10
            )

            return ShotResult(
                power: touchPower,
                accuracy: 1.0,
                spinCurve: spinCurve,
                arc: touchArc,
                targetNX: targetNX,
                targetNY: targetNY,
                shotType: shotType,
                topspinFactor: 0
            )
        }

        // --- Lob mode: high arc to baseline (mutually exclusive with touch/power) ---
        // Low-skill: lobs land short (mid-court), wide scatter, not deep enough
        // High-skill: lobs target baseline corners precisely
        if modes.contains(.lob) {
            let accuracyStat = CGFloat(stats.stat(.accuracy))
            let consistencyStat = CGFloat(stats.stat(.consistency))
            let avgControl = (accuracyStat + consistencyStat) / 2.0
            let lobSkill = min(avgControl / 99.0, 1.0) // 0 = beginner, 1 = expert

            // Lob power: moderate — enough to reach the baseline
            let lobPower = CGFloat.random(in: 0.30...0.50)

            // Target depth: beginners land mid-court (0.65-0.80), experts hit deep baseline (0.88-0.98)
            let minDepth = 0.65 + lobSkill * 0.23  // beginner: 0.65, expert: 0.88
            let maxDepth = 0.80 + lobSkill * 0.18  // beginner: 0.80, expert: 0.98
            var lobTargetNY = CGFloat.random(in: minDepth...maxDepth)

            // Target width: beginners aim center, experts target corners
            var lobTargetNX: CGFloat
            if lobSkill > 0.6 {
                // Experts: aim for baseline corners (away from opponent if possible)
                let corner = Bool.random() ? CGFloat.random(in: 0.10...0.25) : CGFloat.random(in: 0.75...0.90)
                lobTargetNX = corner
            } else {
                // Beginners: scatter around center
                lobTargetNX = CGFloat.random(in: 0.25...0.75)
            }

            // Angled modifier on lob
            if modes.contains(.angled) {
                if ballApproachFromLeft { lobTargetNX = 0.85 } else { lobTargetNX = 0.15 }
            }

            // Mirror target for far-side shooter
            if shootingFromFarSide {
                lobTargetNY = 1.0 - lobTargetNY
            }

            // Beginner scatter: low-stat players lob too short or too long
            let lobScatter = 0.15 * (1.0 - lobSkill)
            lobTargetNX += CGFloat.random(in: -lobScatter...lobScatter)
            lobTargetNY += CGFloat.random(in: -lobScatter...lobScatter)

            // Soft clamp: allow slightly out for genuine misses
            lobTargetNX = max(-0.05, min(1.05, lobTargetNX))
            if shootingFromFarSide {
                lobTargetNY = max(-0.05, min(0.52, lobTargetNY))
            } else {
                lobTargetNY = max(0.48, min(1.05, lobTargetNY))
            }

            // High arc: beginners don't lob high enough, experts lob perfectly
            let lobArc = 0.50 + lobSkill * 0.30 + CGFloat.random(in: -0.08...0.08)

            let spinDirection: CGFloat = Bool.random() ? 1.0 : -1.0
            let spinCurve = spinDirection * (CGFloat(stats.stat(.spin)) / 99.0) * 0.2

            return ShotResult(
                power: lobPower,
                accuracy: max(0, 1.0 - lobScatter * 5),
                spinCurve: spinCurve,
                arc: lobArc,
                targetNX: lobTargetNX,
                targetNY: lobTargetNY,
                shotType: shotType,
                topspinFactor: 0
            )
        }

        // --- Base shot (default medium behavior) ---
        var power: CGFloat
        var arc: CGFloat
        var topspinFactor: CGFloat = 0
        var targetNX: CGFloat
        var targetNY: CGFloat

        let focusStat = CGFloat(stats.stat(.focus))

        if drillType == .dinkingDrill && modes.isEmpty {
            power = 0.15 + (powerStat / 99.0) * 0.20
        } else if drillType == .baselineRally && modes.isEmpty {
            power = max(0.30, 0.15 + (powerStat / 99.0) * 0.85)
        } else {
            power = max(0.30, 0.15 + (powerStat / 99.0) * 0.85)
            let heightBonus = min(ballHeight / 0.15, 1.0) * P.heightPowerBonus
            power += heightBonus

            // Overhead smash: high ball → 2x power mode bonus, scaled by stamina
            if ballHeight >= P.smashHeightThreshold {
                let powerModeBonus = power * (powerStat / 99.0)
                power += powerModeBonus * P.smashPowerMultiplier * staminaFraction
            }
        }

        // Kitchen volley: significantly more power when near net and ball is above net height
        // Uses ballHeightAtNet (height when ball crossed the net) since the ball descends
        // between the net and the contact point — the net-crossing height reflects true advantage
        let distFromNet = abs(courtNY - 0.5)
        let effectiveHeight = max(ballHeight, ballHeightAtNet)
        if distFromNet < P.kitchenVolleyRange && effectiveHeight > P.netLogicalHeight
            && !(drillType == .dinkingDrill && modes.isEmpty) {
            let kitchenProximity = 1.0 - distFromNet / P.kitchenVolleyRange
            let excessAboveNet = effectiveHeight - P.netLogicalHeight
            let heightFraction = min(excessAboveNet / 0.15, 1.0)
            power += heightFraction * kitchenProximity * P.kitchenVolleyMaxBonus * (powerStat / 99.0)
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

        // --- Tactical placement: bias shot away from opponent ---
        if !modes.contains(.angled), let oppNX = opponentNX, placementFraction > 0 {
            if oppNX > 0.6 {
                // Opponent on right side → aim left
                let biasTarget = CGFloat.random(in: 0.15...0.35)
                targetNX = targetNX + (biasTarget - targetNX) * placementFraction
            } else if oppNX < 0.4 {
                // Opponent on left side → aim right
                let biasTarget = CGFloat.random(in: 0.65...0.85)
                targetNX = targetNX + (biasTarget - targetNX) * placementFraction
            }
        }

        // --- Base scatter from stats (always present) ---
        // Accuracy, consistency, and focus all contribute to shot control.
        // stat 1 → scatter ~0.20 (frequent misses), stat 99 → scatter ~0 (laser accurate)
        let avgControl = (accuracyStat + consistencyStat + focusStat) / 3.0
        var scatter = GameConstants.PlayerBalance.baseScatter * (1.0 - avgControl / 99.0)

        // Fatigue increases scatter: below 50% stamina, scatter grows up to 50% more
        if staminaFraction < 0.5 {
            scatter *= 1.0 + (1.0 - staminaFraction / 0.5) * 0.5
        }

        // --- Apply mode modifiers ---

        // Power mode: 2x ball speed at full stamina, scales down to regular at 0 stamina
        if modes.contains(.power) {
            let regularPower = power
            let fullPower = regularPower * (1.0 + powerStat / 99.0)
            power = regularPower + (fullPower - regularPower) * staminaFraction
            // Power adds extra scatter on top of base
            let powerScatter = 0.06 * (1.0 - accuracyStat / 99.0)
            scatter += powerScatter
            targetNY = CGFloat.random(in: 0.80...0.92)
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

        // Angled: target sidelines — slightly inside the lines so shots are reachable
        if modes.contains(.angled) {
            if ballApproachFromLeft {
                targetNX = 0.82
            } else {
                targetNX = 0.18
            }
        }

        // Focus mode: reduces scatter, scaled by stamina
        if modes.contains(.focus) {
            let focusReduction = 0.7 * staminaFraction
            scatter *= (1.0 - focusReduction)
        }

        // Smash put-away: 2x power when ball is high enough for a smash and touch is off
        // Touch mode converts smashes/volleys into soft drops toward kitchen instead
        if ballHeight >= P.smashHeightThreshold && !modes.contains(.touch) {
            power *= 2.0
        }

        power = max(0.15, min(2.5, power))

        // Far-side shooters: mirror target to opponent's court half
        if shootingFromFarSide {
            targetNY = 1.0 - targetNY
        }

        // --- Physics-based arc calculation ---
        let distToTargetNY = abs(targetNY - courtNY)
        let distToTargetNX = abs(targetNX - courtNX)

        if drillType == .dinkingDrill && modes.isEmpty {
            arc = CGFloat.random(in: 0.5...0.7)
        } else {
            // Arc margins reduced after fixing arcToLandAt travel time calculation.
            // ensureNetClearance() in launch() handles net clearance as a safety net.
            var margin: CGFloat = 1.0
            if modes.contains(.topspin) {
                margin = 1.25  // topspin pulls ball down — needs extra arc
            } else if modes.contains(.slice) {
                margin = 0.90  // slice floats — less arc needed
            }
            arc = arcToLandAt(distanceNY: distToTargetNY, distanceNX: distToTargetNX, power: power, arcMargin: margin)

            // Overhead smash: steeper descent → higher bounce on opponent's side
            if ballHeight >= P.smashHeightThreshold {
                arc += P.smashArcBonus
            }
        }

        // Apply scatter — allow targets outside court for genuine misses
        let scatterX = CGFloat.random(in: -scatter...scatter)
        let scatterY = CGFloat.random(in: -scatter...scatter)

        // Spin
        let spinDirection: CGFloat = Bool.random() ? 1.0 : -1.0
        let spinCurve = spinDirection * (spinStat / 99.0)

        // Soft clamp: allow targets slightly past court edges for out balls
        targetNX = max(-0.05, min(1.05, targetNX + scatterX))
        if shootingFromFarSide {
            targetNY = max(-0.05, min(0.52, targetNY + scatterY))
        } else {
            targetNY = max(0.48, min(1.05, targetNY + scatterY))
        }

        // Smash factor: scales 0→1 based on how far above smash threshold
        let smashFactor: CGFloat = ballHeight >= P.smashHeightThreshold
            ? min(1.0, (ballHeight - P.smashHeightThreshold) / 0.10)
            : 0

        return ShotResult(
            power: power,
            accuracy: max(0, 1.0 - scatter * 5),
            spinCurve: spinCurve,
            arc: arc,
            targetNX: targetNX,
            targetNY: targetNY,
            shotType: shotType,
            topspinFactor: topspinFactor,
            smashFactor: smashFactor
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
