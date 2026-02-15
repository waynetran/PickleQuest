import Foundation

enum MatchEvent: Sendable {
    case matchStart(playerName: String, opponentName: String)
    case gameStart(gameNumber: Int)
    case pointPlayed(MatchPoint)
    case streakAlert(side: MatchSide, count: Int)
    case fatigueWarning(side: MatchSide, energyPercent: Double)
    case abilityTriggered(side: MatchSide, abilityName: String, effectDescription: String)
    case gameEnd(gameNumber: Int, winnerSide: MatchSide, score: MatchScore)
    case timeoutCalled(side: MatchSide, energyRestored: Double, streakBroken: Bool)
    case consumableUsed(side: MatchSide, name: String, effect: String)
    case hookCallAttempt(side: MatchSide, success: Bool, repChange: Int)
    case resigned
    case matchEnd(result: MatchResult)

    var narration: String {
        switch self {
        case .matchStart(let player, let opponent):
            return "\(player) vs \(opponent) — Match begins!"
        case .gameStart(let num):
            return "Game \(num) starting!"
        case .pointPlayed(let point):
            let winner = point.winnerSide == .player ? "You" : "Opponent"
            let score = "\(point.scoreAfter.playerPoints)-\(point.scoreAfter.opponentPoints)"
            switch point.pointType {
            case .ace:
                return "\(winner) serves an ace! (\(score))"
            case .winner:
                return "\(winner) hits a clean winner after \(point.rallyLength) shots! (\(score))"
            case .unforcedError:
                let loser = point.winnerSide == .player ? "Opponent" : "You"
                return "\(loser) commits an unforced error. \(winner) takes the point. (\(score))"
            case .forcedError:
                return "\(winner) forces an error after \(point.rallyLength) shots! (\(score))"
            case .rally:
                return "\(winner) wins a \(point.rallyLength)-shot rally! (\(score))"
            }
        case .streakAlert(let side, let count):
            let who = side == .player ? "You're" : "Opponent is"
            return "\(who) on a \(count)-point streak!"
        case .fatigueWarning(let side, let pct):
            let who = side == .player ? "You're" : "Opponent is"
            return "\(who) getting tired (\(Int(pct))% energy)"
        case .abilityTriggered(let side, let name, let effect):
            let who = side == .player ? "Your" : "Opponent's"
            return "\(who) \(name) activates! \(effect)"
        case .gameEnd(let num, let winner, let score):
            let who = winner == .player ? "You win" : "Opponent wins"
            return "\(who) Game \(num)! (Games: \(score.playerGames)-\(score.opponentGames))"
        case .timeoutCalled(let side, let energyRestored, let streakBroken):
            let who = side == .player ? "You call" : "Opponent calls"
            let streakText = streakBroken ? " Streak broken!" : ""
            return "\(who) a timeout! (+\(Int(energyRestored))% energy)\(streakText)"
        case .consumableUsed(let side, let name, let effect):
            let who = side == .player ? "You use" : "Opponent uses"
            return "\(who) \(name)! \(effect)"
        case .hookCallAttempt(let side, let success, let repChange):
            let who = side == .player ? "You" : "Opponent"
            if success {
                return "\(who) challenged the line call and won! (\(repChange) rep)"
            } else {
                return "\(who) challenged the line call and got caught! (\(repChange) rep)"
            }
        case .resigned:
            return "Match resigned."
        case .matchEnd(let result):
            let who = result.didPlayerWin ? "Victory!" : "Defeat!"
            return "\(who) Final: \(result.formattedScore)"
        }
    }
}
