import Foundation

enum CharacterAnimationState: Hashable, Sendable {
    case idleFront          // row 0 — facing camera
    case idleBack           // row 1 — back to camera
    case shuffleFront       // row 2 — front shuffle right (flip xScale for left)
    case shuffleBack        // row 3 — back shuffle right (flip xScale for left)
    case runFront           // row 4 — front run (also used for dink animation)
    case runBack            // row 5 — back run (also used for dink animation)
    case runSide            // row 6 — run right (flip xScale for left)
    case smashFront         // row 7 — front overhead smash w/ jump
    case smashBack          // row 8 — back overhead smash
    case forehandFront      // row 9 — front forehand swing
    case forehandBack       // row 10 — back forehand swing
    case backhandFront      // row 11 — front backhand swing
    case backhandBack       // row 12 — back backhand swing

    var sheetRow: Int {
        switch self {
        case .idleFront:      return 0
        case .idleBack:       return 1
        case .shuffleFront:   return 2
        case .shuffleBack:    return 3
        case .runFront:       return 4
        case .runBack:        return 5
        case .runSide:        return 6
        case .smashFront:     return 7
        case .smashBack:      return 8
        case .forehandFront:  return 9
        case .forehandBack:   return 10
        case .backhandFront:  return 11
        case .backhandBack:   return 12
        }
    }

    var loops: Bool {
        switch self {
        case .idleFront, .idleBack,
             .shuffleFront, .shuffleBack,
             .runFront, .runBack, .runSide:
            return true
        case .smashFront, .smashBack,
             .forehandFront, .forehandBack,
             .backhandFront, .backhandBack:
            return false
        }
    }

    var frameDuration: TimeInterval {
        switch self {
        case .idleFront, .idleBack:
            return 0.15
        case .shuffleFront, .shuffleBack:
            return 0.10
        case .runFront, .runBack, .runSide:
            return 0.08
        case .smashFront, .smashBack:
            return 0.06
        case .forehandFront, .forehandBack:
            return 0.06
        case .backhandFront, .backhandBack:
            return 0.06
        }
    }

    // MARK: - isNear Helpers

    /// Idle: near player (bottom) shows back, far player (top) shows front
    static func idle(isNear: Bool) -> CharacterAnimationState {
        isNear ? .idleBack : .idleFront
    }

    /// Shuffle: lateral movement for non-sprint (dinks, returns, positioning)
    static func shuffle(isNear: Bool) -> CharacterAnimationState {
        isNear ? .shuffleBack : .shuffleFront
    }

    /// Run toward/away: also used for dink push animation
    static func run(isNear: Bool) -> CharacterAnimationState {
        isNear ? .runBack : .runFront
    }

    /// Forehand swing
    static func forehand(isNear: Bool) -> CharacterAnimationState {
        isNear ? .forehandBack : .forehandFront
    }

    /// Backhand swing
    static func backhand(isNear: Bool) -> CharacterAnimationState {
        isNear ? .backhandBack : .backhandFront
    }

    /// Overhead smash (with jump)
    static func smash(isNear: Bool) -> CharacterAnimationState {
        isNear ? .smashBack : .smashFront
    }
}
