import Foundation

struct PlayerProgression: Codable, Equatable, Sendable {
    var level: Int
    var currentXP: Int
    var totalXPEarned: Int
    var availableStatPoints: Int

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
            availableStatPoints += statPoints
            rewards.append(LevelUpReward(newLevel: level, statPointsGained: statPoints))
        }
        return rewards
    }

    static let starter = PlayerProgression(
        level: GameConstants.Stats.startingLevel,
        currentXP: 0,
        totalXPEarned: 0,
        availableStatPoints: 0
    )
}

struct LevelUpReward: Equatable, Sendable {
    let newLevel: Int
    let statPointsGained: Int
}
