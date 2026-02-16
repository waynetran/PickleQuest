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
    private let playerConsumables: [Consumable]
    private let playerReputation: Int

    // Participant data — player side
    private let playerStats: PlayerStats
    private let playerEquipment: [Equipment]
    private let playerName: String

    // Participant data — opponent side
    private let opponentStats: PlayerStats
    private let opponentEquipment: [Equipment]
    private let opponentName: String

    // Doubles partner data (nil for singles)
    private let partnerStats: PlayerStats?
    private let partnerEquipment: [Equipment]?
    private let partnerName: String?
    private let opponent2Stats: PlayerStats?
    private let opponent2Equipment: [Equipment]?
    private let opponent2Name: String?

    // Doubles synergy
    private let teamSynergy: TeamSynergy?
    private let opponentSynergy: TeamSynergy?

    // Match state
    private var playerPoints: Int = 0
    private var opponentPoints: Int = 0
    private var playerGames: Int = 0
    private var opponentGames: Int = 0
    private var currentGame: Int = 1
    private var pointNumber: Int = 0
    private var servingSide: MatchSide = .player
    private var totalServeCount: Int = 0

    // Doubles scoring
    private var doublesScoreTracker: DoublesScoreTracker?

    // Tracking
    private var momentum = MomentumTracker()
    private var playerFatigue: FatigueModel
    private var opponentFatigue: FatigueModel
    private var partnerFatigue: FatigueModel?
    private var opponent2Fatigue: FatigueModel?
    private var allPoints: [MatchPoint] = []
    private var gameScores: [MatchScore] = []

    // Stats tracking
    private var playerAces = 0, playerWinners = 0, playerUEs = 0, playerFEs = 0
    private var opponentAces = 0, opponentWinners = 0, opponentUEs = 0, opponentFEs = 0
    private var playerMaxRally = 0, opponentMaxRally = 0
    private var playerTotalRally = 0, opponentTotalRally = 0
    private var playerPointsWon = 0, opponentPointsWon = 0

    // Action flags
    private var skipRequested = false
    private var resignRequested = false

    // Action state per game
    private var timeoutsUsedThisGame = 0
    private var hookCallsUsedThisGame = 0
    private var consumablesUsedCount = 0
    private var availableConsumables: [Consumable]
    private var currentReputation: Int

    // Active consumable stat boosts (stat → total bonus)
    private var activeStatBoosts: [StatType: Int] = [:]

    // Pending action events to emit between points
    private var pendingActionEvents: [MatchEvent] = []

    private var isDoubles: Bool { config.matchType == .doubles }

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
        suprGap: Double = 0,
        playerConsumables: [Consumable] = [],
        playerReputation: Int = 0,
        // Doubles-only parameters
        partnerStats: PlayerStats? = nil,
        partnerEquipment: [Equipment]? = nil,
        partnerName: String? = nil,
        opponent2Stats: PlayerStats? = nil,
        opponent2Equipment: [Equipment]? = nil,
        opponent2Name: String? = nil,
        teamSynergy: TeamSynergy? = nil,
        opponentSynergy: TeamSynergy? = nil
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
        self.playerConsumables = playerConsumables
        self.playerReputation = playerReputation
        self.partnerStats = partnerStats
        self.partnerEquipment = partnerEquipment
        self.partnerName = partnerName
        self.opponent2Stats = opponent2Stats
        self.opponent2Equipment = opponent2Equipment
        self.opponent2Name = opponent2Name
        self.teamSynergy = teamSynergy
        self.opponentSynergy = opponentSynergy

        self.playerFatigue = FatigueModel(stamina: playerStats.stamina, startingEnergy: startingEnergy)
        self.opponentFatigue = FatigueModel(stamina: opponentStats.stamina)
        if let pStats = partnerStats {
            self.partnerFatigue = FatigueModel(stamina: pStats.stamina)
        }
        if let o2Stats = opponent2Stats {
            self.opponent2Fatigue = FatigueModel(stamina: o2Stats.stamina)
        }
        self.availableConsumables = playerConsumables
        self.currentReputation = playerReputation

        if config.matchType == .doubles {
            self.doublesScoreTracker = DoublesScoreTracker()
        }
    }

    /// Run the full match simulation, returning an AsyncStream of events.
    func simulate() -> AsyncStream<MatchEvent> {
        AsyncStream { continuation in
            Task {
                runMatch(continuation: continuation)
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
        continuation.yield(.matchStart(
            playerName: playerName,
            opponentName: opponentName,
            partnerName: partnerName,
            opponent2Name: opponent2Name
        ))

        while playerGames < config.gamesToWin && opponentGames < config.gamesToWin {
            if resignRequested {
                continuation.yield(.resigned)
                let result = buildResult(resigned: true)
                continuation.yield(.matchEnd(result: result))
                return
            }
            runGame(continuation: continuation)
        }

        let result = buildResult()
        continuation.yield(.matchEnd(result: result))
    }

    private func runGame(continuation: AsyncStream<MatchEvent>.Continuation) {
        if !skipRequested {
            continuation.yield(.gameStart(gameNumber: currentGame))
        }
        playerPoints = 0
        opponentPoints = 0
        momentum.resetForNewGame()
        timeoutsUsedThisGame = 0
        hookCallsUsedThisGame = 0
        doublesScoreTracker?.resetForNewGame()

        if isDoubles {
            runDoublesGame(continuation: continuation)
        } else {
            runSinglesGame(continuation: continuation)
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
            opponentGames: opponentGames,
            doublesScoreDisplay: doublesScoreTracker?.scoreDisplay
        )
        gameScores.append(gameScore)
        if !skipRequested {
            continuation.yield(.gameEnd(gameNumber: currentGame, winnerSide: gameWinner, score: gameScore))
        }

        // Rest between games
        playerFatigue.restBetweenGames()
        opponentFatigue.restBetweenGames()
        partnerFatigue?.restBetweenGames()
        opponent2Fatigue?.restBetweenGames()

        currentGame += 1
        totalServeCount = 0
    }

    // MARK: - Singles Game Loop

    private func runSinglesGame(continuation: AsyncStream<MatchEvent>.Continuation) {
        while !isGameOver() {
            if resignRequested { return }
            pointNumber += 1
            let isClutch = isClutchSituation()

            var pFatigue = playerFatigue
            var oFatigue = opponentFatigue

            let resolved = pointResolver.resolvePoint(
                playerBaseStats: boostedPlayerStats(),
                opponentBaseStats: opponentStats,
                playerEquipment: playerEquipment,
                opponentEquipment: opponentEquipment,
                playerFatigue: &pFatigue,
                opponentFatigue: &oFatigue,
                momentum: momentum,
                servingSide: servingSide,
                isClutch: isClutch,
                playerLevel: playerLevel,
                opponentLevel: 50
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
            trackStats(point: point)
            emitPointEvents(point: point, resolved: resolved, continuation: continuation)

            // Switch serve
            totalServeCount += 1
            if totalServeCount % GameConstants.Match.serveSwitchInterval == 0 {
                servingSide = servingSide == .player ? .opponent : .player
            }
        }
    }

    // MARK: - Doubles Game Loop

    private func runDoublesGame(continuation: AsyncStream<MatchEvent>.Continuation) {
        guard var tracker = doublesScoreTracker else { return }

        while !tracker.isGameOver {
            if resignRequested { return }
            pointNumber += 1
            let isClutch = isDoublesClutchSituation(tracker: tracker)

            // Composite team stats with fatigue applied
            let playerTeamStats = compositePlayerTeamStats()
            let opponentTeamStats = compositeOpponentTeamStats()

            // Average fatigue for composite
            var teamPlayerFatigue = averageFatigue(playerFatigue, partnerFatigue)
            var teamOpponentFatigue = averageFatigue(opponentFatigue, opponent2Fatigue)

            let resolved = pointResolver.resolvePoint(
                playerBaseStats: playerTeamStats,
                opponentBaseStats: opponentTeamStats,
                playerEquipment: [],  // already composited
                opponentEquipment: [], // already composited
                playerFatigue: &teamPlayerFatigue,
                opponentFatigue: &teamOpponentFatigue,
                momentum: momentum,
                servingSide: tracker.servingTeam,
                isClutch: isClutch,
                playerLevel: 50,
                opponentLevel: 50
            )

            // Drain individual fatigue models
            drainDoublesEnergy(rallyLength: resolved.result.rallyLength)

            // Determine rally winner
            let rallyWinner = resolved.result.winnerSide
            let winnerIsServingTeam = rallyWinner == tracker.servingTeam

            // Apply doubles scoring
            let outcome = tracker.recordPoint(winnerIsServingTeam: winnerIsServingTeam)

            // Sync points for result tracking
            playerPoints = tracker.playerScore
            opponentPoints = tracker.opponentScore
            servingSide = tracker.servingTeam

            let isSideOut: Bool
            switch outcome {
            case .scored:
                if rallyWinner == .player { playerPointsWon += 1 } else { opponentPointsWon += 1 }
                isSideOut = false
            case .serverRotation:
                isSideOut = false
            case .sideOut(let newServingTeam, _):
                isSideOut = true
                if !skipRequested {
                    continuation.yield(.sideOut(newServingTeam: newServingTeam, serverNumber: tracker.serverNumber))
                }
            }

            let score = MatchScore(
                playerPoints: playerPoints,
                opponentPoints: opponentPoints,
                playerGames: playerGames,
                opponentGames: opponentGames,
                doublesScoreDisplay: tracker.scoreDisplay
            )

            let point = MatchPoint(
                gameNumber: currentGame,
                pointNumber: pointNumber,
                winnerSide: rallyWinner,
                pointType: resolved.result.pointType,
                rallyLength: resolved.result.rallyLength,
                servingSide: servingSide,
                scoreAfter: score,
                serverNumber: tracker.serverNumber,
                isSideOut: isSideOut
            )
            allPoints.append(point)
            trackStats(point: point)
            emitPointEvents(point: point, resolved: resolved, continuation: continuation)
        }

        doublesScoreTracker = tracker
    }

    // MARK: - Consumable Stat Boosts

    /// Returns playerStats with any active consumable stat boosts applied.
    private func boostedPlayerStats() -> PlayerStats {
        guard !activeStatBoosts.isEmpty else { return playerStats }
        var stats = playerStats
        for (stat, bonus) in activeStatBoosts {
            stats.setStat(stat, value: stats.stat(stat) + bonus)
        }
        return stats
    }

    // MARK: - Doubles Helpers

    private func compositePlayerTeamStats() -> PlayerStats {
        let boosted = boostedPlayerStats()
        guard let pStats = partnerStats, let synergy = teamSynergy else {
            return boosted // fallback to singles if no partner
        }
        return TeamStatCompositor.compositeEffectiveStats(
            p1Effective: boosted,
            p2Effective: pStats,
            synergy: synergy
        )
    }

    private func compositeOpponentTeamStats() -> PlayerStats {
        guard let o2Stats = opponent2Stats, let synergy = opponentSynergy else {
            return opponentStats
        }
        return TeamStatCompositor.compositeEffectiveStats(
            p1Effective: opponentStats,
            p2Effective: o2Stats,
            synergy: synergy
        )
    }

    private func averageFatigue(_ f1: FatigueModel, _ f2: FatigueModel?) -> FatigueModel {
        guard let f2 else { return f1 }
        let avgEnergy = (f1.energy + f2.energy) / 2.0
        let avgStamina = (f1.stamina + f2.stamina) / 2
        return FatigueModel(stamina: avgStamina, startingEnergy: avgEnergy)
    }

    private func drainDoublesEnergy(rallyLength: Int) {
        _ = playerFatigue.drainEnergy(rallyLength: rallyLength)
        _ = opponentFatigue.drainEnergy(rallyLength: rallyLength)
        if var pf = partnerFatigue {
            _ = pf.drainEnergy(rallyLength: rallyLength)
            partnerFatigue = pf
        }
        if var o2f = opponent2Fatigue {
            _ = o2f.drainEnergy(rallyLength: rallyLength)
            opponent2Fatigue = o2f
        }
    }

    private func isDoublesClutchSituation(tracker: DoublesScoreTracker) -> Bool {
        let target = config.pointsToWin
        return tracker.playerScore >= target - 2 && tracker.opponentScore >= target - 2
    }

    // MARK: - Shared Point Emission

    private func emitPointEvents(point: MatchPoint, resolved: PointResolver.ResolvedPoint, continuation: AsyncStream<MatchEvent>.Continuation) {
        // Emit pending action events
        for actionEvent in pendingActionEvents {
            if !skipRequested {
                continuation.yield(actionEvent)
            }
        }
        pendingActionEvents.removeAll()

        if !skipRequested {
            continuation.yield(.pointPlayed(point))
        }

        // Momentum
        if let streak = momentum.recordPoint(winner: point.winnerSide) {
            if streak >= 3 && !skipRequested {
                continuation.yield(.streakAlert(side: point.winnerSide, count: streak))
            }
        }

        // Fatigue warnings
        if !skipRequested {
            if resolved.playerEnergyAfter <= GameConstants.Fatigue.threshold1 &&
               resolved.playerEnergyAfter > GameConstants.Fatigue.threshold1 - 5 {
                continuation.yield(.fatigueWarning(side: .player, energyPercent: resolved.playerEnergyAfter))
            }
            if resolved.opponentEnergyAfter <= GameConstants.Fatigue.threshold1 &&
               resolved.opponentEnergyAfter > GameConstants.Fatigue.threshold1 - 5 {
                continuation.yield(.fatigueWarning(side: .opponent, energyPercent: resolved.opponentEnergyAfter))
            }
        }
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

    private func buildResult(resigned: Bool = false) -> MatchResult {
        let didWin = resigned ? false : playerGames > opponentGames
        let totalPts = allPoints.count

        let xp = calculateXP(didWin: didWin)
        let coins = calculateCoins(didWin: didWin)

        let loot: [Equipment]
        if didWin, let generator = lootGenerator {
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
                opponentGames: opponentGames,
                doublesScoreDisplay: doublesScoreTracker?.scoreDisplay
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
            duration: Double(totalPts) * 1.5,
            wasResigned: resigned,
            duprChange: nil,
            partnerName: partnerName,
            opponent2Name: opponent2Name,
            teamSynergy: teamSynergy,
            isDoubles: isDoubles
        )
    }

    private func calculateXP(didWin: Bool) -> Int {
        var xp = GameConstants.XP.baseXPPerMatch
        if didWin { xp += GameConstants.XP.winBonusXP }
        return xp
    }

    private func calculateCoins(didWin: Bool) -> Int {
        // Wager matches: winner takes the wager amount
        if didWin && config.wagerAmount > 0 {
            return config.wagerAmount
        }
        // Rec matches don't award coins — coins come from tournaments and wagers
        return 0
    }

    // MARK: - Action Methods

    func requestSkip() {
        skipRequested = true
    }

    func requestResign() {
        resignRequested = true
    }

    func requestTimeout() -> MatchActionResult {
        guard timeoutsUsedThisGame == 0 else {
            return .timeoutUnavailable(reason: "Already used timeout this game")
        }
        let opponentStreak = momentum.opponentStreak
        guard opponentStreak >= GameConstants.MatchActions.timeoutMinOpponentStreak else {
            return .timeoutUnavailable(reason: "Opponent needs \(GameConstants.MatchActions.timeoutMinOpponentStreak)+ streak")
        }

        timeoutsUsedThisGame += 1
        let restoreAmount = GameConstants.MatchActions.timeoutEnergyRestore
        playerFatigue.restore(amount: restoreAmount)
        let hadStreak = opponentStreak >= 2
        momentum.resetOpponentStreak()

        pendingActionEvents.append(.timeoutCalled(side: .player, energyRestored: restoreAmount, streakBroken: hadStreak))
        return .timeoutUsed(energyRestored: restoreAmount, streakBroken: hadStreak)
    }

    func useConsumable(_ consumable: Consumable) -> MatchActionResult {
        guard consumablesUsedCount < GameConstants.MatchActions.maxConsumablesPerMatch else {
            return .consumableUnavailable(reason: "Max consumables per match reached")
        }
        guard let index = availableConsumables.firstIndex(where: { $0.id == consumable.id }) else {
            return .consumableUnavailable(reason: "Consumable not available")
        }

        availableConsumables.remove(at: index)
        consumablesUsedCount += 1

        let effectDesc: String
        switch consumable.effect {
        case .energyRestore(let amount):
            playerFatigue.restore(amount: amount)
            effectDesc = "+\(Int(amount))% energy"
        case .statBoost(let stat, let amount, _):
            activeStatBoosts[stat, default: 0] += amount
            effectDesc = "+\(amount) \(stat.rawValue) this match"
        case .xpMultiplier(let mult, _):
            effectDesc = "\(mult)x XP"
        }

        pendingActionEvents.append(.consumableUsed(side: .player, name: consumable.name, effect: effectDesc))
        return .consumableUsed(name: consumable.name, effect: effectDesc)
    }

    func requestHookCall() -> MatchActionResult {
        guard hookCallsUsedThisGame == 0 else {
            return .hookCallUnavailable(reason: "Already used hook call this game")
        }
        guard pointNumber > 0 else {
            return .hookCallUnavailable(reason: "Can only hook after a point is played")
        }

        hookCallsUsedThisGame += 1

        let baseChance = GameConstants.MatchActions.hookCallBaseChance
        let repBonus = Double(currentReputation) * GameConstants.MatchActions.hookCallRepBonusPerPoint
        let successChance = min(GameConstants.MatchActions.hookCallMaxChance, baseChance + repBonus)

        let roll = Double.random(in: 0..<1.0)
        let success = roll < successChance

        let repChange: Int
        if success {
            playerPoints += 1
            playerPointsWon += 1
            repChange = -GameConstants.MatchActions.hookCallSuccessRepPenalty
        } else {
            opponentPoints += 1
            opponentPointsWon += 1
            repChange = -GameConstants.MatchActions.hookCallCaughtRepPenalty
        }
        currentReputation += repChange

        pendingActionEvents.append(.hookCallAttempt(side: .player, success: success, repChange: repChange))
        return .hookCallResult(success: success, repChange: repChange)
    }

    // MARK: - Action State Queries

    var isSkipping: Bool { skipRequested }

    var canTimeout: Bool {
        timeoutsUsedThisGame == 0 && momentum.opponentStreak >= GameConstants.MatchActions.timeoutMinOpponentStreak
    }

    var canHookCall: Bool {
        hookCallsUsedThisGame == 0 && pointNumber > 0
    }

    var canUseConsumable: Bool {
        consumablesUsedCount < GameConstants.MatchActions.maxConsumablesPerMatch && !availableConsumables.isEmpty
    }

    var remainingConsumables: [Consumable] {
        availableConsumables
    }

    var opponentCurrentStreak: Int {
        momentum.opponentStreak
    }
}
