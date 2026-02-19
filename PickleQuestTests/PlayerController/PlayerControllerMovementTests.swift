import Testing
import CoreGraphics
@testable import PickleQuest

@Suite("PlayerController Movement")
struct PlayerControllerMovementTests {
    private typealias P = GameConstants.DrillPhysics

    @MainActor private func makeController(
        startNX: CGFloat = 0.5,
        startNY: CGFloat = 0.1,
        config: PlayerControllerConfig = PlayerControllerConfig()
    ) -> InteractivePlayerController {
        let stats = PlayerStats(
            power: 50, accuracy: 50, spin: 50, speed: 50,
            defense: 50, reflexes: 50, positioning: 50,
            clutch: 50, focus: 50, stamina: 50, consistency: 50
        )
        return InteractivePlayerController(
            playerStats: stats, appearance: .defaultPlayer,
            startNX: startNX, startNY: startNY, config: config
        )
    }

    @Test("Joystick moves player position")
    @MainActor func joystickMovesPlayer() {
        let ctrl = makeController()
        ctrl._testSetJoystickInput(direction: CGVector(dx: 1, dy: 0), magnitude: 0.5)
        let startX = ctrl.playerNX
        ctrl.movePlayer(dt: 1.0 / 60.0)
        #expect(ctrl.playerNX > startX, "Player should move right")
    }

    @Test("Sprint drains stamina")
    @MainActor func sprintDrainsStamina() {
        let ctrl = makeController()
        let startStamina = ctrl.stamina
        // magnitude > 0.6 triggers sprint
        ctrl._testSetJoystickInput(direction: CGVector(dx: 1, dy: 0), magnitude: 0.8)
        for _ in 0..<60 {
            ctrl.movePlayer(dt: 1.0 / 60.0)
        }
        #expect(ctrl.stamina < startStamina, "Stamina should drain while sprinting")
    }

    @Test("Idle recovers stamina after delay")
    @MainActor func idleRecoversStamina() {
        let ctrl = makeController()
        // Drain some stamina first
        ctrl.stamina = 50
        ctrl.timeSinceLastSprint = P.staminaRecoveryDelay + 0.1
        ctrl._testSetJoystickInput(direction: .zero, magnitude: 0)
        let before = ctrl.stamina
        ctrl.movePlayer(dt: 1.0)
        #expect(ctrl.stamina > before, "Stamina should recover when idle past delay")
    }

    @Test("Position clamped to config bounds")
    @MainActor func positionClamped() {
        let config = PlayerControllerConfig(
            minNX: 0.1, maxNX: 0.9,
            minNY: 0.0, maxNY: 0.4
        )
        let ctrl = makeController(startNX: 0.5, startNY: 0.3, config: config)
        // Push hard right
        ctrl._testSetJoystickInput(direction: CGVector(dx: 1, dy: 0), magnitude: 1.0)
        for _ in 0..<600 { ctrl.movePlayer(dt: 1.0 / 60.0) }
        #expect(ctrl.playerNX <= config.maxNX, "Player X should be clamped to maxNX")
        #expect(ctrl.playerNX >= config.minNX, "Player X should be clamped to minNX")
    }

    @Test("Low stamina reduces sprint effectiveness")
    @MainActor func lowStaminaReducedSpeed() {
        let ctrl = makeController()
        ctrl.stamina = P.maxStamina * 0.3  // 30% stamina — below 50% threshold
        ctrl._testSetJoystickInput(direction: CGVector(dx: 1, dy: 0), magnitude: 0.8)
        let startX = ctrl.playerNX
        ctrl.movePlayer(dt: 1.0 / 60.0)
        let lowStaminaMovement = ctrl.playerNX - startX

        let ctrl2 = makeController()
        ctrl2.stamina = P.maxStamina  // full stamina
        ctrl2._testSetJoystickInput(direction: CGVector(dx: 1, dy: 0), magnitude: 0.8)
        let startX2 = ctrl2.playerNX
        ctrl2.movePlayer(dt: 1.0 / 60.0)
        let fullStaminaMovement = ctrl2.playerNX - startX2

        #expect(lowStaminaMovement < fullStaminaMovement, "Low stamina should move slower")
    }
}
