import Foundation

/// Simulates individual rallies: determines rally length and shot outcomes.
struct RallySimulator: Sendable {
    private let rng: RandomSource

    init(rng: RandomSource = SystemRandomSource()) {
        self.rng = rng
    }

    struct RallyResult: Sendable {
        let winnerSide: MatchSide
        let pointType: PointType
        let rallyLength: Int
    }

    /// Simulate a single point including serve phase, optional dink phase (doubles), and rally phase.
    func simulatePoint(
        serverSide: MatchSide,
        playerStats: PlayerStats,
        opponentStats: PlayerStats,
        isDoubles: Bool = false
    ) -> RallyResult {
        let serverStats = serverSide == .player ? playerStats : opponentStats
        let receiverStats = serverSide == .player ? opponentStats : playerStats

        // Phase 1: Serve — check for ace
        let aceChance = calculateAceChance(server: serverStats, receiver: receiverStats)
        if rng.nextDouble() < aceChance {
            return RallyResult(winnerSide: serverSide, pointType: .ace, rallyLength: 1)
        }

        var totalShots = 1 // count the serve return

        // Phase 2 (doubles only): Dink approach phase — kitchen line battle
        if isDoubles {
            let dinkLength = calculateDinkLength(player: playerStats, opponent: opponentStats)
            let receiverSide: MatchSide = serverSide == .player ? .opponent : .player

            for dinkShot in 0..<dinkLength {
                totalShots += 1
                let attackingSide: MatchSide = (dinkShot % 2 == 0) ? receiverSide : serverSide
                let attacker = attackingSide == .player ? playerStats : opponentStats
                let defender = attackingSide == .player ? opponentStats : playerStats

                // Dink winner: uses accuracy + spin + focus (soft game stats)
                let dinkWinChance = calculateDinkWinnerChance(attacker: attacker, defender: defender)
                if rng.nextDouble() < dinkWinChance {
                    return RallyResult(winnerSide: attackingSide, pointType: .winner, rallyLength: totalShots)
                }

                // Dink error: uses consistency + focus
                let dinkErrChance = calculateDinkErrorChance(attacker: attacker)
                if rng.nextDouble() < dinkErrChance {
                    let otherSide: MatchSide = attackingSide == .player ? .opponent : .player
                    return RallyResult(winnerSide: otherSide, pointType: .unforcedError, rallyLength: totalShots)
                }

                // Dink forced error
                if rng.nextDouble() < GameConstants.Rally.dinkForcedErrorChance {
                    return RallyResult(winnerSide: attackingSide, pointType: .forcedError, rallyLength: totalShots)
                }
            }
        }

        // Phase 3: Regular rally
        let maxShots = isDoubles
            ? GameConstants.Rally.doublesMaxRallyShots
            : calculateMaxRallyLength(player: playerStats, opponent: opponentStats)

        while totalShots <= maxShots {
            let attackingSide: MatchSide = (totalShots % 2 == 1) ? serverSide : (serverSide == .player ? .opponent : .player)
            let attacker = attackingSide == .player ? playerStats : opponentStats
            let defender = attackingSide == .player ? opponentStats : playerStats

            let winnerChance = calculateWinnerChance(attacker: attacker, defender: defender, shotNumber: totalShots)
            if rng.nextDouble() < winnerChance {
                return RallyResult(winnerSide: attackingSide, pointType: .winner, rallyLength: totalShots)
            }

            let errorChance = calculateErrorChance(attacker: attacker, shotNumber: totalShots)
            if rng.nextDouble() < errorChance {
                let otherSide: MatchSide = attackingSide == .player ? .opponent : .player
                return RallyResult(winnerSide: otherSide, pointType: .unforcedError, rallyLength: totalShots)
            }

            let forcedErrorChance = calculateForcedErrorChance(attacker: attacker, defender: defender)
            if rng.nextDouble() < forcedErrorChance {
                return RallyResult(winnerSide: attackingSide, pointType: .forcedError, rallyLength: totalShots)
            }

            totalShots += 1
        }

        // Rally went to max — resolve by stat comparison
        let playerAdvantage = overallAdvantage(player: playerStats, opponent: opponentStats)
        let winnerSide: MatchSide = rng.nextDouble() < playerAdvantage ? .player : .opponent
        return RallyResult(winnerSide: winnerSide, pointType: .rally, rallyLength: maxShots)
    }

    // MARK: - Probability Calculations

    private func calculateAceChance(server: PlayerStats, receiver: PlayerStats) -> Double {
        let S = GameConstants.Rally.statSensitivity
        let base = GameConstants.Rally.baseAceChance
        let powerBonus = Double(server.power) * GameConstants.Rally.powerAceScaling
        let reflexPenalty = Double(receiver.reflexes) * GameConstants.Rally.reflexDefenseScale
        let differential = (powerBonus - reflexPenalty) * S
        return max(0.01, min(0.25, base + differential))
    }

    private func calculateMaxRallyLength(player: PlayerStats, opponent: PlayerStats) -> Int {
        let avgDefense = Double(player.defense + opponent.defense + player.consistency + opponent.consistency) / 4.0
        let baseLength = 5 + Int(avgDefense / 10.0)
        return min(max(baseLength, GameConstants.Rally.minRallyShots), GameConstants.Rally.maxRallyShots)
    }

    private func calculateWinnerChance(attacker: PlayerStats, defender: PlayerStats, shotNumber: Int) -> Double {
        let S = GameConstants.Rally.statSensitivity
        let base = GameConstants.Rally.baseWinnerChance
        let attackFactor = (Double(attacker.power) + Double(attacker.accuracy) + Double(attacker.spin)) / 300.0
        let defenseFactor = (Double(defender.defense) + Double(defender.positioning) + Double(defender.reflexes)) / 300.0
        let differential = (attackFactor - defenseFactor) * S
        let shotBonus = Double(shotNumber) * 0.005 // longer rallies slightly increase winner chance
        return max(0.02, min(0.35, base + differential + shotBonus))
    }

    private func calculateErrorChance(attacker: PlayerStats, shotNumber: Int) -> Double {
        let base = GameConstants.Rally.baseErrorChance
        let consistencyFactor = Double(attacker.consistency) / 200.0
        let accuracyFactor = Double(attacker.accuracy) / 200.0
        let fatigueFactor = Double(shotNumber) * 0.003
        return max(0.02, min(0.30, base - consistencyFactor - accuracyFactor + fatigueFactor))
    }

    private func calculateForcedErrorChance(attacker: PlayerStats, defender: PlayerStats) -> Double {
        let S = GameConstants.Rally.statSensitivity
        let attackPressure = (Double(attacker.power) + Double(attacker.spin)) / 200.0
        let defenseResist = (Double(defender.defense) + Double(defender.reflexes)) / 200.0
        let differential = (attackPressure - defenseResist) * S
        return max(0.01, min(0.20, 0.08 + differential))
    }

    // MARK: - Doubles Dink Phase

    private func calculateDinkLength(player: PlayerStats, opponent: PlayerStats) -> Int {
        let avgSoftGame = Double(player.accuracy + player.consistency + player.focus +
                                  opponent.accuracy + opponent.consistency + opponent.focus) / 6.0
        let normalized = avgSoftGame / 99.0
        let range = GameConstants.Rally.doublesDinkMaxShots - GameConstants.Rally.doublesDinkMinShots
        return GameConstants.Rally.doublesDinkMinShots + Int(normalized * Double(range))
    }

    private func calculateDinkWinnerChance(attacker: PlayerStats, defender: PlayerStats) -> Double {
        let S = GameConstants.Rally.statSensitivity
        let attackFactor = (Double(attacker.accuracy) + Double(attacker.spin) + Double(attacker.focus)) / 300.0
        let defenseFactor = (Double(defender.consistency) + Double(defender.focus) + Double(defender.positioning)) / 300.0
        let differential = (attackFactor - defenseFactor) * S
        return max(0.01, min(0.15, GameConstants.Rally.dinkWinnerChance + differential))
    }

    private func calculateDinkErrorChance(attacker: PlayerStats) -> Double {
        let consistencyFactor = Double(attacker.consistency) / 200.0
        let focusFactor = Double(attacker.focus) / 200.0
        return max(0.01, min(0.15, GameConstants.Rally.dinkErrorChance - consistencyFactor - focusFactor))
    }

    private func overallAdvantage(player: PlayerStats, opponent: PlayerStats) -> Double {
        let S = GameConstants.Rally.statSensitivity
        let pTotal = player.average
        let oTotal = opponent.average
        let diff = pTotal - oTotal
        return 0.5 + (diff / 200.0) * S
    }
}

// MARK: - Random Source Protocol

protocol RandomSource: Sendable {
    func nextDouble() -> Double
    func nextInt(in range: ClosedRange<Int>) -> Int
}

final class SystemRandomSource: RandomSource {
    func nextDouble() -> Double {
        Double.random(in: 0..<1)
    }

    func nextInt(in range: ClosedRange<Int>) -> Int {
        Int.random(in: range)
    }
}

/// Seeded random source for deterministic testing.
final class SeededRandomSource: RandomSource, @unchecked Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    func nextDouble() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 33) / Double(UInt32.max)
    }

    func nextInt(in range: ClosedRange<Int>) -> Int {
        let d = nextDouble()
        return range.lowerBound + Int(d * Double(range.upperBound - range.lowerBound + 1))
    }
}
