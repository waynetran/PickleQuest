import Foundation

struct PlayerProgression: Codable, Equatable, Sendable {
    var level: Int
    var currentXP: Int
    var totalXPEarned: Int
    var availableStatPoints: Int
    var availableSkillPoints: Int = 0

    enum CodingKeys: String, CodingKey {
        case level, currentXP, totalXPEarned, availableStatPoints, availableSkillPoints
    }

    init(level: Int, currentXP: Int, totalXPEarned: Int, availableStatPoints: Int, availableSkillPoints: Int = 0) {
        self.level = level
        self.currentXP = currentXP
        self.totalXPEarned = totalXPEarned
        self.availableStatPoints = availableStatPoints
        self.availableSkillPoints = availableSkillPoints
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level = try c.decode(Int.self, forKey: .level)
        currentXP = try c.decode(Int.self, forKey: .currentXP)
        totalXPEarned = try c.decode(Int.self, forKey: .totalXPEarned)
        availableStatPoints = try c.decode(Int.self, forKey: .availableStatPoints)
        availableSkillPoints = try c.decodeIfPresent(Int.self, forKey: .availableSkillPoints) ?? 0
    }

    var xpToNextLevel: Int {
        GameConstants.XP.xpRequired(forLevel: level + 1)
    }

    var xpProgress: Double {
        let required = xpToNextLevel
        guard required > 0 else { return 1.0 }
        let currentLevelXP = GameConstants.XP.xpRequired(forLevel: level)
        let progressXP = currentXP - currentLevelXP
        let neededXP = required - currentLevelXP
        guard neededXP > 0 else { return 1.0 }
        return Double(progressXP) / Double(neededXP)
    }

    mutating func addXP(_ amount: Int) -> [LevelUpReward] {
        currentXP += amount
        totalXPEarned += amount
        var rewards: [LevelUpReward] = []
        while currentXP >= xpToNextLevel && level < GameConstants.Stats.maxLevel {
            level += 1
            let statPoints = GameConstants.Stats.statPointsPerLevel
            let skillPoints = GameConstants.Skills.skillPointsPerLevel
            availableStatPoints += statPoints
            availableSkillPoints += skillPoints
            rewards.append(LevelUpReward(newLevel: level, statPointsGained: statPoints, skillPointsGained: skillPoints))
        }
        return rewards
    }

    static let starter = PlayerProgression(
        level: GameConstants.Stats.startingLevel,
        currentXP: 0,
        totalXPEarned: 0,
        availableStatPoints: 0,
        availableSkillPoints: 0
    )
}

struct LevelUpReward: Equatable, Sendable {
    let newLevel: Int
    let statPointsGained: Int
    let skillPointsGained: Int
}
