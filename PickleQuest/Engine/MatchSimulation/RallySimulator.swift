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

    /// Simulate a single point including serve phase and rally phase.
    func simulatePoint(
        serverSide: MatchSide,
        playerStats: PlayerStats,
        opponentStats: PlayerStats
    ) -> RallyResult {
        let serverStats = serverSide == .player ? playerStats : opponentStats
        let receiverStats = serverSide == .player ? opponentStats : playerStats

        // Phase 1: Serve — check for ace
        let aceChance = calculateAceChance(server: serverStats, receiver: receiverStats)
        if rng.nextDouble() < aceChance {
            return RallyResult(winnerSide: serverSide, pointType: .ace, rallyLength: 1)
        }

        // Phase 2: Rally
        let maxShots = calculateMaxRallyLength(
            player: playerStats,
            opponent: opponentStats
        )

        var shot = 1
        while shot <= maxShots {
            // Determine which side is "attacking" this shot
            let attackingSide: MatchSide = (shot % 2 == 1) ? serverSide : (serverSide == .player ? .opponent : .player)
            let attacker = attackingSide == .player ? playerStats : opponentStats
            let defender = attackingSide == .player ? opponentStats : playerStats

            // Check for winner
            let winnerChance = calculateWinnerChance(attacker: attacker, defender: defender, shotNumber: shot)
            if rng.nextDouble() < winnerChance {
                return RallyResult(winnerSide: attackingSide, pointType: .winner, rallyLength: shot)
            }

            // Check for unforced error by attacker
            let errorChance = calculateErrorChance(attacker: attacker, shotNumber: shot)
            if rng.nextDouble() < errorChance {
                let otherSide: MatchSide = attackingSide == .player ? .opponent : .player
                return RallyResult(winnerSide: otherSide, pointType: .unforcedError, rallyLength: shot)
            }

            // Check for forced error on defender
            let forcedErrorChance = calculateForcedErrorChance(attacker: attacker, defender: defender)
            if rng.nextDouble() < forcedErrorChance {
                return RallyResult(winnerSide: attackingSide, pointType: .forcedError, rallyLength: shot)
            }

            shot += 1
        }

        // Rally went to max — resolve by stat comparison
        let playerAdvantage = overallAdvantage(player: playerStats, opponent: opponentStats)
        let winnerSide: MatchSide = rng.nextDouble() < playerAdvantage ? .player : .opponent
        return RallyResult(winnerSide: winnerSide, pointType: .rally, rallyLength: maxShots)
    }

    // MARK: - Probability Calculations

    private func calculateAceChance(server: PlayerStats, receiver: PlayerStats) -> Double {
        let base = GameConstants.Rally.baseAceChance
        let powerBonus = Double(server.power) * GameConstants.Rally.powerAceScaling
        let reflexPenalty = Double(receiver.reflexes) * GameConstants.Rally.reflexDefenseScale
        return max(0.01, min(0.25, base + powerBonus - reflexPenalty))
    }

    private func calculateMaxRallyLength(player: PlayerStats, opponent: PlayerStats) -> Int {
        let avgDefense = Double(player.defense + opponent.defense + player.consistency + opponent.consistency) / 4.0
        let baseLength = 5 + Int(avgDefense / 10.0)
        return min(max(baseLength, GameConstants.Rally.minRallyShots), GameConstants.Rally.maxRallyShots)
    }

    private func calculateWinnerChance(attacker: PlayerStats, defender: PlayerStats, shotNumber: Int) -> Double {
        let base = GameConstants.Rally.baseWinnerChance
        let attackFactor = (Double(attacker.power) + Double(attacker.accuracy) + Double(attacker.spin)) / 300.0
        let defenseFactor = (Double(defender.defense) + Double(defender.positioning) + Double(defender.reflexes)) / 300.0
        let shotBonus = Double(shotNumber) * 0.005 // longer rallies slightly increase winner chance
        return max(0.02, min(0.35, base + attackFactor - defenseFactor + shotBonus))
    }

    private func calculateErrorChance(attacker: PlayerStats, shotNumber: Int) -> Double {
        let base = GameConstants.Rally.baseErrorChance
        let consistencyFactor = Double(attacker.consistency) / 200.0
        let accuracyFactor = Double(attacker.accuracy) / 200.0
        let fatigueFactor = Double(shotNumber) * 0.003
        return max(0.02, min(0.30, base - consistencyFactor - accuracyFactor + fatigueFactor))
    }

    private func calculateForcedErrorChance(attacker: PlayerStats, defender: PlayerStats) -> Double {
        let attackPressure = (Double(attacker.power) + Double(attacker.spin)) / 200.0
        let defenseResist = (Double(defender.defense) + Double(defender.reflexes)) / 200.0
        return max(0.01, min(0.20, 0.08 + attackPressure - defenseResist))
    }

    private func overallAdvantage(player: PlayerStats, opponent: PlayerStats) -> Double {
        let pTotal = player.average
        let oTotal = opponent.average
        let diff = pTotal - oTotal
        return 0.5 + (diff / 200.0) // slight advantage based on stat difference
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
