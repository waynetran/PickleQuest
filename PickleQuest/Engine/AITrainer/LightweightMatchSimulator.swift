import Foundation

/// Synchronous match simulator for AI training.
/// Mirrors `RallySimulator` logic but uses mutable `SimulationParameters` instead of `GameConstants`.
/// Runs entirely on one thread — no actors, no async.
struct LightweightMatchSimulator: Sendable {
    let params: SimulationParameters
    let rng: SeededRandomSource

    struct MatchResult: Sendable {
        let winnerSide: MatchSide
        let playerScore: Int
        let opponentScore: Int
        let totalRallies: Int
        let totalRallyShots: Int
    }

    /// Simulate a full match to 11, win by 2, cap 15.
    func simulateMatch(playerStats: PlayerStats, opponentStats: PlayerStats) -> MatchResult {
        var pScore = 0
        var oScore = 0
        var servingSide: MatchSide = .player
        var totalRallies = 0
        var totalRallyShots = 0

        while true {
            let result = simulatePoint(
                serverSide: servingSide,
                playerStats: playerStats,
                opponentStats: opponentStats
            )
            totalRallies += 1
            totalRallyShots += result.rallyLength

            if result.winnerSide == .player {
                if servingSide == .player {
                    pScore += 1
                } else {
                    // Side-out: switch serve
                    servingSide = .player
                }
            } else {
                if servingSide == .opponent {
                    oScore += 1
                } else {
                    servingSide = .opponent
                }
            }

            // Check win condition
            if pScore >= 11 && pScore - oScore >= 2 { break }
            if oScore >= 11 && oScore - pScore >= 2 { break }
            if pScore >= 15 || oScore >= 15 { break } // sudden death cap

            // Safety valve
            if totalRallies > 500 { break }
        }

        let winner: MatchSide = pScore >= oScore ? .player : .opponent
        return MatchResult(
            winnerSide: winner,
            playerScore: pScore,
            opponentScore: oScore,
            totalRallies: totalRallies,
            totalRallyShots: totalRallyShots
        )
    }

    // MARK: - Point Simulation

    private func simulatePoint(
        serverSide: MatchSide,
        playerStats: PlayerStats,
        opponentStats: PlayerStats
    ) -> (winnerSide: MatchSide, rallyLength: Int) {
        let serverStats = serverSide == .player ? playerStats : opponentStats
        let receiverStats = serverSide == .player ? opponentStats : playerStats

        // Phase 1: Ace check
        let aceChance = calculateAceChance(server: serverStats, receiver: receiverStats)
        if rng.nextDouble() < aceChance {
            return (serverSide, 1)
        }

        // Phase 2: Rally
        var totalShots = 1
        let maxShots = calculateMaxRallyLength(player: playerStats, opponent: opponentStats)

        while totalShots <= maxShots {
            let attackingSide: MatchSide = (totalShots % 2 == 1)
                ? serverSide
                : (serverSide == .player ? .opponent : .player)
            let attacker = attackingSide == .player ? playerStats : opponentStats
            let defender = attackingSide == .player ? opponentStats : playerStats

            let winnerChance = calculateWinnerChance(attacker: attacker, defender: defender, shotNumber: totalShots)
            if rng.nextDouble() < winnerChance {
                return (attackingSide, totalShots)
            }

            let errorChance = calculateErrorChance(attacker: attacker, shotNumber: totalShots)
            if rng.nextDouble() < errorChance {
                let otherSide: MatchSide = attackingSide == .player ? .opponent : .player
                return (otherSide, totalShots)
            }

            let forcedErrorChance = calculateForcedErrorChance(attacker: attacker, defender: defender)
            if rng.nextDouble() < forcedErrorChance {
                return (attackingSide, totalShots)
            }

            totalShots += 1
        }

        // Rally went to max — resolve by stat comparison
        let playerAdvantage = overallAdvantage(player: playerStats, opponent: opponentStats)
        let winner: MatchSide = rng.nextDouble() < playerAdvantage ? .player : .opponent
        return (winner, maxShots)
    }

    // MARK: - Probability Calculations (using SimulationParameters)

    private func calculateAceChance(server: PlayerStats, receiver: PlayerStats) -> Double {
        let base = params.baseAceChance
        let powerBonus = Double(server.power) * params.powerAceScaling
        let reflexPenalty = Double(receiver.reflexes) * params.reflexDefenseScale
        return max(0.01, min(0.25, base + powerBonus - reflexPenalty))
    }

    private func calculateMaxRallyLength(player: PlayerStats, opponent: PlayerStats) -> Int {
        let avgDefense = Double(player.defense + opponent.defense + player.consistency + opponent.consistency) / 4.0
        let baseLength = 5 + Int(avgDefense / 10.0)
        return min(max(baseLength, GameConstants.Rally.minRallyShots), GameConstants.Rally.maxRallyShots)
    }

    private func calculateWinnerChance(attacker: PlayerStats, defender: PlayerStats, shotNumber: Int) -> Double {
        let base = params.baseWinnerChance
        let attackFactor = (Double(attacker.power) + Double(attacker.accuracy) + Double(attacker.spin)) / 300.0
        let defenseFactor = (Double(defender.defense) + Double(defender.positioning) + Double(defender.reflexes)) / 300.0
        let shotBonus = Double(shotNumber) * params.winnerShotBonus
        return max(0.02, min(0.35, base + attackFactor - defenseFactor + shotBonus))
    }

    private func calculateErrorChance(attacker: PlayerStats, shotNumber: Int) -> Double {
        let base = params.baseErrorChance
        let consistencyFactor = Double(attacker.consistency) * params.errorConsistencyScale
        let accuracyFactor = Double(attacker.accuracy) * params.errorAccuracyScale
        let fatigueFactor = Double(shotNumber) * params.errorFatigueScale
        return max(0.02, min(0.30, base - consistencyFactor - accuracyFactor + fatigueFactor))
    }

    private func calculateForcedErrorChance(attacker: PlayerStats, defender: PlayerStats) -> Double {
        let attackPressure = (Double(attacker.power) + Double(attacker.spin)) * params.attackPressureScale
        let defenseResist = (Double(defender.defense) + Double(defender.reflexes)) * params.defenseResistScale
        return max(0.01, min(0.20, params.forcedErrorBase + attackPressure - defenseResist))
    }

    private func overallAdvantage(player: PlayerStats, opponent: PlayerStats) -> Double {
        let diff = player.average - opponent.average
        return 0.5 + diff * params.overallAdvantageScale
    }
}
