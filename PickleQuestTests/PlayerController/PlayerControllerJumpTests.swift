import Testing
@testable import PickleQuest

@Suite("PlayerController Jump")
struct PlayerControllerJumpTests {
    private typealias P = GameConstants.DrillPhysics

    @MainActor private func makeController(jumpEnabled: Bool = true) -> InteractivePlayerController {
        let stats = PlayerStats(
            power: 50, accuracy: 50, spin: 50, speed: 50,
            defense: 50, reflexes: 50, positioning: 50,
            clutch: 50, focus: 50, stamina: 50, consistency: 50
        )
        return InteractivePlayerController(
            playerStats: stats, appearance: .defaultPlayer,
            startNX: 0.5, startNY: 0.1,
            config: PlayerControllerConfig(jumpEnabled: jumpEnabled)
        )
    }

    @Test("Jump phases transition correctly: grounded → rising → hanging → falling → grounded")
    @MainActor func jumpPhasesTransition() {
        let ctrl = makeController()
        #expect(ctrl.jumpPhase == .grounded)

        ctrl.initiateJump()
        #expect(ctrl.jumpPhase == .rising)

        // Advance through rising phase
        let riseEnd = P.jumpDuration * P.jumpRiseFraction
        ctrl.updateJump(dt: riseEnd + 0.01)
        #expect(ctrl.jumpPhase == .hanging)

        // Advance through hanging phase
        let hangDuration = P.jumpDuration * P.jumpHangFraction
        ctrl.updateJump(dt: hangDuration + 0.01)
        #expect(ctrl.jumpPhase == .falling)

        // Advance through falling phase
        let fallDuration = P.jumpDuration * P.jumpFallFraction
        ctrl.updateJump(dt: fallDuration + 0.01)
        #expect(ctrl.jumpPhase == .grounded)
    }

    @Test("Jump not allowed when disabled")
    @MainActor func jumpDisabled() {
        let ctrl = makeController(jumpEnabled: false)
        ctrl.initiateJump()
        #expect(ctrl.jumpPhase == .grounded, "Jump should not start when disabled")
    }

    @Test("Jump requires minimum stamina")
    @MainActor func jumpRequiresStamina() {
        let ctrl = makeController()
        ctrl.stamina = P.jumpMinStamina - 1
        ctrl.initiateJump()
        #expect(ctrl.jumpPhase == .grounded, "Jump should not start with insufficient stamina")
    }

    @Test("Jump costs stamina")
    @MainActor func jumpCostsStamina() {
        let ctrl = makeController()
        let before = ctrl.stamina
        ctrl.initiateJump()
        #expect(ctrl.stamina < before, "Stamina should decrease after initiating jump")
        #expect(ctrl.stamina == before - P.jumpStaminaCost, "Stamina cost should match constant")
    }

    @Test("Height bonus returns to 0 after landing")
    @MainActor func heightBonusResetsAfterLanding() {
        let ctrl = makeController()
        ctrl.initiateJump()
        // Run through entire jump with small steps (state machine transitions one phase per call)
        for _ in 0..<60 { ctrl.updateJump(dt: 1.0 / 60.0) }
        #expect(ctrl.jumpPhase == .grounded)
        #expect(ctrl.jumpHeightBonus == 0, "Height bonus should be 0 after landing")
    }

    @Test("Jump cooldown prevents immediate re-jump")
    @MainActor func jumpCooldown() {
        let ctrl = makeController()
        ctrl.initiateJump()
        // Complete the jump with small steps (0.45s = ~27 frames, use 30 to be safe)
        for _ in 0..<30 { ctrl.updateJump(dt: 1.0 / 60.0) }
        #expect(ctrl.jumpPhase == .grounded)
        #expect(ctrl.jumpCooldownTimer > 0)

        // Try to jump again immediately
        ctrl.initiateJump()
        #expect(ctrl.jumpPhase == .grounded, "Should not be able to jump during cooldown")

        // Wait out cooldown (0.3s = 18 frames, use 20)
        for _ in 0..<20 { ctrl.updateJump(dt: 1.0 / 60.0) }
        ctrl.initiateJump()
        #expect(ctrl.jumpPhase == .rising, "Should be able to jump after cooldown")
    }

    @Test("Height bonus peaks during hang phase")
    @MainActor func heightBonusPeaksDuringHang() {
        let ctrl = makeController()
        ctrl.initiateJump()

        // Rise to peak
        let riseEnd = P.jumpDuration * P.jumpRiseFraction
        ctrl.updateJump(dt: riseEnd + 0.001)
        #expect(ctrl.jumpPhase == .hanging)
        #expect(ctrl.jumpHeightBonus == P.jumpHeightReachBonus,
                "Height bonus should be at max during hang phase")
    }
}
