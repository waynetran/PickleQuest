import Foundation

enum MatchAction: Sendable {
    case skip
    case resign
    case timeout
    case useConsumable(Consumable)
    case hookLineCall
}

enum MatchActionResult: Sendable {
    case skipStarted
    case resigned
    case timeoutUsed(energyRestored: Double, streakBroken: Bool)
    case timeoutUnavailable(reason: String)
    case consumableUsed(name: String, effect: String)
    case consumableUnavailable(reason: String)
    case hookCallResult(success: Bool, repChange: Int)
    case hookCallUnavailable(reason: String)
}
