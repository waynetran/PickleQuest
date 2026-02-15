import Foundation

protocol CoachService: Sendable {
    func getCoachAtCourt(_ courtID: UUID) async -> Coach?
    func getAllCoaches() async -> [UUID: Coach]
    func assignCoaches(to courtIDs: [UUID], courtDifficulties: [UUID: NPCDifficulty]) async
    /// Returns true if this court uses its alpha NPC as the coach (80% of courts)
    func isAlphaCoachCourt(_ courtID: UUID) async -> Bool
    /// Register an alpha-derived coach for a court
    func setAlphaCoach(_ coach: Coach, courtID: UUID) async
}
