import Foundation

struct MockSkillService: SkillService {
    func availableSkills(for playerType: PlayerType) -> [SkillDefinition] {
        SkillDefinition.forPlayerType(playerType)
    }

    func canAcquire(_ skillID: SkillID, player: Player) -> Bool {
        guard let def = SkillDefinition.definition(for: skillID) else { return false }
        // Already acquired?
        if player.skills.contains(where: { $0.skillID == skillID }) { return false }
        // Level requirement met?
        if player.progression.level < def.requiredLevel { return false }
        // Player type compatible?
        if let exclusive = def.exclusiveTo, exclusive != player.playerType { return false }
        return true
    }

    func acquireSkill(_ skillID: SkillID, for player: inout Player, via source: SkillAcquisitionSource) {
        guard canAcquire(skillID, player: player) else { return }
        let skill = PlayerSkill(
            skillID: skillID,
            rank: 1,
            acquiredDate: Date(),
            acquiredVia: source
        )
        player.skills.append(skill)
    }

    func canUpgrade(_ skillID: SkillID, player: Player) -> Bool {
        guard let existing = player.skills.first(where: { $0.skillID == skillID }) else { return false }
        guard existing.rank < GameConstants.Skills.maxSkillRank else { return false }
        guard player.progression.availableSkillPoints >= 1 else { return false }
        return true
    }

    func upgradeSkill(_ skillID: SkillID, for player: inout Player) -> Bool {
        guard canUpgrade(skillID, player: player) else { return false }
        guard let index = player.skills.firstIndex(where: { $0.skillID == skillID }) else { return false }
        player.skills[index].rank += 1
        player.progression.availableSkillPoints -= 1
        return true
    }
}
