import Foundation

enum GameConstants {
    // MARK: - Stats
    enum Stats {
        static let minValue: Int = 1
        static let maxValue: Int = 99
        static let hardCap: Int = 99
        static let linearCap: Int = 60
        static let midCap: Int = 80
        static let linearScale: Double = 1.0
        static let midScale: Double = 0.7
        static let highScale: Double = 0.4
        static let startingLevel: Int = 1
        static let maxLevel: Int = 50
        static let statPointsPerLevel: Int = 3
        static let startingStatTotal: Int = 150 // distributed across 10 stats
    }

    // MARK: - DUPR Mapping
    enum DUPR {
        static let minRating: Double = 2.0
        static let maxRating: Double = 8.0
        /// Maps average stat (1-99) to DUPR (2.0-8.0)
        static func rating(fromAverageStat avg: Double) -> Double {
            let clamped = min(max(avg, 1.0), 99.0)
            return minRating + (clamped - 1.0) / 98.0 * (maxRating - minRating)
        }
    }

    // MARK: - DUPR Rating System
    enum DUPRRating {
        // Rating bounds
        static let minRating: Double = 2.00
        static let maxRating: Double = 8.00
        static let startingRating: Double = 2.00

        // K-factor tiers (based on reliability)
        static let kFactorNew: Double = 64.0       // reliability < 0.3
        static let kFactorDeveloping: Double = 32.0 // reliability 0.3-0.7
        static let kFactorEstablished: Double = 16.0 // reliability > 0.7

        // Reliability weights
        static let depthWeight: Double = 0.4
        static let breadthWeight: Double = 0.3
        static let recencyWeight: Double = 0.3

        // Reliability thresholds
        static let depthMax: Int = 30           // matches for 1.0 depth
        static let breadthMax: Int = 15         // unique opponents for 1.0 breadth
        static let recencyFullDays: Int = 7     // days for 1.0 recency
        static let recencyDecayDays: Int = 90   // days for minimum recency
        static let recencyMinimum: Double = 0.3 // floor for recency component

        // Margin-of-victory scaling (for actualScore)
        static let marginExponent: Double = 1.5  // controls curve steepness
        static let pointsToWin: Double = 11.0    // reference for normalization

        // Elo parameters
        static let eloScaleFactor: Double = 400.0
        static let duprToEloScale: Double = 100.0 // 1.0 DUPR gap = 100 Elo-equivalent
        static let ratingChangeDivisor: Double = 200.0 // scales raw Elo to DUPR range

        // Auto-unrate threshold
        static let maxRatedGap: Double = 1.0
    }

    // MARK: - Match
    enum Match {
        static let defaultPointsToWin: Int = 11
        static let defaultGamesToWin: Int = 2
        static let winByTwo: Bool = true
        static let maxPoints: Int = 21 // safety cap per game
        static let serveSwitchInterval: Int = 2 // singles: every 2 points
    }

    // MARK: - Fatigue
    enum Fatigue {
        static let maxEnergy: Double = 100.0
        static let baseEnergyDrainPerShot: Double = 0.3
        static let rallyLengthDrainMultiplier: Double = 0.05
        static let threshold1: Double = 70.0 // mild fatigue
        static let threshold2: Double = 50.0 // moderate fatigue
        static let threshold3: Double = 30.0 // severe fatigue
        static let penalty1: Double = 0.03  // -3% stats at threshold1
        static let penalty2: Double = 0.08  // -8% stats at threshold2
        static let penalty3: Double = 0.15  // -15% stats at threshold3
        static let staminaReductionFactor: Double = 0.01 // per stamina point
    }

    // MARK: - Momentum
    enum Momentum {
        static let streakThresholds: [Int: Double] = [
            2: 0.02,  // 2 in a row: +2%
            3: 0.04,
            4: 0.05,
            5: 0.06,
            6: 0.07   // 6+: +7%
        ]
        static let negativePenalties: [Int: Double] = [
            2: -0.01,
            3: -0.02,
            4: -0.03,
            5: -0.05  // 5+ lost in a row: -5%
        ]
    }

    // MARK: - Rally
    enum Rally {
        static let baseAceChance: Double = 0.05
        static let powerAceScaling: Double = 0.002 // per power point
        static let reflexDefenseScale: Double = 0.0015
        static let minRallyShots: Int = 1
        static let maxRallyShots: Int = 30
        static let baseWinnerChance: Double = 0.15
        static let baseErrorChance: Double = 0.12
    }

    // MARK: - Equipment
    enum Equipment {
        static let maxSlots: Int = 6
        static let maxBonusPerStat: Int = 25 // legendary max single-stat bonus
        static let setChanceRare = 0.15
        static let setChanceEpic = 0.30
        static let setChanceLegendary = 0.50
    }

    // MARK: - Loot
    enum Loot {
        static let winDropCount: Int = 1
        static let lossDropChance: Double = 0.3
        // Difficulty boosts: higher difficulty → better rarity chances
        static let difficultyRarityBoost: [NPCDifficulty: Double] = [
            .beginner: 0.0,
            .intermediate: 0.05,
            .advanced: 0.10,
            .expert: 0.15,
            .master: 0.25
        ]
        // Bonus stats per rarity
        static let bonusStatCount: [EquipmentRarity: ClosedRange<Int>] = [
            .common: 1...2,
            .uncommon: 1...3,
            .rare: 2...3,
            .epic: 2...4,
            .legendary: 3...4
        ]
        // SUPR-scaled loot: beating stronger opponents boosts rare drops
        static let suprGapRarityBoost = 0.10  // per 1.0 SUPR gap overcome
        static let maxSuprLootBoost = 0.25    // cap
    }

    // MARK: - Reputation
    enum Reputation {
        // Win constants
        static let baseWinRep = 10
        static let upsetWinBonus = 15.0        // per 1.0 SUPR gap (beating stronger)
        static let expectedWinReduction = 5.0  // per 1.0 SUPR gap (beating weaker, reduces gain)
        static let minWinRep = 3               // always some rep for winning

        // Loss: respect gain (lost to much stronger)
        static let respectThreshold = 0.5      // SUPR gap where respect kicks in on loss
        static let respectGainRate = 2.0       // per 1.0 SUPR gap
        static let maxRespectGain = 3          // cap on respect gain

        // Loss: rep penalty (lost to weaker)
        static let baseLossRep = 5             // base loss when losing to weaker
        static let upsetLossMultiplier = 10.0  // per 1.0 SUPR gap (losing to weaker)
        static let maxLossRep = 30             // cap
    }

    // MARK: - Durability
    enum Durability {
        static let baseLossWear = 0.08       // 8% per loss
        static let baseWinWear = 0.03        // 3% per win (shoes + paddle only)
        static let suprGapWearBonus = 0.04   // +4% per 1.0 SUPR gap (stronger opp)
        static let maxWearPerMatch = 0.15    // cap 15%
    }

    // MARK: - Persistent Energy
    enum PersistentEnergy {
        static let maxEnergy = 100.0
        static let minEnergy = 50.0          // floor between matches
        static let baseLossDrain = 10.0      // -10% on loss
        static let suprGapDrainBonus = 5.0   // +5% per 1.0 SUPR gap
        static let maxDrainPerMatch = 20.0
        static let recoveryPerMinute = 1.0   // +1% real time
    }

    // MARK: - Store
    enum Store {
        static let shopSize: Int = 8
        static let consumableSlots: Int = 2
        static let refreshCost: Int = 50
        static let priceRange: [EquipmentRarity: ClosedRange<Int>] = [
            .common: 50...100,
            .uncommon: 100...250,
            .rare: 250...500,
            .epic: 500...1000,
            .legendary: 1000...2500
        ]
        // Store has slightly better rarity odds than loot
        static let storeRarityWeights: [EquipmentRarity: Double] = [
            .common: 0.30,
            .uncommon: 0.35,
            .rare: 0.20,
            .epic: 0.12,
            .legendary: 0.03
        ]
    }

    // MARK: - Economy
    enum Economy {
        static let startingCoins: Int = 500
        static let matchWinBaseReward: Int = 100
        static let matchLossBaseReward: Int = 0
        static let difficultyBonusMultiplier: Double = 0.5
    }

    // MARK: - Match Actions
    enum MatchActions {
        static let timeoutEnergyRestore: Double = 15.0
        static let timeoutMinOpponentStreak: Int = 2
        static let hookCallBaseChance: Double = 0.3
        static let hookCallRepBonusPerPoint: Double = 0.001
        static let hookCallMaxChance: Double = 0.8
        static let hookCallSuccessRepPenalty: Int = 5
        static let hookCallCaughtRepPenalty: Int = 20
        static let maxConsumablesPerMatch: Int = 3
        static let resignFrequentThreshold: Int = 3
        static let resignFrequentRepPenalty: Int = 10
        static let resignCheckWindow: Int = 10
    }

    // MARK: - Court Progression
    enum CourtProgression {
        static let singlesNPCRange: ClosedRange<Int> = 6...8
        static let alphaStatScale: Double = 1.3
        static let alphaStatCap: Int = 75
        static let alphaRewardMultiplier: Double = 5.0
        static let alphaLootCount: Int = 3
        static let storeDiscountPercent: Double = 0.20
    }

    // MARK: - Doubles
    enum Doubles {
        static let compositeStatWeight: Double = 0.5  // equal weight per partner
        static let startServerNumber: Int = 2         // game starts "0-0-2"
    }

    // MARK: - Tournament
    enum Tournament {
        static let bracketSize: Int = 4
        static let xpMultiplier: Double = 1.5
        static let coinMultiplier: Double = 2.0
        static let winnerLegendaryCount: Int = 1
        static let winnerEpicCount: Int = 2
        static let participationLootCount: Int = 1
    }

    // MARK: - Training
    enum Training {
        static let drillEnergyCost: Double = 15.0 // 15% persistent energy
        static let baseTrainingXP: Int = 50
        static let drillAnimationDuration: Double = 4.0
    }

    // MARK: - Coaching
    enum Coaching {
        static let coachCourtPercentage: Double = 0.5 // ~50% of courts get a coach
        static let alphaCoachChance: Double = 0.8 // 80% of coach courts use the alpha NPC
        static let alphaDefeatedDiscount: Double = 0.5 // 50% off when alpha is defeated
        static let sessionsPerCoachPerDay: Int = 1
        static let coachLevelFees: [Int: Int] = [ // level → base fee
            1: 200, 2: 500, 3: 1000, 4: 2000, 5: 3000
        ]
        static let feeDoublePerExistingBoost: Double = 2.0 // fee doubles per existing boost
        static let maxCoachingBoostPerStat: Int = 5
    }

    // MARK: - Daily Challenges
    enum DailyChallenge {
        static let challengesPerDay: Int = 3
        static let individualCoinReward: ClosedRange<Int> = 50...200
        static let individualXPReward: ClosedRange<Int> = 25...100
        static let completionBonusCoins: Int = 500
    }

    // MARK: - XP
    enum XP {
        static let baseXPPerMatch: Int = 50
        static let winBonusXP: Int = 30
        static let levelUpBase: Int = 100
        static let levelUpGrowthRate: Double = 1.3
        /// XP required to reach a given level
        static func xpRequired(forLevel level: Int) -> Int {
            guard level > 1 else { return 0 }
            return Int(Double(levelUpBase) * pow(levelUpGrowthRate, Double(level - 2)))
        }
    }
}
