import Foundation

@MainActor
@Observable
final class TrainingViewModel {
    private let trainingService: TrainingService
    private let skillService: SkillService

    let coach: Coach
    var trainingResult: TrainingResult?
    var isSimulating = false
    var errorMessage: String?
    var animationComplete = false
    var interactiveDrillResult: InteractiveDrillResult?
    var showInteractiveDrill = false
    var unlockedSkillName: String?
    var unlockedSkillIcon: String?

    init(trainingService: TrainingService, skillService: SkillService, coach: Coach) {
        self.trainingService = trainingService
        self.skillService = skillService
        self.coach = coach
    }

    private static let coachLevelGains: [Int: Int] = [
        1: 2, 2: 3, 3: 4, 4: 6, 5: 8
    ]

    /// Expected stat gain based on both player and coach energy.
    func expectedGain(playerEnergy: Double, coachEnergy: Double) -> Int {
        let baseGain = Self.coachLevelGains[coach.level] ?? coach.level
        return max(1, Int(round(Double(baseGain) * (playerEnergy / 100.0) * (coachEnergy / 100.0))))
    }

    func startDrill(player: inout Player) async {
        let stat = coach.dailySpecialtyStat
        let drillType = coach.dailyDrillType
        let drill = TrainingDrill(type: drillType)
        errorMessage = nil
        animationComplete = false

        // Check energy
        guard player.currentEnergy >= drill.energyCost else {
            errorMessage = "Not enough energy (\(Int(drill.energyCost))% needed)"
            return
        }

        // Check coach energy
        let coachEnergy = player.coachingRecord.coachRemainingEnergy(coachID: coach.id)
        guard coachEnergy > 0 else {
            errorMessage = coach.dialogue.onExhausted
            return
        }

        // Check cost
        let fee = player.coachingRecord.fee(for: coach)
        guard player.wallet.coins >= fee else {
            errorMessage = "Not enough coins (\(fee) needed)"
            return
        }

        // Deduct costs
        player.wallet.coins -= fee
        player.energy = max(
            GameConstants.PersistentEnergy.minEnergy,
            player.currentEnergy - drill.energyCost
        )
        player.lastMatchDate = Date()

        isSimulating = true

        // Run simulation with both energies
        let result = await trainingService.performDrill(
            drill,
            stat: stat,
            coachLevel: coach.level,
            playerEnergy: player.currentEnergy,
            coachEnergy: coachEnergy
        )

        // Drain coach energy
        player.coachingRecord.drainCoach(
            coachID: coach.id,
            amount: GameConstants.Coaching.coachDrainPerSession
        )

        // Apply stat gain
        let currentValue = player.stats.stat(stat)
        player.stats.setStat(stat, value: min(currentValue + result.statGainAmount, GameConstants.Stats.maxValue))
        player.coachingRecord.recordSession(coachID: coach.id, stat: stat, amount: result.statGainAmount)

        // Award XP (use addXP for proper skill point granting)
        _ = player.progression.addXP(result.xpEarned)

        // Track skill lesson progress
        progressSkillLesson(drillType: drillType, player: &player)

        trainingResult = result
        isSimulating = false
    }

    func onAnimationComplete() {
        animationComplete = true
    }

    func clearResult() {
        trainingResult = nil
        errorMessage = nil
        animationComplete = false
        interactiveDrillResult = nil
        showInteractiveDrill = false
    }

    // MARK: - Interactive Drill

    /// Validates and deducts costs for an interactive drill. Returns true if ready to start.
    func prepareInteractiveDrill(player: inout Player) -> Bool {
        let drill = TrainingDrill(type: coach.dailyDrillType)
        errorMessage = nil

        // Check energy
        guard player.currentEnergy >= drill.energyCost else {
            errorMessage = "Not enough energy (\(Int(drill.energyCost))% needed)"
            return false
        }

        // Check coach energy
        let coachEnergy = player.coachingRecord.coachRemainingEnergy(coachID: coach.id)
        guard coachEnergy > 0 else {
            errorMessage = coach.dialogue.onExhausted
            return false
        }

        // Check cost
        let fee = player.coachingRecord.fee(for: coach)
        guard player.wallet.coins >= fee else {
            errorMessage = "Not enough coins (\(fee) needed)"
            return false
        }

        // Deduct costs upfront
        player.wallet.coins -= fee
        player.energy = max(
            GameConstants.PersistentEnergy.minEnergy,
            player.currentEnergy - drill.energyCost
        )
        player.lastMatchDate = Date()

        // Drain coach energy
        player.coachingRecord.drainCoach(
            coachID: coach.id,
            amount: GameConstants.Coaching.coachDrainPerSession
        )

        showInteractiveDrill = true
        return true
    }

    /// Apply results from completed interactive drill.
    func completeInteractiveDrill(result: InteractiveDrillResult, player: inout Player) {
        // Apply stat gain
        let currentValue = player.stats.stat(result.statGained)
        player.stats.setStat(result.statGained, value: min(currentValue + result.statGainAmount, GameConstants.Stats.maxValue))
        player.coachingRecord.recordSession(coachID: coach.id, stat: result.statGained, amount: result.statGainAmount)

        // Award XP (use addXP for proper skill point granting)
        _ = player.progression.addXP(result.xpEarned)

        // Track skill lesson progress
        progressSkillLesson(drillType: coach.dailyDrillType, player: &player)

        interactiveDrillResult = result
    }

    // MARK: - Skill Lesson Progress

    /// After a drill, increment lesson progress for the best matching unacquired skill.
    private func progressSkillLesson(drillType: DrillType, player: inout Player) {
        unlockedSkillName = nil
        unlockedSkillIcon = nil

        // Find unacquired skills that this drill teaches (matching player type)
        let candidates = SkillDefinition.forPlayerType(player.playerType).filter { def in
            def.teachingDrills.contains(drillType)
                && !player.skills.contains(where: { $0.skillID == def.id })
                && player.progression.level >= def.requiredLevel
        }

        guard let target = candidates.first else { return }

        // Increment lesson progress
        let coachKey = coach.id.uuidString
        var progress = player.skillLessonProgress[target.id] ?? SkillLessonProgress(lessonsCompleted: 0, coachIDs: [])
        progress.lessonsCompleted += 1
        progress.coachIDs.insert(coachKey)
        player.skillLessonProgress[target.id] = progress

        // Track cumulative lessons per coach
        player.coachingRecord.totalLessonsPerCoach[coachKey, default: 0] += 1

        // If lessons complete, auto-acquire the skill
        if progress.lessonsCompleted >= GameConstants.Skills.lessonsToAcquire {
            skillService.acquireSkill(target.id, for: &player, via: .coaching)
            player.skillLessonProgress.removeValue(forKey: target.id)
            unlockedSkillName = target.name
            unlockedSkillIcon = target.icon
        }
    }

    /// The drill type teaching a specific skill for this coach's current specialty.
    var currentTeachingSkill: SkillDefinition? {
        let drillType = coach.dailyDrillType
        // Find what skill this drill teaches (excluding already-acquired)
        return nil // Populated dynamically based on player in the view
    }

    /// Get the skill this coach is currently teaching for a given player.
    func teachingSkill(for player: Player) -> (skill: SkillDefinition, progress: SkillLessonProgress)? {
        let drillType = coach.dailyDrillType
        let candidates = SkillDefinition.forPlayerType(player.playerType).filter { def in
            def.teachingDrills.contains(drillType)
                && !player.skills.contains(where: { $0.skillID == def.id })
                && player.progression.level >= def.requiredLevel
        }
        guard let target = candidates.first else { return nil }
        let progress = player.skillLessonProgress[target.id] ?? SkillLessonProgress(lessonsCompleted: 0, coachIDs: [])
        return (target, progress)
    }
}
