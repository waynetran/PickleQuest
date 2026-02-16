import Foundation

protocol NPCService: Sendable {
    func getAllNPCs() async -> [NPC]
    func getNPC(by id: UUID) async -> NPC?
    func getNPCs(forDifficulty difficulty: NPCDifficulty) async -> [NPC]
    func getHustlerNPCs() async -> [NPC]
    func getPurse(npcID: UUID) async -> Int
    func deductPurse(npcID: UUID, amount: Int) async
    func addToPurse(npcID: UUID, amount: Int) async
}
