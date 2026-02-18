import CoreGraphics

final class DrillBallSimulation {
    private typealias P = GameConstants.DrillPhysics

    // Position in logical court space (0-1 normalized)
    var courtX: CGFloat = 0.5
    var courtY: CGFloat = 0.5
    var height: CGFloat = 0       // vertical above court surface

    // Velocities (court units per second)
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var vz: CGFloat = 0           // vertical velocity

    // Spin curve applied each frame
    var spinCurve: CGFloat = 0

    // Topspin/backspin factor (-1 = backspin, 0 = flat, +1 = topspin)
    var topspinFactor: CGFloat = 0

    var bounceCount: Int = 0
    var isActive: Bool = false
    var lastHitByPlayer: Bool = false
    var activeTime: CGFloat = 0
    var skipNetCorrection: Bool = false

    /// Smash factor: 0 = normal shot, 1 = full overhead smash. Amplifies bounce height.
    var smashFactor: CGFloat = 0

    // Sub-frame interpolated bounce position (exact landing spot)
    private(set) var lastBounceCourtX: CGFloat = 0.5
    private(set) var lastBounceCourtY: CGFloat = 0.5
    private(set) var didBounceThisFrame: Bool = false

    func update(dt: CGFloat) {
        guard isActive else { return }

        activeTime += dt
        didBounceThisFrame = false

        // Save pre-frame positions for sub-frame interpolation
        let prevCourtX = courtX
        let prevCourtY = courtY
        let prevHeight = height

        // Advance position
        courtX += vx * dt
        courtY += vy * dt

        // Apply spin curve (lateral drift)
        vx += spinCurve * dt

        // Apply gravity
        vz -= P.gravity * dt

        // Magnus effect: topspin pulls ball down faster, backspin holds it up
        // Topspin: extra downward acceleration (ball dips)
        // Slice: slight upward force (ball floats/hangs)
        if topspinFactor != 0 && height > 0 {
            vz -= topspinFactor * 0.6 * dt
        }

        // Update height
        height += vz * dt

        // Bounce off court surface
        if height <= 0 && vz < 0 {
            // Sub-frame interpolation: find exact fraction of frame where height crossed zero
            // prevHeight was positive, height is now negative — linear interpolate
            let heightDelta = prevHeight - height  // total drop (positive)
            if heightDelta > 0.0001 {
                let f = prevHeight / heightDelta  // fraction in [0, 1]
                lastBounceCourtX = prevCourtX + (courtX - prevCourtX) * f
                lastBounceCourtY = prevCourtY + (courtY - prevCourtY) * f
            } else {
                lastBounceCourtX = courtX
                lastBounceCourtY = courtY
            }
            didBounceThisFrame = true

            bounceCount += 1
            height = 0
            vz *= -P.bounceDamping
            vx *= P.courtFriction
            vy *= P.courtFriction

            // Smash shots bounce higher (amplify vz after damping)
            if smashFactor > 0 {
                vz *= (1.0 + smashFactor * (P.smashBounceMultiplier - 1.0))
            }

            // Topspin/backspin effects on bounce
            // Topspin: accelerates 30% after bounce, stays low (kills bounce height)
            // Slice (backspin): skids forward, stays very low after bounce
            if topspinFactor > 0 {
                // Topspin: big forward acceleration, flatten bounce
                vy *= (1.0 + topspinFactor * 0.30)
                vz *= (1.0 - topspinFactor * 0.4)  // much flatter bounce
            } else if topspinFactor < 0 {
                // Slice/backspin: skid — less forward speed lost, very low bounce
                vy *= (1.0 + topspinFactor * 0.05)  // slight slowdown
                vz *= (1.0 + topspinFactor * 0.35)  // kills bounce height (stays low)
            }

            // Kill very small bounces
            if abs(vz) < 0.05 {
                vz = 0
            }
        }
    }

    func launch(from origin: CGPoint, toward target: CGPoint, power: CGFloat, arc: CGFloat, spin: CGFloat, topspin: CGFloat = 0) {
        skipNetCorrection = false
        smashFactor = 0
        courtX = origin.x
        courtY = origin.y
        height = 0.05  // slightly above ground for visual clarity

        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let dist = sqrt(dx * dx + dy * dy)

        let speed = P.baseShotSpeed + power * (P.maxShotSpeed - P.baseShotSpeed)

        if dist > 0.001 {
            vx = (dx / dist) * speed
            vy = (dy / dist) * speed
        } else {
            vx = 0
            vy = speed
        }

        // Arc determines initial upward velocity (2.0x for visible height)
        vz = arc * speed * 2.0

        // Ensure the ball clears the net with margin
        ensureNetClearance()

        // Spin sets lateral curve
        spinCurve = spin * P.spinCurveFactor

        // Store topspin/backspin factor
        topspinFactor = topspin

        bounceCount = 0
        activeTime = 0
        isActive = true
    }

    /// Calculates whether the current trajectory clears the net at ny=0.5.
    /// If not, boosts vz to the minimum needed (with margin).
    private func ensureNetClearance() {
        guard !skipNetCorrection else { return }
        // Only relevant if the ball crosses the net
        let crossesNet = (courtY < 0.5 && vy > 0) || (courtY > 0.5 && vy < 0)
        guard crossesNet, abs(vy) > 0.001 else { return }

        // Time to reach the net line (ny = 0.5)
        let timeToNet = abs(0.5 - courtY) / abs(vy)

        // Height at the net: h(t) = h0 + vz*t - 0.5*g*t²
        let heightAtNet = height + vz * timeToNet - 0.5 * P.gravity * timeToNet * timeToNet

        // Need to clear net height plus a margin
        let clearance = P.netLogicalHeight + 0.03

        if heightAtNet < clearance {
            // Solve for minimum vz: clearance = h0 + vz_min*t - 0.5*g*t²
            // vz_min = (clearance - h0 + 0.5*g*t²) / t
            let minVZ = (clearance - height + 0.5 * P.gravity * timeToNet * timeToNet) / timeToNet
            vz = minVZ
        }
    }

    func reset() {
        courtX = 0.5
        courtY = 0.5
        height = 0
        vx = 0
        vy = 0
        vz = 0
        spinCurve = 0
        topspinFactor = 0
        bounceCount = 0
        isActive = false
        lastHitByPlayer = false
        skipNetCorrection = false
        smashFactor = 0
        activeTime = 0
        lastBounceCourtX = 0.5
        lastBounceCourtY = 0.5
        didBounceThisFrame = false
    }

    /// Convert logical position to screen position via CourtRenderer.
    @MainActor func screenPosition() -> CGPoint {
        let groundPos = CourtRenderer.courtPoint(nx: courtX, ny: courtY)
        // Convert height to screen pixels, scaled by perspective at this depth
        let scale = CourtRenderer.perspectiveScale(ny: max(0, min(1, courtY)))
        let screenHeightOffset = height * 200 * scale
        return CGPoint(x: groundPos.x, y: groundPos.y + screenHeightOffset)
    }

    /// Ground-level position for the ball shadow.
    @MainActor func shadowScreenPosition() -> CGPoint {
        CourtRenderer.courtPoint(nx: courtX, ny: courtY)
    }

    /// Whether the ball has escaped the playing area entirely (safety check during flight).
    /// Uses generous margins — actual in/out calls should use `isLandingOut` at bounce time.
    var isOutOfBounds: Bool {
        courtX < -0.5 || courtX > 1.5 || courtY < -0.5 || courtY > 1.5
    }

    /// Whether the ball's interpolated landing position is outside the court lines.
    /// Only meaningful when `didBounceThisFrame` is true.
    var isLandingOut: Bool {
        lastBounceCourtX < 0.0 || lastBounceCourtX > 1.0 ||
        lastBounceCourtY < 0.0 || lastBounceCourtY > 1.0
    }

    /// Whether the ball has double-bounced (point over).
    var isDoubleBounce: Bool {
        bounceCount >= 2
    }

    /// Whether the ball is effectively stalled (rolling on ground or timed out).
    var isStalled: Bool {
        // Ball rolling on ground with low speed after bouncing
        if bounceCount >= 1 && height <= 0.01 && vz == 0 {
            let speed = sqrt(vx * vx + vy * vy)
            if speed < 0.05 { return true }
        }
        // Safety timeout — ball active too long
        if activeTime > 5.0 { return true }
        return false
    }

    /// Whether the ball hit the net (crossed ny=0.5 while height is below net).
    func checkNetCollision(previousY: CGFloat) -> Bool {
        guard isActive else { return false }
        let crossedNet = (previousY < 0.5 && courtY >= 0.5) || (previousY > 0.5 && courtY <= 0.5)
        return crossedNet && height < P.netLogicalHeight
    }
}
