import Foundation

protocol SkillService: Sendable {
    func availableSkills(for playerType: PlayerType) -> [SkillDefinition]
    func acquireSkill(_ skillID: SkillID, for player: inout Player, via source: SkillAcquisitionSource)
    func upgradeSkill(_ skillID: SkillID, for player: inout Player) -> Bool
    func canAcquire(_ skillID: SkillID, player: Player) -> Bool
    func canUpgrade(_ skillID: SkillID, player: Player) -> Bool
}
