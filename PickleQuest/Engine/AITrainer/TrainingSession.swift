import Foundation

// MARK: - Training Configuration (nonisolated)

/// Configuration constants for the AI training system.
/// Extracted from TrainingSession to avoid @MainActor isolation on constants.
private enum TrainingConfig {
    static let populationSize = 30
    static let sigma: Double = 0.07
    static let learningRate: Double = 0.015
    static let matchesPerPair = 200
    static let maxGenerations = 300
    static let convergenceThreshold: Double = 0.001
    static let convergencePatience = 15

    // Fitness weights
    static let npcPointDiffWeight: Double = 1.0
    static let playerVsNPCPointDiffWeight: Double = 0.8
    static let starterPointDiffWeight: Double = 0.5
    static let rallyLengthWeight: Double = 0.1
    static let targetRallyLength: Double = 6.5

    // Player-vs-NPC target: player (bare stats) should lose by ~2 points without equipment
    static let playerVsNPCTargetDiff: Double = -2.0
    // Starter target: new player vs NPC at DUPR 2.0 should be even
    static let starterTargetDiff: Double = 0.0
}

struct TrainingTestPair: Sendable {
    let higherDUPR: Double
    let lowerDUPR: Double
    /// Expected signed point differential: higher player score minus lower player score.
    /// Based on DUPR formula: 1.2 points per 0.1 DUPR gap (12.0 per 1.0 gap) in an 11-point game.
    let targetPointDiff: Double
}

/// DUPR-based expected point differential: `gap * 12.0` points per game to 11,
/// capped at 10.5 (max achievable avg diff in a game to 11, win-by-2, cap 15).
private func makeTestPair(higher: Double, lower: Double) -> TrainingTestPair {
    let gap = higher - lower
    let targetPointDiff = min(gap * 12.0, 10.5)
    return TrainingTestPair(higherDUPR: higher, lowerDUPR: lower,
                            targetPointDiff: targetPointDiff)
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

/// Player-vs-NPC test pairs: player uses bare stats, NPC uses stats + virtual equipment.
private let playerVsNPCTestDUPRs: [Double] = [2.0, 3.0, 4.0, 5.0, 6.0, 7.0]

// MARK: - Training Session

/// Natural Evolution Strategy trainer that optimizes `SimulationParameters`
/// (per-stat mapping coefficients) so that NPC-vs-NPC match point differentials match
/// real-world DUPR expectations, and player-vs-NPC balance is calibrated.
@Observable
@MainActor
final class TrainingSession {

    // MARK: - Published State

    var generation: Int = 0
    var currentFitness: Double = .infinity
    var bestFitness: Double = .infinity
    var bestParameters: SimulationParameters = .defaults
    var npcVsNPCResults: [TrainingReport.PointDiffEntry] = []
    var playerVsNPCResults: [TrainingReport.PlayerVsNPCEntry] = []
    var starterBalance: TrainingReport.PlayerVsNPCEntry?
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

            // Update tables for UI
            updateResultsTables(params: currentParams, seed: UInt64(generation * 10000))

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
        let finalNPCEntries = evaluateNPCDetailed(params: finalParams, seed: 42, matchCount: 500)
        let finalPlayerEntries = evaluatePlayerVsNPCDetailed(params: finalParams, seed: 42, matchCount: 500)
        let finalStarterEntry = evaluateStarterDetailed(params: finalParams, seed: 42, matchCount: 500)
        let headlessEntries = evaluateHeadlessInteractive(params: finalParams, matchCount: 50)

        return TrainingReport(
            parameters: finalParams,
            fitnessScore: bestFitness,
            generationCount: generation,
            npcVsNPCTable: finalNPCEntries,
            playerVsNPCTable: finalPlayerEntries,
            starterBalance: finalStarterEntry,
            avgRallyLength: avgRallyLength,
            elapsedSeconds: elapsed,
            headlessInteractiveTable: headlessEntries
        )
    }

    func stop() {
        shouldStop = true
    }

    // MARK: - Fitness Evaluation

    private nonisolated func evaluateFitness(params: SimulationParameters, seed: UInt64) -> Double {
        var npcPointDiffMSE = 0.0
        var totalRallySum = 0.0
        var npcMatchCount = 0

        // NPC-vs-NPC: target point differential from DUPR formula
        for (pairIdx, pair) in allTestPairs.enumerated() {
            let higherStats = params.toPlayerStats(dupr: pair.higherDUPR)
            let lowerStats = params.toPlayerStats(dupr: pair.lowerDUPR)

            var totalPointDiff = 0.0
            var totalRallies = 0.0

            for m in 0..<TrainingConfig.matchesPerPair {
                let matchSeed = seed &+ UInt64(pairIdx * 10000 + m)
                let rng = SeededRandomSource(seed: matchSeed)
                let sim = LightweightMatchSimulator(rng: rng)
                let result = sim.simulateMatch(playerStats: higherStats, opponentStats: lowerStats)

                // Signed: higher player's score minus lower player's score
                totalPointDiff += Double(result.playerScore - result.opponentScore)
                totalRallies += Double(result.totalRallyShots) / Double(max(1, result.totalRallies))
            }

            let avgPointDiff = totalPointDiff / Double(TrainingConfig.matchesPerPair)
            let diffError = avgPointDiff - pair.targetPointDiff
            npcPointDiffMSE += diffError * diffError

            totalRallySum += totalRallies / Double(TrainingConfig.matchesPerPair)
            npcMatchCount += 1
        }

        npcPointDiffMSE /= Double(npcMatchCount)

        // Player-vs-NPC: player (bare stats) vs NPC (stats + virtual equip) at same DUPR
        var playerVsNPCMSE = 0.0
        for (idx, dupr) in playerVsNPCTestDUPRs.enumerated() {
            let playerStats = params.toPlayerStats(dupr: dupr)
            let npcStats = params.toNPCStats(dupr: dupr)

            var totalPointDiff = 0.0
            for m in 0..<TrainingConfig.matchesPerPair {
                let matchSeed = seed &+ UInt64((allTestPairs.count + idx) * 10000 + m)
                let rng = SeededRandomSource(seed: matchSeed)
                let sim = LightweightMatchSimulator(rng: rng)
                let result = sim.simulateMatch(playerStats: playerStats, opponentStats: npcStats)
                totalPointDiff += Double(result.playerScore - result.opponentScore)
            }

            let avgPointDiff = totalPointDiff / Double(TrainingConfig.matchesPerPair)
            let diffError = avgPointDiff - TrainingConfig.playerVsNPCTargetDiff
            playerVsNPCMSE += diffError * diffError
        }
        playerVsNPCMSE /= Double(playerVsNPCTestDUPRs.count)

        // Starter validation: trained starter stats vs NPC at DUPR 2.0 (with equip)
        let starterStats = params.toPlayerStarterStats()
        let starterNPCStats = params.toNPCStats(dupr: 2.0)
        var starterPointDiff = 0.0
        for m in 0..<TrainingConfig.matchesPerPair {
            let matchSeed = seed &+ UInt64((allTestPairs.count + playerVsNPCTestDUPRs.count) * 10000 + m)
            let rng = SeededRandomSource(seed: matchSeed)
            let sim = LightweightMatchSimulator(rng: rng)
            let result = sim.simulateMatch(playerStats: starterStats, opponentStats: starterNPCStats)
            starterPointDiff += Double(result.playerScore - result.opponentScore)
        }
        let avgStarterDiff = starterPointDiff / Double(TrainingConfig.matchesPerPair)
        let starterError = avgStarterDiff - TrainingConfig.starterTargetDiff
        let starterMSE = starterError * starterError

        let avgRally = totalRallySum / Double(npcMatchCount)
        let rallyDiff = avgRally - TrainingConfig.targetRallyLength
        let rallyPenalty = rallyDiff * rallyDiff

        return npcPointDiffMSE * TrainingConfig.npcPointDiffWeight
             + playerVsNPCMSE * TrainingConfig.playerVsNPCPointDiffWeight
             + starterMSE * TrainingConfig.starterPointDiffWeight
             + rallyPenalty * TrainingConfig.rallyLengthWeight
    }

    private func updateResultsTables(params: SimulationParameters, seed: UInt64) {
        var npcEntries: [TrainingReport.PointDiffEntry] = []
        var totalAvgRally = 0.0
        let sampleSize = 100

        for (pairIdx, pair) in allTestPairs.enumerated() {
            let higherStats = params.toPlayerStats(dupr: pair.higherDUPR)
            let lowerStats = params.toPlayerStats(dupr: pair.lowerDUPR)

            var higherWins = 0
            var totalPointDiff = 0.0
            var totalRallies = 0.0

            for m in 0..<sampleSize {
                let matchSeed = seed &+ UInt64(pairIdx * 10000 + m)
                let rng = SeededRandomSource(seed: matchSeed)
                let sim = LightweightMatchSimulator(rng: rng)
                let result = sim.simulateMatch(playerStats: higherStats, opponentStats: lowerStats)

                if result.winnerSide == .player { higherWins += 1 }
                totalPointDiff += Double(result.playerScore - result.opponentScore)
                totalRallies += Double(result.totalRallyShots) / Double(max(1, result.totalRallies))
            }

            let actualPointDiff = totalPointDiff / Double(sampleSize)
            let actualWinRate = Double(higherWins) / Double(sampleSize)
            totalAvgRally += totalRallies / Double(sampleSize)

            npcEntries.append(TrainingReport.PointDiffEntry(
                higherDUPR: pair.higherDUPR,
                lowerDUPR: pair.lowerDUPR,
                actualPointDiff: actualPointDiff,
                targetPointDiff: pair.targetPointDiff,
                actualWinRate: actualWinRate,
                matchesPlayed: sampleSize
            ))
        }

        // Player-vs-NPC entries
        var pvnEntries: [TrainingReport.PlayerVsNPCEntry] = []
        for (idx, dupr) in playerVsNPCTestDUPRs.enumerated() {
            let playerStats = params.toPlayerStats(dupr: dupr)
            let npcStats = params.toNPCStats(dupr: dupr)

            var playerWins = 0
            var totalPointDiff = 0.0

            for m in 0..<sampleSize {
                let matchSeed = seed &+ UInt64((allTestPairs.count + idx) * 10000 + m)
                let rng = SeededRandomSource(seed: matchSeed)
                let sim = LightweightMatchSimulator(rng: rng)
                let result = sim.simulateMatch(playerStats: playerStats, opponentStats: npcStats)

                if result.winnerSide == .player { playerWins += 1 }
                totalPointDiff += Double(result.playerScore - result.opponentScore)
            }

            pvnEntries.append(TrainingReport.PlayerVsNPCEntry(
                dupr: dupr,
                npcEquipBonus: params.npcEquipmentBonus(dupr: dupr),
                actualPointDiff: totalPointDiff / Double(sampleSize),
                targetPointDiff: TrainingConfig.playerVsNPCTargetDiff,
                actualWinRate: Double(playerWins) / Double(sampleSize),
                matchesPlayed: sampleSize
            ))
        }

        // Starter balance
        let starterStats = params.toPlayerStarterStats()
        let starterNPCStats = params.toNPCStats(dupr: 2.0)
        var starterWins = 0
        var starterPointDiff = 0.0
        for m in 0..<sampleSize {
            let matchSeed = seed &+ UInt64((allTestPairs.count + playerVsNPCTestDUPRs.count) * 10000 + m)
            let rng = SeededRandomSource(seed: matchSeed)
            let sim = LightweightMatchSimulator(rng: rng)
            let result = sim.simulateMatch(playerStats: starterStats, opponentStats: starterNPCStats)
            if result.winnerSide == .player { starterWins += 1 }
            starterPointDiff += Double(result.playerScore - result.opponentScore)
        }

        npcVsNPCResults = npcEntries
        playerVsNPCResults = pvnEntries
        starterBalance = TrainingReport.PlayerVsNPCEntry(
            dupr: 2.0,
            npcEquipBonus: params.npcEquipmentBonus(dupr: 2.0),
            actualPointDiff: starterPointDiff / Double(sampleSize),
            targetPointDiff: TrainingConfig.starterTargetDiff,
            actualWinRate: Double(starterWins) / Double(sampleSize),
            matchesPlayed: sampleSize
        )
        avgRallyLength = totalAvgRally / Double(allTestPairs.count)
    }

    // MARK: - Detailed Evaluation (for final report)

    private nonisolated func evaluateNPCDetailed(params: SimulationParameters, seed: UInt64, matchCount: Int) -> [TrainingReport.PointDiffEntry] {
        var entries: [TrainingReport.PointDiffEntry] = []

        for (pairIdx, pair) in allTestPairs.enumerated() {
            let higherStats = params.toPlayerStats(dupr: pair.higherDUPR)
            let lowerStats = params.toPlayerStats(dupr: pair.lowerDUPR)

            var higherWins = 0
            var totalPointDiff = 0.0

            for m in 0..<matchCount {
                let matchSeed = seed &+ UInt64(pairIdx * 10000 + m)
                let rng = SeededRandomSource(seed: matchSeed)
                let sim = LightweightMatchSimulator(rng: rng)
                let result = sim.simulateMatch(playerStats: higherStats, opponentStats: lowerStats)

                if result.winnerSide == .player { higherWins += 1 }
                totalPointDiff += Double(result.playerScore - result.opponentScore)
            }

            entries.append(TrainingReport.PointDiffEntry(
                higherDUPR: pair.higherDUPR,
                lowerDUPR: pair.lowerDUPR,
                actualPointDiff: totalPointDiff / Double(matchCount),
                targetPointDiff: pair.targetPointDiff,
                actualWinRate: Double(higherWins) / Double(matchCount),
                matchesPlayed: matchCount
            ))
        }

        return entries
    }

    private nonisolated func evaluatePlayerVsNPCDetailed(params: SimulationParameters, seed: UInt64, matchCount: Int) -> [TrainingReport.PlayerVsNPCEntry] {
        var entries: [TrainingReport.PlayerVsNPCEntry] = []

        for (idx, dupr) in playerVsNPCTestDUPRs.enumerated() {
            let playerStats = params.toPlayerStats(dupr: dupr)
            let npcStats = params.toNPCStats(dupr: dupr)

            var playerWins = 0
            var totalPointDiff = 0.0

            for m in 0..<matchCount {
                let matchSeed = seed &+ UInt64((allTestPairs.count + idx) * 10000 + m)
                let rng = SeededRandomSource(seed: matchSeed)
                let sim = LightweightMatchSimulator(rng: rng)
                let result = sim.simulateMatch(playerStats: playerStats, opponentStats: npcStats)

                if result.winnerSide == .player { playerWins += 1 }
                totalPointDiff += Double(result.playerScore - result.opponentScore)
            }

            entries.append(TrainingReport.PlayerVsNPCEntry(
                dupr: dupr,
                npcEquipBonus: params.npcEquipmentBonus(dupr: dupr),
                actualPointDiff: totalPointDiff / Double(matchCount),
                targetPointDiff: TrainingConfig.playerVsNPCTargetDiff,
                actualWinRate: Double(playerWins) / Double(matchCount),
                matchesPlayed: matchCount
            ))
        }

        return entries
    }

    private nonisolated func evaluateStarterDetailed(params: SimulationParameters, seed: UInt64, matchCount: Int) -> TrainingReport.PlayerVsNPCEntry {
        let starterStats = params.toPlayerStarterStats()
        let npcStats = params.toNPCStats(dupr: 2.0)

        var playerWins = 0
        var totalPointDiff = 0.0

        for m in 0..<matchCount {
            let matchSeed = seed &+ UInt64((allTestPairs.count + playerVsNPCTestDUPRs.count) * 10000 + m)
            let rng = SeededRandomSource(seed: matchSeed)
            let sim = LightweightMatchSimulator(rng: rng)
            let result = sim.simulateMatch(playerStats: starterStats, opponentStats: npcStats)

            if result.winnerSide == .player { playerWins += 1 }
            totalPointDiff += Double(result.playerScore - result.opponentScore)
        }

        return TrainingReport.PlayerVsNPCEntry(
            dupr: 2.0,
            npcEquipBonus: params.npcEquipmentBonus(dupr: 2.0),
            actualPointDiff: totalPointDiff / Double(matchCount),
            targetPointDiff: TrainingConfig.starterTargetDiff,
            actualWinRate: Double(playerWins) / Double(matchCount),
            matchesPlayed: matchCount
        )
    }

    // MARK: - Headless Interactive Validation

    /// Run headless interactive matches at various DUPR levels.
    /// Validation only — does NOT affect ES fitness.
    private nonisolated func evaluateHeadlessInteractive(
        params: SimulationParameters,
        matchCount: Int
    ) -> [TrainingReport.HeadlessInteractiveEntry] {
        let testDUPRs: [Double] = [2.0, 3.0, 4.0, 5.0, 6.0]
        var entries: [TrainingReport.HeadlessInteractiveEntry] = []

        for dupr in testDUPRs {
            let playerStats = params.toPlayerStats(dupr: dupr)
            let npc = NPC.practiceOpponent(dupr: dupr)

            var playerWins = 0
            var totalPointDiff = 0.0
            var totalAvgRally = 0.0

            for _ in 0..<matchCount {
                let sim = HeadlessMatchSimulator(
                    npc: npc,
                    playerStats: playerStats,
                    playerDUPR: dupr,
                    params: params
                )
                let result = sim.simulateMatch()

                if result.winnerSide == .player { playerWins += 1 }
                totalPointDiff += Double(result.playerScore - result.opponentScore)
                totalAvgRally += result.avgRallyLength
            }

            entries.append(TrainingReport.HeadlessInteractiveEntry(
                dupr: dupr,
                actualPointDiff: totalPointDiff / Double(matchCount),
                actualWinRate: Double(playerWins) / Double(matchCount),
                avgRallyLength: totalAvgRally / Double(matchCount),
                matchesPlayed: matchCount
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
