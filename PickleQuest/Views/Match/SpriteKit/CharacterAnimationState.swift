import Foundation

enum CharacterAnimationState: Sendable {
    case idleBack
    case idleFront
    case walkToward
    case walkAway
    case walkLeft
    case walkRight
    case ready
    case servePrep
    case serveSwing
    case forehand
    case backhand
    case runDive
    case celebrate

    var sheetRow: Int {
        switch self {
        case .idleBack:    return 0
        case .idleFront:   return 1
        case .walkToward:  return 2
        case .walkAway:    return 3
        case .walkLeft:    return 4
        case .walkRight:   return 5
        case .ready:       return 6
        case .servePrep:   return 7
        case .serveSwing:  return 8
        case .forehand:    return 9
        case .backhand:    return 10
        case .runDive:     return 11
        case .celebrate:   return 12
        }
    }

    var loops: Bool {
        switch self {
        case .idleBack, .idleFront, .walkToward, .walkAway,
             .walkLeft, .walkRight, .ready:
            return true
        case .servePrep, .serveSwing, .forehand, .backhand,
             .runDive, .celebrate:
            return false
        }
    }

    var frameDuration: TimeInterval {
        switch self {
        case .idleBack, .idleFront, .ready:
            return 0.15
        case .walkToward, .walkAway, .walkLeft, .walkRight:
            return 0.10
        case .servePrep:
            return 0.10
        case .serveSwing:
            return 0.06
        case .forehand, .backhand:
            return 0.06
        case .runDive:
            return 0.08
        case .celebrate:
            return 0.12
        }
    }

    /// Default idle state for near (back-view) vs far (front-view) player
    static func idle(isNear: Bool) -> CharacterAnimationState {
        isNear ? .idleBack : .idleFront
    }
}
