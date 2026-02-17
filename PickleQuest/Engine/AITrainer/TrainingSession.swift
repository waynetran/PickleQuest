import Foundation

// MARK: - Training Configuration (nonisolated)

/// Configuration constants for the AI training system.
/// Extracted from TrainingSession to avoid @MainActor isolation on constants.
private enum TrainingConfig {
    static let populationSize = 20
    static let sigma: Double = 0.05
    static let learningRate: Double = 0.01
    static let matchesPerPair = 200
    static let maxGenerations = 200
    static let convergenceThreshold: Double = 0.001
    static let convergencePatience = 10

    // Fitness weights
    static let winRateMSEWeight: Double = 1.0
    static let scoreMarginWeight: Double = 0.3
    static let rallyLengthWeight: Double = 0.1
    static let targetRallyLength: Double = 6.5
}

struct TrainingTestPair: Sendable {
    let higherDUPR: Double
    let lowerDUPR: Double
    let targetWinRate: Double
    let targetMargin: Double
}

/// Elo-style expected win rate: `1/(1+10^(gap*100/400))`
private func makeTestPair(higher: Double, lower: Double) -> TrainingTestPair {
    let gap = higher - lower
    let expectedWinRate = 1.0 / (1.0 + pow(10.0, -gap * 100.0 / 400.0))
    let targetMargin = gap * 2.5
    return TrainingTestPair(higherDUPR: higher, lowerDUPR: lower,
                            targetWinRate: expectedWinRate, targetMargin: targetMargin)
}

private let allTestPairs: [TrainingTestPair] = {
    var pairs: [TrainingTestPair] = []

    // 0.5 DUPR gap pairs
    var d = 2.0
    while d <= 7.0 {
        pairs.append(makeTestPair(higher: d + 0.5, lower: d))
        d += 0.5
    }

    // Larger gap pairs
    pairs.append(makeTestPair(higher: 3.0, lower: 2.0))
    pairs.append(makeTestPair(higher: 5.0, lower: 3.0))
    pairs.append(makeTestPair(higher: 6.0, lower: 4.0))
    pairs.append(makeTestPair(higher: 8.0, lower: 5.0))

    return pairs
}()

// MARK: - Training Session

/// Natural Evolution Strategy trainer that optimizes `SimulationParameters`
/// so that NPC-vs-NPC match win rates match real-world DUPR expectations.
@Observable
@MainActor
final class TrainingSession {

    // MARK: - Published State

    var generation: Int = 0
    var currentFitness: Double = .infinity
    var bestFitness: Double = .infinity
    var bestParameters: SimulationParameters = .defaults
    var winRateResults: [TrainingReport.WinRateEntry] = []
    var avgRallyLength: Double = 0
    var isRunning: Bool = false
    var progress: Double = 0

    private var shouldStop = false
    private var startTime: Date?

    // MARK: - Training

    func start() async -> TrainingReport {
        isRunning = true
        shouldStop = false
        startTime = Date()
        generation = 0

        var theta = SimulationParameters.defaults.toArray()
        bestFitness = .infinity
        var bestTheta = theta
        var stagnantCount = 0
        var previousBestFitness: Double = .infinity

        // Evaluate baseline
        let baseParams = SimulationParameters(fromArray: theta).clamped()
        let baseFitness = evaluateFitness(params: baseParams, seed: 0)
        bestFitness = baseFitness
        currentFitness = baseFitness

        while generation < TrainingConfig.maxGenerations && !shouldStop {
            generation += 1
            progress = Double(generation) / Double(TrainingConfig.maxGenerations)

            let n = TrainingConfig.populationSize
            let dim = SimulationParameters.parameterCount

            // Generate perturbation vectors
            var epsilons: [[Double]] = []
            var fitnesses: [Double] = []

            let genSeed = UInt64(generation * 1000)
            let noiseRng = SeededRandomSource(seed: genSeed)

            for i in 0..<n {
                var epsilon = [Double](repeating: 0, count: dim)
                for j in 0..<dim {
                    epsilon[j] = gaussianNoise(rng: noiseRng)
                }
                epsilons.append(epsilon)

                // Perturbed candidate
                var candidate = [Double](repeating: 0, count: dim)
                for j in 0..<dim {
                    candidate[j] = theta[j] + TrainingConfig.sigma * epsilon[j]
                }

                let candidateParams = SimulationParameters(fromArray: candidate).clamped()
                let fitness = evaluateFitness(params: candidateParams, seed: UInt64(generation * 1000 + i))
                fitnesses.append(fitness)
            }

            // Rank-normalize fitnesses (lower is better)
            let sortedIndices = fitnesses.indices.sorted { fitnesses[$0] < fitnesses[$1] }
            var utilities = [Double](repeating: 0, count: n)
            for (rank, idx) in sortedIndices.enumerated() {
                utilities[idx] = Double(n / 2 - rank) / Double(n)
            }

            // Update theta
            for j in 0..<dim {
                var grad = 0.0
                for i in 0..<n {
                    grad += utilities[i] * epsilons[i][j]
                }
                theta[j] += TrainingConfig.learningRate / (Double(n) * TrainingConfig.sigma) * grad
            }

            // Evaluate current theta
            let currentParams = SimulationParameters(fromArray: theta).clamped()
            let fitness = evaluateFitness(params: currentParams, seed: UInt64(generation * 10000))
            currentFitness = fitness

            if fitness < bestFitness {
                bestFitness = fitness
                bestTheta = theta
                bestParameters = currentParams
            }

            // Update win rate table for UI
            updateWinRateTable(params: currentParams, seed: UInt64(generation * 10000))

            // Convergence check
            if abs(previousBestFitness - bestFitness) < TrainingConfig.convergenceThreshold {
                stagnantCount += 1
            } else {
                stagnantCount = 0
            }
            previousBestFitness = bestFitness

            if stagnantCount >= TrainingConfig.convergencePatience {
                break
            }

            // Yield to UI
            await Task.yield()
        }

        isRunning = false
        let elapsed = Date().timeIntervalSince(startTime ?? Date())

        // Final evaluation with more matches for the report
        let finalParams = SimulationParameters(fromArray: bestTheta).clamped()
        let finalEntries = evaluateDetailed(params: finalParams, seed: 42, matchCount: 500)

        return TrainingReport(
            parameters: finalParams,
            fitnessScore: bestFitness,
            generationCount: generation,
            winRateTable: finalEntries,
            avgRallyLength: avgRallyLength,
            elapsedSeconds: elapsed
        )
    }

    func stop() {
        shouldStop = true
    }

    // MARK: - Fitness Evaluation

    private nonisolated func evaluateFitness(params: SimulationParameters, seed: UInt64) -> Double {
        var winRateMSE = 0.0
        var marginMSE = 0.0
        var totalRallySum = 0.0
        var totalMatches = 0

        for (pairIdx, pair) in allTestPairs.enumerated() {
            let higherStats = NPC.practiceOpponent(dupr: pair.higherDUPR).stats
            let lowerStats = NPC.practiceOpponent(dupr: pair.lowerDUPR).stats

            var higherWins = 0
            var totalMargin = 0.0
            var totalRallies = 0.0

            for m in 0..<TrainingConfig.matchesPerPair {
                let matchSeed = seed &+ UInt64(pairIdx * 10000 + m)
                let rng = SeededRandomSource(seed: matchSeed)
                let sim = LightweightMatchSimulator(params: params, rng: rng)
                let result = sim.simulateMatch(playerStats: higherStats, opponentStats: lowerStats)

                if result.winnerSide == .player { higherWins += 1 }
                totalMargin += Double(abs(result.playerScore - result.opponentScore))
                totalRallies += Double(result.totalRallyShots) / Double(max(1, result.totalRallies))
            }

            let actualRate = Double(higherWins) / Double(TrainingConfig.matchesPerPair)
            let rateDiff = actualRate - pair.targetWinRate
            winRateMSE += rateDiff * rateDiff

            let avgMargin = totalMargin / Double(TrainingConfig.matchesPerPair)
            let marginDiff = avgMargin - pair.targetMargin
            marginMSE += marginDiff * marginDiff

            totalRallySum += totalRallies / Double(TrainingConfig.matchesPerPair)
            totalMatches += 1
        }

        winRateMSE /= Double(totalMatches)
        marginMSE /= Double(totalMatches)

        let avgRally = totalRallySum / Double(totalMatches)
        let rallyDiff = avgRally - TrainingConfig.targetRallyLength
        let rallyPenalty = rallyDiff * rallyDiff

        return winRateMSE * TrainingConfig.winRateMSEWeight
             + marginMSE * TrainingConfig.scoreMarginWeight
             + rallyPenalty * TrainingConfig.rallyLengthWeight
    }

    private func updateWinRateTable(params: SimulationParameters, seed: UInt64) {
        var entries: [TrainingReport.WinRateEntry] = []
        var totalAvgRally = 0.0

        for (pairIdx, pair) in allTestPairs.enumerated() {
            let higherStats = NPC.practiceOpponent(dupr: pair.higherDUPR).stats
            let lowerStats = NPC.practiceOpponent(dupr: pair.lowerDUPR).stats

            var higherWins = 0
            var totalMargin = 0.0
            var totalRallies = 0.0
            let sampleSize = 100

            for m in 0..<sampleSize {
                let matchSeed = seed &+ UInt64(pairIdx * 10000 + m)
                let rng = SeededRandomSource(seed: matchSeed)
                let sim = LightweightMatchSimulator(params: params, rng: rng)
                let result = sim.simulateMatch(playerStats: higherStats, opponentStats: lowerStats)

                if result.winnerSide == .player { higherWins += 1 }
                totalMargin += Double(abs(result.playerScore - result.opponentScore))
                totalRallies += Double(result.totalRallyShots) / Double(max(1, result.totalRallies))
            }

            let actualRate = Double(higherWins) / Double(sampleSize)
            let avgMargin = totalMargin / Double(sampleSize)
            totalAvgRally += totalRallies / Double(sampleSize)

            entries.append(TrainingReport.WinRateEntry(
                higherDUPR: pair.higherDUPR,
                lowerDUPR: pair.lowerDUPR,
                actualWinRate: actualRate,
                targetWinRate: pair.targetWinRate,
                matchesPlayed: sampleSize,
                avgScoreMargin: avgMargin
            ))
        }

        winRateResults = entries
        avgRallyLength = totalAvgRally / Double(allTestPairs.count)
    }

    private nonisolated func evaluateDetailed(params: SimulationParameters, seed: UInt64, matchCount: Int) -> [TrainingReport.WinRateEntry] {
        var entries: [TrainingReport.WinRateEntry] = []

        for (pairIdx, pair) in allTestPairs.enumerated() {
            let higherStats = NPC.practiceOpponent(dupr: pair.higherDUPR).stats
            let lowerStats = NPC.practiceOpponent(dupr: pair.lowerDUPR).stats

            var higherWins = 0
            var totalMargin = 0.0

            for m in 0..<matchCount {
                let matchSeed = seed &+ UInt64(pairIdx * 10000 + m)
                let rng = SeededRandomSource(seed: matchSeed)
                let sim = LightweightMatchSimulator(params: params, rng: rng)
                let result = sim.simulateMatch(playerStats: higherStats, opponentStats: lowerStats)

                if result.winnerSide == .player { higherWins += 1 }
                totalMargin += Double(abs(result.playerScore - result.opponentScore))
            }

            entries.append(TrainingReport.WinRateEntry(
                higherDUPR: pair.higherDUPR,
                lowerDUPR: pair.lowerDUPR,
                actualWinRate: Double(higherWins) / Double(matchCount),
                targetWinRate: pair.targetWinRate,
                matchesPlayed: matchCount,
                avgScoreMargin: totalMargin / Double(matchCount)
            ))
        }

        return entries
    }

    // MARK: - Gaussian Noise (Box-Muller)

    private nonisolated func gaussianNoise(rng: SeededRandomSource) -> Double {
        let u1 = max(1e-10, rng.nextDouble())
        let u2 = rng.nextDouble()
        return sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
    }
}
