import Testing
import CoreGraphics
@testable import PickleQuest

@Suite("PlayerController Hitbox")
struct PlayerControllerHitboxTests {
    private typealias P = GameConstants.DrillPhysics

    @MainActor private func makeController(
        positioning: Int = 50,
        speed: Int = 50,
        reflexes: Int = 50,
        startNX: CGFloat = 0.5,
        startNY: CGFloat = 0.1
    ) -> InteractivePlayerController {
        let stats = PlayerStats(
            power: 50, accuracy: 50, spin: 50, speed: speed,
            defense: 50, reflexes: reflexes, positioning: positioning,
            clutch: 50, focus: 50, stamina: 50, consistency: 50
        )
        return InteractivePlayerController(
            playerStats: stats, appearance: .defaultPlayer,
            startNX: startNX, startNY: startNY
        )
    }

    @Test("Swept collision detects fast ball crossing player")
    @MainActor func sweptCollisionDetectsTraversal() {
        let ctrl = makeController(startNX: 0.5, startNY: 0.2)
        // Ball segment crosses through player: prev far left, curr far right
        ctrl.storeBallPosition(courtX: 0.3, courtY: 0.2, height: 0.0)
        let dist = ctrl.checkHitDistance(ballX: 0.7, ballY: 0.2, ballHeight: 0.0)
        #expect(dist < 0.01, "Swept collision should detect ball passing through player position")
    }

    @Test("Ball near player returns small distance")
    @MainActor func nearBallSmallDistance() {
        let ctrl = makeController(startNX: 0.5, startNY: 0.2)
        ctrl.storeBallPosition(courtX: 0.51, courtY: 0.2, height: 0.0)
        let dist = ctrl.checkHitDistance(ballX: 0.52, ballY: 0.2, ballHeight: 0.0)
        #expect(dist < 0.05, "Ball near player should have small distance")
    }

    @Test("Hitbox radius scales with positioning stat")
    @MainActor func hitboxScalesWithPositioning() {
        let lowPos = makeController(positioning: 10)
        let highPos = makeController(positioning: 90)
        #expect(highPos.hitboxRadius > lowPos.hitboxRadius,
                "Higher positioning stat should give larger hitbox")
    }

    @Test("High ball out of reach returns larger distance")
    @MainActor func highBallOutOfReach() {
        let ctrl = makeController(startNX: 0.5, startNY: 0.2)
        ctrl.storeBallPosition(courtX: 0.5, courtY: 0.2, height: 1.0)
        let dist = ctrl.checkHitDistance(ballX: 0.5, ballY: 0.2, ballHeight: 1.0)
        // Ball directly above but very high — excess height adds to distance
        #expect(dist > 0.5, "Very high ball should be out of reach")
    }

    @Test("Jump bonus increases effective height reach")
    @MainActor func jumpBonusIncreasesReach() {
        let ctrl = makeController(startNX: 0.5, startNY: 0.2)
        let highBall: CGFloat = ctrl.heightReach + 0.1  // just above base reach

        ctrl.storeBallPosition(courtX: 0.5, courtY: 0.2, height: highBall)
        let distNoJump = ctrl.checkHitDistance(ballX: 0.5, ballY: 0.2, ballHeight: highBall)

        // Simulate jump at peak
        ctrl.jumpHeightBonus = P.jumpHeightReachBonus
        ctrl.storeBallPosition(courtX: 0.5, courtY: 0.2, height: highBall)
        let distWithJump = ctrl.checkHitDistance(ballX: 0.5, ballY: 0.2, ballHeight: highBall)

        #expect(distWithJump < distNoJump, "Jump should reduce distance to high ball")
    }
}
