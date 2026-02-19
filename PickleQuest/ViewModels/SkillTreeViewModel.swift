import Foundation

@MainActor
@Observable
final class SkillTreeViewModel {
    private let skillService: SkillService

    var sharedSkills: [SkillDefinition] = []
    var exclusiveSkills: [SkillDefinition] = []
    var playerSkills: [SkillID: PlayerSkill] = [:]
    var lessonProgress: [SkillID: SkillLessonProgress] = [:]
    var availableSkillPoints: Int = 0
    var playerLevel: Int = 1
    var playerType: PlayerType = .allRounder

    init(skillService: SkillService) {
        self.skillService = skillService
    }

    func load(player: Player) {
        let allSkills = skillService.availableSkills(for: player.playerType)
        sharedSkills = allSkills.filter { $0.exclusiveTo == nil }
        exclusiveSkills = allSkills.filter { $0.exclusiveTo != nil }
        playerSkills = Dictionary(uniqueKeysWithValues: player.skills.map { ($0.skillID, $0) })
        lessonProgress = player.skillLessonProgress
        availableSkillPoints = player.progression.availableSkillPoints
        playerLevel = player.progression.level
        playerType = player.playerType
    }

    func isAcquired(_ skillID: SkillID) -> Bool {
        playerSkills[skillID] != nil
    }

    func rank(for skillID: SkillID) -> Int {
        playerSkills[skillID]?.rank ?? 0
    }

    func isLocked(_ def: SkillDefinition) -> Bool {
        if isAcquired(def.id) { return false }
        if playerLevel < def.requiredLevel { return true }
        if let exclusive = def.exclusiveTo, exclusive != playerType { return true }
        return false
    }

    func canUpgrade(_ skillID: SkillID, player: Player) -> Bool {
        skillService.canUpgrade(skillID, player: player)
    }

    func upgradeSkill(_ skillID: SkillID, player: inout Player) -> Bool {
        let result = skillService.upgradeSkill(skillID, for: &player)
        if result {
            load(player: player)
        }
        return result
    }
}
