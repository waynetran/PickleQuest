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
        static let startingStatTotal: Int = 165 // distributed across 11 stats
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

        // Doubles dink phase
        static let doublesDinkMinShots: Int = 3
        static let doublesDinkMaxShots: Int = 15
        static let dinkWinnerChance: Double = 0.05
        static let dinkErrorChance: Double = 0.05
        static let dinkForcedErrorChance: Double = 0.02
        static let doublesMaxRallyShots: Int = 45
    }

    // MARK: - Equipment
    enum Equipment {
        static let maxSlots: Int = 6
        static let maxBonusPerStat: Int = 25 // legendary max single-stat bonus
        static let setChanceRare = 0.15
        static let setChanceEpic = 0.30
        static let setChanceLegendary = 0.50
    }

    // MARK: - Equipment Level
    enum EquipmentLevel {
        static let statPercentPerLevel: Double = 0.05  // +5% flat per level
        static let baseUpgradeCost: Int = 25
        static let upgradeCostExponent: Double = 1.4
        static let rarityUpgradeMultiplier: [EquipmentRarity: Double] = [
            .common: 1.0,
            .uncommon: 1.5,
            .rare: 2.5,
            .epic: 4.0,
            .legendary: 7.0
        ]
        static let levelSellBonus: Int = 5

        static func upgradeCost(rarity: EquipmentRarity, targetLevel: Int) -> Int {
            let rarityMult = rarityUpgradeMultiplier[rarity] ?? 1.0
            let base = Double(baseUpgradeCost) * pow(Double(targetLevel), upgradeCostExponent) * rarityMult
            return Int(base.rounded())
        }
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
        static let minEnergy = 0.0           // no floor — energy can reach 0%
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
        static let matchWinBaseReward: Int = 0   // Rec matches: no coins (tournaments/wagers only)
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

    // MARK: - Drill Physics (Interactive Mini-Games)
    enum DrillPhysics {
        static let gravity: CGFloat = 1.2           // logical units/sec² (low for floaty, arcade feel)
        static let bounceDamping: CGFloat = 0.6     // vz retained after bounce
        static let courtFriction: CGFloat = 0.85    // vx/vy retained after bounce
        static let netLogicalHeight: CGFloat = 0.08 // net height in court-space units
        static let spinCurveFactor: CGFloat = 0.15  // max lateral curve from spin stat

        // Shot speeds (court units per second)
        static let baseShotSpeed: CGFloat = 0.35
        static let maxShotSpeed: CGFloat = 0.90
        static let dinkShotSpeed: CGFloat = 0.20

        // Player hitbox (court-space units)
        static let baseHitboxRadius: CGFloat = 0.144     // reach (paddle + arm extension)
        static let positioningHitboxBonus: CGFloat = 0.048 // bonus from positioning stat

        // Player movement (court units per second)
        static let baseMoveSpeed: CGFloat = 0.4
        static let maxMoveSpeedBonus: CGFloat = 0.8

        // Shot quality
        static let heightPowerBonus: CGFloat = 0.3        // bonus power for high ball (overhead smash)

        // Drill ball count
        static let drillBallCount: Int = 10
        static let feedDelay: TimeInterval = 0.8

        // Serve swipe
        static let serveSwipeMinDistance: CGFloat = 50
        static let serveSwipeMaxPower: CGFloat = 200
        static let serveSwipeAngleRange: CGFloat = 0.5

        // Stamina (sprint system in drills — separate from persistent energy)
        static let maxStamina: CGFloat = 100
        static let sprintDrainRate: CGFloat = 25        // per second while sprinting
        static let staminaRecoveryRate: CGFloat = 5     // per second while walking/standing
        static let staminaRecoveryDelay: CGFloat = 1.5  // seconds after sprint ends before recovery
        static let maxSprintSpeedBoost: CGFloat = 1.0   // 100% max speed boost
        static let playerPositioningOffset: CGFloat = 0.04 // half-sprite court units for kitchen clamp

        // Cone targets (accuracy drill)
        static let accuracyConeTargets: [(nx: CGFloat, ny: CGFloat)] = [
            (0.25, 0.75), (0.50, 0.85), (0.75, 0.75)
        ]

        // Cone targets (return of serve) — kitchen sidelines, deep middle, deep baseline sides
        static let returnOfServeConeTargets: [(nx: CGFloat, ny: CGFloat)] = [
            (0.12, 0.58),   // left kitchen sideline
            (0.88, 0.58),   // right kitchen sideline
            (0.50, 0.90),   // deep center
            (0.15, 0.88),   // deep baseline left
            (0.85, 0.88),   // deep baseline right
        ]

        static let coneHitRadius: CGFloat = 0.10
    }

    // MARK: - Coaching
    enum Coaching {
        static let coachCourtPercentage: Double = 0.5 // ~50% of courts get a coach
        static let alphaCoachChance: Double = 0.8 // 80% of coach courts use the alpha NPC
        static let alphaDefeatedDiscount: Double = 0.5 // 50% off when alpha is defeated
        static let coachLevelFees: [Int: Int] = [ // level → fee (realistic coaching rates)
            1: 40, 2: 75, 3: 150, 4: 500, 5: 1500
        ]
        static let coachMaxEnergy: Double = 100.0
        static let coachDrainPerSession: Double = 20.0  // each session drains 20% coach energy
    }

    // MARK: - Daily Challenges
    enum DailyChallenge {
        static let challengesPerDay: Int = 3
        static let individualCoinReward: ClosedRange<Int> = 50...200
        static let individualXPReward: ClosedRange<Int> = 25...100
        static let completionBonusCoins: Int = 500
    }

    // MARK: - Wager
    enum Wager {
        static let wagerTiers: [Int] = [0, 50, 100, 250, 500]
        static let npcMaxConsecutiveLosses: Int = 3
        static let hustlerWagerRange: ClosedRange<Int> = 200...1000
        static let hustlerMinSUPRRejectThreshold: Double = 0.5
        static let hustlerBeatRepBonus: Int = 25
        static let hustlerCount: Int = 3
        static let regularNPCMinPurse: Int = 0
        static let regularNPCMaxPurse: Int = 200
        static let hustlerMinPurse: Int = 1000
        static let hustlerMaxPurse: Int = 3000
        static let hustlerResetInterval: TimeInterval = 3600 // 1 hour
    }

    // MARK: - Gear Drops
    enum GearDrop {
        // Field drops
        static let fieldSpawnIntervalMin: TimeInterval = 900   // 15 minutes minimum
        static let fieldSpawnIntervalMax: TimeInterval = 1200  // 20 minutes maximum
        static let fieldDespawnTime: TimeInterval = 1800       // 30 minutes
        static let maxActiveFieldDrops: Int = 3
        static let spawnRadius: Double = 300                   // meters
        static let pickupRadius: Double = 50                   // meters
        static let annotationVisibilityRadius: Double = 500    // meters — only show on map when nearby

        // Court caches
        static let courtCacheCooldown: TimeInterval = 14400    // 4 hours
        static let courtDifficultyRarityBoost: [NPCDifficulty: Double] = [
            .beginner: 0.0,
            .intermediate: 0.05,
            .advanced: 0.10,
            .expert: 0.15,
            .master: 0.25
        ]

        // Trail drops
        static let trailWaypointCountRange: ClosedRange<Int> = 5...8
        static let trailTimeLimit: TimeInterval = 7200         // 2 hours
        static let trailSpacing: Double = 200                  // meters between waypoints

        // Contested drops
        static let contestedMaxPerDay: Int = 2
        static let contestedVisibilityRadius: Double = 2000    // meters

        // Fog stashes
        static let fogStashChancePerCell: Double = 0.02        // 2% per newly revealed cell
        static let remotenessRarityBoost: Double = 0.15        // max boost for isolated cells
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
