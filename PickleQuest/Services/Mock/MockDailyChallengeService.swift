import Foundation

actor MockDailyChallengeService: DailyChallengeService {
    private var currentState: DailyChallengeState?

    func getTodaysChallenges() async -> DailyChallengeState {
        if let state = currentState, Calendar.current.isDateInToday(state.lastResetDate) {
            return state
        }
        return await generateNewChallenges()
    }

    func generateNewChallenges() async -> DailyChallengeState {
        let count = GameConstants.DailyChallenge.challengesPerDay
        var selectedTypes: [ChallengeType] = []
        var available = ChallengeType.allCases.shuffled()

        while selectedTypes.count < count && !available.isEmpty {
            selectedTypes.append(available.removeFirst())
        }

        let challenges = selectedTypes.map { type in
            DailyChallenge(
                id: UUID(),
                type: type,
                targetCount: type.targetCount,
                currentCount: 0,
                coinReward: Int.random(in: GameConstants.DailyChallenge.individualCoinReward),
                xpReward: Int.random(in: GameConstants.DailyChallenge.individualXPReward)
            )
        }

        let state = DailyChallengeState(
            challenges: challenges,
            lastResetDate: Date(),
            bonusClaimed: false
        )
        currentState = state
        return state
    }

    func checkAndResetIfNeeded(current: DailyChallengeState) async -> DailyChallengeState {
        if Calendar.current.isDateInToday(current.lastResetDate) {
            currentState = current
            return current
        }
        return await generateNewChallenges()
    }
}
