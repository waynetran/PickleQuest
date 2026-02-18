import Foundation
import CoreGraphics

/// Heavy debug logger for interactive matches. Logs detailed shot-by-shot info to console.
/// Enable via `isDevMode` on InteractiveMatchScene.
@MainActor
final class MatchDebugLogger {
    static let shared = MatchDebugLogger()

    var isEnabled = false

    // Point-level tracking
    private var pointNumber = 0
    private var shotInPoint = 0

    private let tag = "[MATCH]"

    // MARK: - Match Start

    func logMatchStart(
        player: Player,
        playerStats: PlayerStats,
        npc: NPC,
        npcStatBoost: Int
    ) {
        guard isEnabled else { return }
        let p = playerStats
        let n = npc.stats
        let boost = npcStatBoost

        print("""
        \(tag) ═══════════════════════════════════════════════
        \(tag) MATCH START: \(player.name) vs \(npc.name)
        \(tag) ═══════════════════════════════════════════════
        \(tag) Player DUPR: \(String(format: "%.2f", player.duprRating))
        \(tag) NPC DUPR:    \(String(format: "%.2f", npc.duprRating)) (\(npc.difficulty.rawValue), \(npc.personality.rawValue))
        \(tag) NPC stat boost: +\(boost)
        \(tag) ───────────────────────────────────────────────
        \(tag) PLAYER STATS (used in match):
        \(tag)   pow=\(p.power) acc=\(p.accuracy) spn=\(p.spin) spd=\(p.speed)
        \(tag)   def=\(p.defense) ref=\(p.reflexes) pos=\(p.positioning) clu=\(p.clutch)
        \(tag)   foc=\(p.focus) sta=\(p.stamina) con=\(p.consistency)
        \(tag) NPC STATS (raw → boosted):
        \(tag)   pow=\(n.power)→\(min(99,n.power+boost)) acc=\(n.accuracy)→\(min(99,n.accuracy+boost)) spn=\(n.spin)→\(min(99,n.spin+boost)) spd=\(n.speed)→\(min(99,n.speed+boost))
        \(tag)   def=\(n.defense)→\(min(99,n.defense+boost)) ref=\(n.reflexes)→\(min(99,n.reflexes+boost)) pos=\(n.positioning)→\(min(99,n.positioning+boost)) clu=\(n.clutch)→\(min(99,n.clutch+boost))
        \(tag)   foc=\(n.focus)→\(min(99,n.focus+boost)) sta=\(n.stamina)→\(min(99,n.stamina+boost)) con=\(n.consistency)→\(min(99,n.consistency+boost))
        \(tag) ───────────────────────────────────────────────
        \(tag) PLAYER EQUIPPED ITEM IDs:
        """)

        // Log equipped item IDs (we don't have the inventory objects here,
        // but the stats above already include equipment bonuses via StatCalculator)
        if player.equippedItems.isEmpty {
            print("\(tag)   (none)")
        } else {
            for (slot, itemID) in player.equippedItems.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                print("\(tag)   [\(slot.rawValue)] \(itemID.uuidString.prefix(8))...")
            }
        }

        // Compute derived values used in match
        let speedStat = CGFloat(p.stat(.speed))
        let moveSpeed = GameConstants.DrillPhysics.baseMoveSpeed + (speedStat / 99.0) * GameConstants.DrillPhysics.maxMoveSpeedBonus
        let positioningStat = CGFloat(p.stat(.positioning))
        let hitbox = GameConstants.DrillPhysics.baseHitboxRadius + (positioningStat / 99.0) * GameConstants.DrillPhysics.positioningHitboxBonus
        let reflexes = CGFloat(p.stat(.reflexes))
        let athleticism = (speedStat + reflexes) / 2.0 / 99.0
        let heightReach = GameConstants.DrillPhysics.baseHeightReach + athleticism * GameConstants.DrillPhysics.maxHeightReachBonus

        print("""
        \(tag) DERIVED VALUES:
        \(tag)   moveSpeed=\(String(format: "%.3f", moveSpeed)) hitbox=\(String(format: "%.3f", hitbox)) heightReach=\(String(format: "%.3f", heightReach))
        \(tag) ═══════════════════════════════════════════════
        """)
        pointNumber = 0
    }

    // MARK: - Point Start

    func logPointStart(
        pointNum: Int,
        servingSide: MatchSide,
        playerScore: Int,
        npcScore: Int,
        playerNX: CGFloat,
        playerNY: CGFloat,
        playerStamina: CGFloat,
        npcNX: CGFloat,
        npcNY: CGFloat,
        npcStamina: CGFloat
    ) {
        guard isEnabled else { return }
        pointNumber = pointNum
        shotInPoint = 0
        let server = servingSide == .player ? "PLAYER" : "NPC"
        print("""
        \(tag) ──── POINT #\(pointNum) ────  Score: \(playerScore)-\(npcScore)  Server: \(server)
        \(tag)   Player pos=(\(f(playerNX)), \(f(playerNY))) stamina=\(f(playerStamina))
        \(tag)   NPC    pos=(\(f(npcNX)), \(f(npcNY))) stamina=\(f(npcStamina))
        """)
    }

    // MARK: - Serve

    func logPlayerServe(
        originNX: CGFloat, originNY: CGFloat,
        targetNX: CGFloat, targetNY: CGFloat,
        power: CGFloat, arc: CGFloat,
        scatter: CGFloat, modes: DrillShotCalculator.ShotMode,
        stamina: CGFloat
    ) {
        guard isEnabled else { return }
        shotInPoint += 1
        print("""
        \(tag)   [SERVE] Player #\(shotInPoint)  stamina=\(f(stamina))
        \(tag)     from=(\(f(originNX)),\(f(originNY))) → target=(\(f(targetNX)),\(f(targetNY)))
        \(tag)     power=\(f(power)) arc=\(f(arc)) scatter=\(f(scatter)) modes=\(modesStr(modes))
        """)
    }

    func logNPCServe(
        originNX: CGFloat, originNY: CGFloat,
        targetNX: CGFloat, targetNY: CGFloat,
        power: CGFloat, arc: CGFloat,
        faultRate: CGFloat, isDoubleFault: Bool,
        modes: DrillShotCalculator.ShotMode,
        stamina: CGFloat
    ) {
        guard isEnabled else { return }
        shotInPoint += 1
        let fault = isDoubleFault ? " *** DOUBLE FAULT ***" : ""
        print("""
        \(tag)   [SERVE] NPC #\(shotInPoint)  stamina=\(f(stamina))\(fault)
        \(tag)     from=(\(f(originNX)),\(f(originNY))) → target=(\(f(targetNX)),\(f(targetNY)))
        \(tag)     power=\(f(power)) arc=\(f(arc)) faultRate=\(f(faultRate)) modes=\(modesStr(modes))
        """)
    }

    // MARK: - Ball Approaching Player

    func logBallApproachingPlayer(
        ballX: CGFloat, ballY: CGFloat, ballHeight: CGFloat,
        ballVX: CGFloat, ballVY: CGFloat, ballVZ: CGFloat,
        ballSpeed: CGFloat, ballSpin: CGFloat, ballTopspin: CGFloat,
        bounceCount: Int,
        playerNX: CGFloat, playerNY: CGFloat,
        hitboxRadius: CGFloat,
        dist2D: CGFloat,
        dist3D: CGFloat,
        heightReach: CGFloat,
        excessHeight: CGFloat,
        isInHitbox: Bool
    ) {
        guard isEnabled else { return }
        let status = isInHitbox ? "IN HITBOX" : "outside"
        print("""
        \(tag)   [BALL→PLAYER] \(status)
        \(tag)     ball=(\(f(ballX)),\(f(ballY))) h=\(f3(ballHeight)) v=(\(f(ballVX)),\(f(ballVY)),\(f3(ballVZ)))
        \(tag)     speed=\(f(ballSpeed)) spin=\(f(ballSpin)) topspin=\(f(ballTopspin)) bounces=\(bounceCount)
        \(tag)     player=(\(f(playerNX)),\(f(playerNY))) hitbox=\(f(hitboxRadius))
        \(tag)     dist2D=\(f3(dist2D)) dist3D=\(f3(dist3D)) heightReach=\(f3(heightReach)) excessH=\(f3(excessHeight))
        """)
    }

    // MARK: - Player Whiff (Forced Error)

    func logPlayerWhiff(
        shotDifficulty: CGFloat,
        speedFrac: CGFloat,
        spinPressure: CGFloat,
        stretchFrac: CGFloat,
        stretchMultiplier: CGFloat,
        forcedErrorRate: CGFloat,
        avgDefense: CGFloat,
        rallyPressure: CGFloat,
        pressureThreshold: CGFloat,
        pressureOverflow: CGFloat,
        duprGapAmplifier: CGFloat,
        ballSpeed: CGFloat,
        ballSpin: CGFloat,
        ballHeight: CGFloat,
        dist: CGFloat,
        hitboxRadius: CGFloat,
        roll: CGFloat
    ) {
        guard isEnabled else { return }
        print("""
        \(tag)   *** PLAYER WHIFF ***  (roll \(f3(roll)) < rate \(f3(forcedErrorRate)))
        \(tag)     shotDifficulty=\(f3(shotDifficulty)):
        \(tag)       speedFrac=\(f3(speedFrac)) × stretchMult=\(f3(stretchMultiplier)) (stretch=\(f3(stretchFrac)))
        \(tag)       spinPressure=\(f3(spinPressure))
        \(tag)     avgDefense=\(f3(avgDefense))
        \(tag)     rallyPressure=\(f3(rallyPressure)) threshold=\(f3(pressureThreshold)) overflow=\(f3(pressureOverflow))
        \(tag)     duprGapAmplifier=\(f3(duprGapAmplifier))
        \(tag)     ball: speed=\(f(ballSpeed)) spin=\(f(ballSpin)) height=\(f3(ballHeight))
        \(tag)     dist=\(f3(dist)) hitbox=\(f3(hitboxRadius))
        """)
    }

    /// Log when player successfully returns (no whiff).
    func logPlayerHit(
        shotDifficulty: CGFloat,
        forcedErrorRate: CGFloat,
        roll: CGFloat,
        modes: DrillShotCalculator.ShotMode,
        stamina: CGFloat,
        targetNX: CGFloat,
        targetNY: CGFloat,
        power: CGFloat,
        arc: CGFloat,
        spinCurve: CGFloat,
        topspinFactor: CGFloat,
        netFaultRate: CGFloat,
        isNetFault: Bool
    ) {
        guard isEnabled else { return }
        shotInPoint += 1
        let netStr = isNetFault ? " *** NET FAULT ***" : ""
        print("""
        \(tag)   [HIT] Player #\(shotInPoint) stamina=\(f(stamina)) modes=\(modesStr(modes))\(netStr)
        \(tag)     whiffRate=\(f3(forcedErrorRate)) roll=\(f3(roll)) → survived
        \(tag)     target=(\(f(targetNX)),\(f(targetNY))) pow=\(f(power)) arc=\(f(arc))
        \(tag)     spin=\(f(spinCurve)) topspin=\(f(topspinFactor)) netFaultRate=\(f3(netFaultRate))
        """)
    }

    // MARK: - Ball Approaching NPC

    func logBallApproachingNPC(
        ballX: CGFloat, ballY: CGFloat, ballHeight: CGFloat,
        ballVX: CGFloat, ballVY: CGFloat, ballVZ: CGFloat,
        ballSpeed: CGFloat, ballSpin: CGFloat, ballTopspin: CGFloat,
        bounceCount: Int,
        npcNX: CGFloat, npcNY: CGFloat,
        hitboxRadius: CGFloat,
        dist: CGFloat,
        heightReach: CGFloat,
        excessHeight: CGFloat,
        isInHitbox: Bool
    ) {
        guard isEnabled else { return }
        let status = isInHitbox ? "IN HITBOX" : "outside"
        print("""
        \(tag)   [BALL→NPC] \(status)
        \(tag)     ball=(\(f(ballX)),\(f(ballY))) h=\(f3(ballHeight)) v=(\(f(ballVX)),\(f(ballVY)),\(f3(ballVZ)))
        \(tag)     speed=\(f(ballSpeed)) spin=\(f(ballSpin)) topspin=\(f(ballTopspin)) bounces=\(bounceCount)
        \(tag)     npc=(\(f(npcNX)),\(f(npcNY))) hitbox=\(f(hitboxRadius))
        \(tag)     dist=\(f3(dist)) heightReach=\(f3(heightReach)) excessH=\(f3(excessHeight))
        """)
    }

    // MARK: - NPC Whiff (Unforced Error)

    func logNPCError(
        errorRate: CGFloat,
        baseError: CGFloat,
        pressureError: CGFloat,
        shotDifficulty: CGFloat,
        speedFrac: CGFloat,
        spinPressure: CGFloat,
        stretchFrac: CGFloat,
        stretchMultiplier: CGFloat,
        staminaPct: CGFloat,
        shotQuality: CGFloat,
        duprMultiplier: CGFloat,
        errorType: NPCErrorType,
        modes: DrillShotCalculator.ShotMode
    ) {
        guard isEnabled else { return }
        let errStr: String
        switch errorType {
        case .net: errStr = "net"
        case .long: errStr = "long"
        case .wide: errStr = "wide"
        }
        print("""
        \(tag)   *** NPC ERROR *** type=\(errStr) modes=\(modesStr(modes))
        \(tag)     errorRate=\(f3(errorRate)) base=\(f3(baseError)) pressure=\(f3(pressureError))
        \(tag)     shotDifficulty=\(f3(shotDifficulty)):
        \(tag)       speedFrac=\(f3(speedFrac)) × stretchMult=\(f3(stretchMultiplier)) (stretch=\(f3(stretchFrac)))
        \(tag)       spinPressure=\(f3(spinPressure))
        \(tag)     staminaPct=\(f3(staminaPct)) shotQuality=\(f3(shotQuality)) duprMult=\(f3(duprMultiplier))
        """)
    }

    func logNPCHit(
        modes: DrillShotCalculator.ShotMode,
        stamina: CGFloat,
        targetNX: CGFloat,
        targetNY: CGFloat,
        power: CGFloat,
        arc: CGFloat,
        spinCurve: CGFloat,
        topspinFactor: CGFloat,
        errorRate: CGFloat
    ) {
        guard isEnabled else { return }
        shotInPoint += 1
        print("""
        \(tag)   [HIT] NPC #\(shotInPoint)  stamina=\(f(stamina)) modes=\(modesStr(modes))
        \(tag)     errorRate=\(f3(errorRate)) → survived
        \(tag)     target=(\(f(targetNX)),\(f(targetNY))) pow=\(f(power)) arc=\(f(arc))
        \(tag)     spin=\(f(spinCurve)) topspin=\(f(topspinFactor))
        """)
    }

    // MARK: - Ball State Events

    func logBallBounce(
        bounceNum: Int,
        courtX: CGFloat, courtY: CGFloat,
        isOut: Bool, isKitchenFault: Bool
    ) {
        guard isEnabled else { return }
        var flags = ""
        if isOut { flags += " OUT" }
        if isKitchenFault { flags += " KITCHEN_FAULT" }
        print("\(tag)   [BOUNCE] #\(bounceNum) at (\(f3(courtX)),\(f3(courtY)))\(flags)")
    }

    func logNetCollision(
        ballHeight: CGFloat, previousBallNY: CGFloat, currentBallNY: CGFloat,
        lastHitByPlayer: Bool
    ) {
        guard isEnabled else { return }
        let hitter = lastHitByPlayer ? "Player" : "NPC"
        print("\(tag)   [NET] collision — hit by \(hitter), h=\(f3(ballHeight)) prevY=\(f(previousBallNY)) currY=\(f(currentBallNY))")
    }

    func logDoubleBounce(
        courtY: CGFloat, lastHitByPlayer: Bool, bounceCount: Int
    ) {
        guard isEnabled else { return }
        let side = courtY < 0.5 ? "player" : "NPC"
        let hitter = lastHitByPlayer ? "Player" : "NPC"
        print("\(tag)   [DOUBLE_BOUNCE] on \(side) side, lastHit=\(hitter), bounces=\(bounceCount)")
    }

    func logPointEnd(
        result: String,
        reason: String,
        rallyLength: Int
    ) {
        guard isEnabled else { return }
        print("\(tag)   ──── POINT OVER: \(result) — \(reason) (rally=\(rallyLength)) ────")
    }

    // MARK: - Ball at Player's Y

    /// Log when ball crosses the player's Y coordinate (key moment for understanding misses).
    func logBallAtPlayerY(
        ballX: CGFloat, ballY: CGFloat, ballHeight: CGFloat,
        playerNX: CGFloat, playerNY: CGFloat,
        xDistance: CGFloat,
        hitboxRadius: CGFloat,
        wouldBeInHitbox: Bool,
        bounceCount: Int
    ) {
        guard isEnabled else { return }
        let status = wouldBeInHitbox ? "REACHABLE" : "TOO FAR"
        print("""
        \(tag)   [BALL@PLAYER_Y] \(status)
        \(tag)     ball=(\(f(ballX)),\(f(ballY))) h=\(f3(ballHeight)) bounces=\(bounceCount)
        \(tag)     player=(\(f(playerNX)),\(f(playerNY)))
        \(tag)     xDist=\(f3(xDistance)) hitbox=\(f3(hitboxRadius))
        """)
    }

    // MARK: - Helpers

    private func f(_ v: CGFloat) -> String { String(format: "%.2f", v) }
    private func f3(_ v: CGFloat) -> String { String(format: "%.3f", v) }

    private func modesStr(_ modes: DrillShotCalculator.ShotMode) -> String {
        var parts: [String] = []
        if modes.contains(.power) { parts.append("PWR") }
        if modes.contains(.reset) { parts.append("RST") }
        if modes.contains(.slice) { parts.append("SLC") }
        if modes.contains(.topspin) { parts.append("TOP") }
        if modes.contains(.angled) { parts.append("ANG") }
        if modes.contains(.focus) { parts.append("FOC") }
        return parts.isEmpty ? "none" : parts.joined(separator: "|")
    }
}
