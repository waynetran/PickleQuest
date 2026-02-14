import Foundation

protocol NPCService: Sendable {
    func getAllNPCs() async -> [NPC]
    func getNPC(by id: UUID) async -> NPC?
    func getNPCs(forDifficulty difficulty: NPCDifficulty) async -> [NPC]
}
