import Foundation

/// Orchestrates a full match simulation, emitting events via AsyncStream.
actor MatchEngine {
    private let pointResolver: PointResolver
    private let config: MatchConfig
    private let lootGenerator: LootGenerator?
    private let opponentDifficulty: NPCDifficulty
    private let playerLevel: Int
    private let startingEnergy: Double
    private let suprGap: Double

    // Participant data
    private let playerStats: PlayerStats
    private let opponentStats: PlayerStats
    private let playerEquipment: [Equipment]
    private let opponentEquipment: [Equipment]
    private let playerName: String
    private let opponentName: String

    // Match state
    private var playerPoints: Int = 0
    private var opponentPoints: Int = 0
    private var playerGames: Int = 0
    private var opponentGames: Int = 0
    private var currentGame: Int = 1
    private var pointNumber: Int = 0
    private var servingSide: MatchSide = .player
    private var totalServeCount: Int = 0

    // Tracking
    private var momentum = MomentumTracker()
    private var playerFatigue: FatigueModel
    private var opponentFatigue: FatigueModel
    private var allPoints: [MatchPoint] = []
    private var gameScores: [MatchScore] = []

    // Stats tracking
    private var playerAces = 0, playerWinners = 0, playerUEs = 0, playerFEs = 0
    private var opponentAces = 0, opponentWinners = 0, opponentUEs = 0, opponentFEs = 0
    private var playerMaxRally = 0, opponentMaxRally = 0
    private var playerTotalRally = 0, opponentTotalRally = 0
    private var playerPointsWon = 0, opponentPointsWon = 0

    init(
        playerStats: PlayerStats,
        opponentStats: PlayerStats,
        playerEquipment: [Equipment] = [],
        opponentEquipment: [Equipment] = [],
        playerName: String = "You",
        opponentName: String = "Opponent",
        config: MatchConfig = .defaultSingles,
        pointResolver: PointResolver = PointResolver(),
        lootGenerator: LootGenerator? = nil,
        opponentDifficulty: NPCDifficulty = .beginner,
        playerLevel: Int = 1,
        startingEnergy: Double = GameConstants.PersistentEnergy.maxEnergy,
        suprGap: Double = 0
    ) {
        self.playerStats = playerStats
        self.opponentStats = opponentStats
        self.playerEquipment = playerEquipment
        self.opponentEquipment = opponentEquipment
        self.playerName = playerName
        self.opponentName = opponentName
        self.config = config
        self.pointResolver = pointResolver
        self.lootGenerator = lootGenerator
        self.opponentDifficulty = opponentDifficulty
        self.playerLevel = playerLevel
        self.startingEnergy = startingEnergy
        self.suprGap = suprGap
        self.playerFatigue = FatigueModel(stamina: playerStats.stamina, startingEnergy: startingEnergy)
        self.opponentFatigue = FatigueModel(stamina: opponentStats.stamina)
    }

    /// Run the full match simulation, returning an AsyncStream of events.
    func simulate() -> AsyncStream<MatchEvent> {
        AsyncStream { continuation in
            Task {
                await runMatch(continuation: continuation)
                continuation.finish()
            }
        }
    }

    /// Run the match and return only the final result (for testing/batch simulations).
    func simulateToResult() async -> MatchResult {
        var lastResult: MatchResult?
        for await event in simulate() {
            if case .matchEnd(let result) = event {
                lastResult = result
            }
        }
        return lastResult!
    }

    // MARK: - Match Loop

    private func runMatch(continuation: AsyncStream<MatchEvent>.Continuation) {
        continuation.yield(.matchStart(playerName: playerName, opponentName: opponentName))

        while playerGames < config.gamesToWin && opponentGames < config.gamesToWin {
            runGame(continuation: continuation)
        }

        let result = buildResult()
        continuation.yield(.matchEnd(result: result))
    }

    private func runGame(continuation: AsyncStream<MatchEvent>.Continuation) {
        continuation.yield(.gameStart(gameNumber: currentGame))
        playerPoints = 0
        opponentPoints = 0
        momentum.resetForNewGame()

        while !isGameOver() {
            pointNumber += 1
            let isClutch = isClutchSituation()

            var pFatigue = playerFatigue
            var oFatigue = opponentFatigue

            let resolved = pointResolver.resolvePoint(
                playerBaseStats: playerStats,
                opponentBaseStats: opponentStats,
                playerEquipment: playerEquipment,
                opponentEquipment: opponentEquipment,
                playerFatigue: &pFatigue,
                opponentFatigue: &oFatigue,
                momentum: momentum,
                servingSide: servingSide,
                isClutch: isClutch
            )

            playerFatigue = pFatigue
            opponentFatigue = oFatigue

            // Update score
            let winner = resolved.result.winnerSide
            if winner == .player {
                playerPoints += 1
                playerPointsWon += 1
            } else {
                opponentPoints += 1
                opponentPointsWon += 1
            }

            let score = MatchScore(
                playerPoints: playerPoints,
                opponentPoints: opponentPoints,
                playerGames: playerGames,
                opponentGames: opponentGames
            )

            let point = MatchPoint(
                gameNumber: currentGame,
                pointNumber: pointNumber,
                winnerSide: winner,
                pointType: resolved.result.pointType,
                rallyLength: resolved.result.rallyLength,
                servingSide: servingSide,
                scoreAfter: score
            )
            allPoints.append(point)

            // Track stats
            trackStats(point: point)

            // Emit events
            continuation.yield(.pointPlayed(point))

            // Momentum
            if let streak = momentum.recordPoint(winner: winner) {
                if streak >= 3 {
                    continuation.yield(.streakAlert(side: winner, count: streak))
                }
            }

            // Fatigue warnings
            if resolved.playerEnergyAfter <= GameConstants.Fatigue.threshold1 &&
               resolved.playerEnergyAfter > GameConstants.Fatigue.threshold1 - 5 {
                continuation.yield(.fatigueWarning(side: .player, energyPercent: resolved.playerEnergyAfter))
            }
            if resolved.opponentEnergyAfter <= GameConstants.Fatigue.threshold1 &&
               resolved.opponentEnergyAfter > GameConstants.Fatigue.threshold1 - 5 {
                continuation.yield(.fatigueWarning(side: .opponent, energyPercent: resolved.opponentEnergyAfter))
            }

            // Switch serve
            totalServeCount += 1
            if totalServeCount % GameConstants.Match.serveSwitchInterval == 0 {
                servingSide = servingSide == .player ? .opponent : .player
            }
        }

        // Game over
        let gameWinner: MatchSide = playerPoints > opponentPoints ? .player : .opponent
        if gameWinner == .player {
            playerGames += 1
        } else {
            opponentGames += 1
        }

        let gameScore = MatchScore(
            playerPoints: playerPoints,
            opponentPoints: opponentPoints,
            playerGames: playerGames,
            opponentGames: opponentGames
        )
        gameScores.append(gameScore)
        continuation.yield(.gameEnd(gameNumber: currentGame, winnerSide: gameWinner, score: gameScore))

        // Rest between games
        playerFatigue.restBetweenGames()
        opponentFatigue.restBetweenGames()

        currentGame += 1
        totalServeCount = 0
    }

    // MARK: - Game State

    private func isGameOver() -> Bool {
        let target = config.pointsToWin
        if config.winByTwo {
            return (playerPoints >= target || opponentPoints >= target)
                && abs(playerPoints - opponentPoints) >= 2
                || playerPoints >= GameConstants.Match.maxPoints
                || opponentPoints >= GameConstants.Match.maxPoints
        }
        return playerPoints >= target || opponentPoints >= target
    }

    private func isClutchSituation() -> Bool {
        let target = config.pointsToWin
        return playerPoints >= target - 2 && opponentPoints >= target - 2
    }

    // MARK: - Stat Tracking

    private func trackStats(point: MatchPoint) {
        let isPlayerPoint = point.winnerSide == .player
        let rally = point.rallyLength

        switch point.pointType {
        case .ace:
            if isPlayerPoint { playerAces += 1 } else { opponentAces += 1 }
        case .winner:
            if isPlayerPoint { playerWinners += 1 } else { opponentWinners += 1 }
        case .unforcedError:
            // Winner gets the point from opponent's error
            if isPlayerPoint { opponentUEs += 1 } else { playerUEs += 1 }
        case .forcedError:
            if isPlayerPoint { playerFEs += 1 } else { opponentFEs += 1 }
        case .rally:
            break
        }

        if isPlayerPoint {
            playerMaxRally = max(playerMaxRally, rally)
            playerTotalRally += rally
        } else {
            opponentMaxRally = max(opponentMaxRally, rally)
            opponentTotalRally += rally
        }
    }

    // MARK: - Result

    private func buildResult() -> MatchResult {
        let didWin = playerGames > opponentGames
        let totalPts = allPoints.count

        let xp = calculateXP(didWin: didWin)
        let coins = calculateCoins(didWin: didWin)

        let loot: [Equipment]
        if let generator = lootGenerator {
            loot = generator.generateMatchLoot(
                didWin: didWin,
                opponentDifficulty: opponentDifficulty,
                playerLevel: playerLevel,
                suprGap: suprGap
            )
        } else {
            loot = []
        }

        return MatchResult(
            didPlayerWin: didWin,
            finalScore: MatchScore(
                playerPoints: playerPoints,
                opponentPoints: opponentPoints,
                playerGames: playerGames,
                opponentGames: opponentGames
            ),
            gameScores: gameScores,
            totalPoints: totalPts,
            playerStats: MatchPlayerStats(
                aces: playerAces,
                winners: playerWinners,
                unforcedErrors: playerUEs,
                forcedErrors: playerFEs,
                longestRally: playerMaxRally,
                averageRallyLength: playerPointsWon > 0 ? Double(playerTotalRally) / Double(playerPointsWon) : 0,
                longestStreak: momentum.playerLongestStreak,
                finalEnergy: playerFatigue.energy
            ),
            opponentStats: MatchPlayerStats(
                aces: opponentAces,
                winners: opponentWinners,
                unforcedErrors: opponentUEs,
                forcedErrors: opponentFEs,
                longestRally: opponentMaxRally,
                averageRallyLength: opponentPointsWon > 0 ? Double(opponentTotalRally) / Double(opponentPointsWon) : 0,
                longestStreak: momentum.opponentLongestStreak,
                finalEnergy: opponentFatigue.energy
            ),
            xpEarned: xp,
            coinsEarned: coins,
            loot: loot,
            duration: Double(totalPts) * 1.5, // rough simulated time
            duprChange: nil
        )
    }

    private func calculateXP(didWin: Bool) -> Int {
        var xp = GameConstants.XP.baseXPPerMatch
        if didWin { xp += GameConstants.XP.winBonusXP }
        return xp
    }

    private func calculateCoins(didWin: Bool) -> Int {
        if didWin {
            return GameConstants.Economy.matchWinBaseReward
        } else {
            return GameConstants.Economy.matchLossBaseReward
        }
    }
}
