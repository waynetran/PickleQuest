import Foundation

protocol DailyChallengeService: Sendable {
    func getTodaysChallenges() async -> DailyChallengeState
    func generateNewChallenges() async -> DailyChallengeState
    func checkAndResetIfNeeded(current: DailyChallengeState) async -> DailyChallengeState
}
