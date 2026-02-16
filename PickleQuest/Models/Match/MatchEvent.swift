import Foundation

enum MatchEvent: Sendable {
    case matchStart(playerName: String, opponentName: String, partnerName: String? = nil, opponent2Name: String? = nil)
    case gameStart(gameNumber: Int)
    case pointPlayed(MatchPoint)
    case streakAlert(side: MatchSide, count: Int)
    case fatigueWarning(side: MatchSide, energyPercent: Double)
    case abilityTriggered(side: MatchSide, abilityName: String, effectDescription: String)
    case gameEnd(gameNumber: Int, winnerSide: MatchSide, score: MatchScore)
    case timeoutCalled(side: MatchSide, energyRestored: Double, streakBroken: Bool)
    case consumableUsed(side: MatchSide, name: String, effect: String)
    case hookCallAttempt(side: MatchSide, success: Bool, repChange: Int)
    case sideOut(newServingTeam: MatchSide, serverNumber: Int)
    case resigned
    case matchEnd(result: MatchResult)

    var narration: String {
        narration(playerName: "You")
    }

    func narration(playerName: String) -> String {
        let opponentLabel = "Opponent"
        switch self {
        case .matchStart(let player, let opponent, let partner, let opponent2):
            if let partner, let opponent2 {
                return "\(player) & \(partner) vs \(opponent) & \(opponent2) — Match begins!"
            }
            return "\(player) vs \(opponent) — Match begins!"
        case .gameStart(let num):
            return "Game \(num) starting!"
        case .pointPlayed(let point):
            let winner = point.winnerSide == .player ? playerName : opponentLabel
            let score = "\(point.scoreAfter.playerPoints)-\(point.scoreAfter.opponentPoints)"
            switch point.pointType {
            case .ace:
                return "\(winner) serves an ace! (\(score))"
            case .winner:
                return "\(winner) hits a clean winner after \(point.rallyLength) shots! (\(score))"
            case .unforcedError:
                let loser = point.winnerSide == .player ? opponentLabel : playerName
                return "\(loser) commits an unforced error. \(winner) takes the point. (\(score))"
            case .forcedError:
                return "\(winner) forces an error after \(point.rallyLength) shots! (\(score))"
            case .rally:
                return "\(winner) wins a \(point.rallyLength)-shot rally! (\(score))"
            }
        case .streakAlert(let side, let count):
            let who = side == .player ? "\(playerName) is" : "\(opponentLabel) is"
            return "\(who) on a \(count)-point streak!"
        case .fatigueWarning(let side, let pct):
            let who = side == .player ? "\(playerName) is" : "\(opponentLabel) is"
            return "\(who) getting tired (\(Int(pct))% energy)"
        case .abilityTriggered(let side, let name, let effect):
            let who = side == .player ? "\(playerName)'s" : "\(opponentLabel)'s"
            return "\(who) \(name) activates! \(effect)"
        case .gameEnd(let num, let winner, let score):
            let who = winner == .player ? "\(playerName) wins" : "\(opponentLabel) wins"
            return "\(who) Game \(num)! (Games: \(score.playerGames)-\(score.opponentGames))"
        case .timeoutCalled(let side, let energyRestored, let streakBroken):
            let who = side == .player ? playerName : opponentLabel
            if streakBroken {
                return "⏸ \(who) calls timeout! Broke the opponent's momentum and recovered \(Int(energyRestored))% energy."
            } else {
                return "⏸ \(who) calls timeout! Recovered \(Int(energyRestored))% energy."
            }
        case .consumableUsed(let side, let name, let effect):
            let who = side == .player ? playerName : opponentLabel
            return "🧃 \(who) used \(name) — \(effect)!"
        case .hookCallAttempt(let side, let success, let repChange):
            let who = side == .player ? playerName : opponentLabel
            if success {
                return "👀 \(who) hooked the line call — it worked! Free point gained. (\(repChange) rep)"
            } else {
                return "👀 \(who) hooked the line call — got caught! Opponent gets a free point. (\(repChange) rep)"
            }
        case .sideOut(let newServingTeam, let serverNumber):
            let who = newServingTeam == .player ? "\(playerName)'s team" : "\(opponentLabel)'s team"
            return "Side out! \(who) serves (Server \(serverNumber))"
        case .resigned:
            return "Match resigned."
        case .matchEnd(let result):
            let who = result.didPlayerWin ? "Victory!" : "Defeat!"
            return "\(who) Final: \(result.formattedScore)"
        }
    }
}
