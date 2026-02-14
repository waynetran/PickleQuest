import Foundation

enum MatchEvent: Sendable {
    case matchStart(playerName: String, opponentName: String)
    case gameStart(gameNumber: Int)
    case pointPlayed(MatchPoint)
    case streakAlert(side: MatchSide, count: Int)
    case fatigueWarning(side: MatchSide, energyPercent: Double)
    case abilityTriggered(side: MatchSide, abilityName: String, effectDescription: String)
    case gameEnd(gameNumber: Int, winnerSide: MatchSide, score: MatchScore)
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
        case .matchEnd(let result):
            let who = result.didPlayerWin ? "Victory!" : "Defeat!"
            return "\(who) Final: \(result.formattedScore)"
        }
    }
}
