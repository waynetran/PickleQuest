import Testing
@testable import PickleQuest

@Suite("PlayerController Lunge")
struct PlayerControllerLungeTests {
    private typealias P = GameConstants.DrillPhysics

    @MainActor private func makeController(lungeEnabled: Bool = true) -> InteractivePlayerController {
        let stats = PlayerStats(
            power: 50, accuracy: 50, spin: 50, speed: 50,
            defense: 50, reflexes: 50, positioning: 50,
            clutch: 50, focus: 50, stamina: 50, consistency: 50
        )
        return InteractivePlayerController(
            playerStats: stats, appearance: .defaultPlayer,
            startNX: 0.5, startNY: 0.1,
            config: PlayerControllerConfig(lungeEnabled: lungeEnabled)
        )
    }

    @Test("Lunge completes full cycle: loading → jumping → landing → none")
    @MainActor func lungeCompletesFullCycle() {
        let ctrl = makeController()
        ctrl.isPlayable = true
        ctrl._testStartLunge(direction: 1.0)

        #expect(ctrl.lungePhase == .loading)

        // Advance through loading (0.08s → ~5 frames)
        for _ in 0..<6 { ctrl.movePlayer(dt: 1.0 / 60.0) }
        #expect(ctrl.lungePhase == .jumping, "Should transition to jumping after loading")

        // Advance through jumping (0.18s → ~11 frames)
        for _ in 0..<8 { ctrl.movePlayer(dt: 1.0 / 60.0) }
        #expect(ctrl.lungePhase == .jumping, "Should still be jumping mid-way")
        for _ in 0..<4 { ctrl.movePlayer(dt: 1.0 / 60.0) }
        #expect(ctrl.lungePhase == .landing, "Should transition to landing after jumping")

        // Advance through landing (0.08s → ~5 frames)
        for _ in 0..<6 { ctrl.movePlayer(dt: 1.0 / 60.0) }
        #expect(ctrl.lungePhase == .none, "Lunge should complete")
    }

    @Test("Lunge moves player laterally")
    @MainActor func lungeMovesSideways() {
        let ctrl = makeController()
        ctrl.isPlayable = true
        let startNX = ctrl.playerNX
        ctrl._testStartLunge(direction: 1.0)

        // Run through loading + jumping
        for _ in 0..<20 { ctrl.movePlayer(dt: 1.0 / 60.0) }
        #expect(ctrl.playerNX > startNX, "Lunge should move player to the right")
    }

    @Test("Lunge stops at ball X to prevent overshoot")
    @MainActor func lungeStopsAtBallX() {
        let ctrl = makeController(lungeEnabled: true)
        ctrl.isPlayable = true
        ctrl.isBallActive = true
        ctrl.currentBallX = 0.55  // ball slightly to the right

        ctrl._testStartLunge(direction: 1.0)
        // Run through loading + jumping
        for _ in 0..<30 { ctrl.movePlayer(dt: 1.0 / 60.0) }

        #expect(ctrl.playerNX <= 0.55 + 0.01,
                "Lunge should stop near ball X, not overshoot significantly")
    }

    @Test("Low stamina reduces lunge distance")
    @MainActor func lowStaminaReducesLungeDistance() {
        // Full stamina lunge
        let ctrl1 = makeController()
        ctrl1.isPlayable = true
        ctrl1.stamina = P.maxStamina
        ctrl1._testStartLunge(direction: 1.0)
        for _ in 0..<30 { ctrl1.movePlayer(dt: 1.0 / 60.0) }
        let fullStaminaDist = ctrl1.playerNX - 0.5

        // Very low stamina lunge (< 10% → 1/3 distance)
        let ctrl2 = makeController()
        ctrl2.isPlayable = true
        ctrl2.stamina = P.maxStamina * 0.05  // 5%
        ctrl2._testStartLunge(direction: 1.0)
        for _ in 0..<30 { ctrl2.movePlayer(dt: 1.0 / 60.0) }
        let lowStaminaDist = ctrl2.playerNX - 0.5

        #expect(lowStaminaDist < fullStaminaDist,
                "Low stamina lunge should cover less distance")
    }

    @Test("Lunge not allowed when disabled")
    @MainActor func lungeDisabled() {
        let ctrl = makeController(lungeEnabled: false)
        ctrl.isPlayable = true
        ctrl._testStartLunge(direction: 1.0)
        #expect(ctrl.lungePhase == .none, "Lunge should not start when disabled")
    }

    @Test("Lunge not allowed during jump")
    @MainActor func lungeNotDuringJump() {
        let ctrl = makeController()
        ctrl.isPlayable = true
        ctrl.initiateJump()
        #expect(ctrl.jumpPhase == .rising)
        ctrl._testStartLunge(direction: 1.0)
        #expect(ctrl.lungePhase == .none, "Lunge should not start during a jump")
    }
}
