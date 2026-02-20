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

        // Margin-based scoring (real DUPR: 0.1 gap ≈ 1.2 points in 11-point game)
        static let pointsPerDUPRGap: Double = 12.0 // expected point margin per 1.0 DUPR gap
        static let performanceCurve: Double = 1.0   // tanh scaling for performance normalization
        static let ratingChangeDivisor: Double = 200.0

        // Lopsidedness discount (real DUPR: 0.625+ gap = less informative)
        static let lopsidedGapThreshold: Double = 0.625 // graduated discount starts here
        static let lopsidedDiscountFloor: Double = 0.3   // K multiplier at maxRatedGap

        // High-level convergence (real DUPR: ratings converge more at 4.0+)
        static let highLevelThreshold: Double = 4.0
        static let highLevelDamping: Double = 0.7 // K multiplier above threshold

        // Auto-unrate threshold
        static let maxRatedGap: Double = 1.5
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
        /// Master knob scaling how much stat differences affect per-shot probabilities.
        /// Higher values create more DUPR separation in point differentials.
        static let statSensitivity: Double = 0.26

        static let baseAceChance: Double = 0.05
        static let powerAceScaling: Double = 0.002 // per power point
        static let reflexDefenseScale: Double = 0.0015
        static let minRallyShots: Int = 1
        static let maxRallyShots: Int = 30
        static let baseWinnerChance: Double = 0.15
        static let baseErrorChance: Double = 0.16

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
        static let maxEquipmentBonusPerStat: Int = 15 // cap any single stat's total equipment contribution
        static let setChanceRare = 0.15
        static let setChanceEpic = 0.30
        static let setChanceLegendary = 0.50
    }

    // MARK: - Equipment Level
    enum EquipmentLevel {
        static let statPercentPerLevel: Double = 0.01  // +1% flat per level (max 1.24x at level 25)
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

    // MARK: - Interactive Match
    enum InteractiveMatch {
        static let pointsToWin = 11
        static let winByMargin = 2
        static let maxScore = 15              // sudden death at 15-15
        static let servePauseDuration: CGFloat = 1.5  // seconds before AI serves
        static let pointOverPauseDuration: CGFloat = 2.0  // show point result
        static let baseXP = 50
        static let winXPBonus = 100
        static let interactiveXPMultiplier = 1.5  // 50% more XP than simulated
    }

    // MARK: - Player Balance (Interactive Match)
    enum PlayerBalance {
        // Forced error: player whiff on hard incoming shots
        static let forcedErrorScale: CGFloat = 0.90
        static let forcedErrorExponent: CGFloat = 2.0
        static let forcedErrorSpeedWeight: CGFloat = 0.55
        static let forcedErrorSpinWeight: CGFloat = 0.15
        static let forcedErrorStretchWeight: CGFloat = 0.30

        // Net fault: chance of hitting net on low-stat shots
        static let netFaultBaseRate: CGFloat = 0.18

        // Shot scatter base (max scatter at stat 1, was hardcoded 0.12)
        static let baseScatter: CGFloat = 0.20
    }

    // MARK: - Drill Physics (Interactive Mini-Games)
    enum DrillPhysics {
        static let gravity: CGFloat = 1.2           // logical units/sec² (low for floaty, arcade feel)
        static let bounceDamping: CGFloat = 0.6     // vz retained after bounce
        static let courtFriction: CGFloat = 0.85    // vx/vy retained after bounce
        static let netLogicalHeight: CGFloat = 0.08 // net height in court-space units
        static let spinCurveFactor: CGFloat = 0.15  // max lateral curve from spin stat

        // Shot speeds (court units per second)
        // baseShotSpeed is the minimum ball speed (power=0). Lower = more stat separation.
        // Must be high enough for the ball to physically cross the court (~0.20 minimum).
        static let baseShotSpeed: CGFloat = 0.25
        static let maxShotSpeed: CGFloat = 0.90
        static let dinkShotSpeed: CGFloat = 0.20

        // Player hitbox (court-space units)
        static let baseHitboxRadius: CGFloat = 0.10      // reach (player must earn through stats)
        static let positioningHitboxBonus: CGFloat = 0.092 // bonus from positioning stat (stat 99 = 0.192)

        // NPC hitbox — larger base so even low-stat NPCs make basic returns
        static let npcBaseHitboxRadius: CGFloat = 0.18
        static let npcHitboxBonus: CGFloat = 0.06        // bonus from max(reflexes, positioning)

        // Pressure hitbox shrink — cumulative per kitchen shot while opponent is deep.
        // Each shot from the kitchen player while NPC stays back shrinks NPC hitbox further.
        static let pressureShrinkPerShot: CGFloat = 0.2800        // hitbox multiplier lost per pressure shot
        static let pressureHitboxMinMultiplier: CGFloat = 0.3000  // floor — can't shrink below 30%
        static let pressureTouchResistMax: CGFloat = 0.8000       // positioning stat 99 resists 80% of shrink
        static let pressurePlayerKitchenNY: CGFloat = 0.38      // player Y threshold to be "at kitchen"
        static let pressureNPCDeepNY: CGFloat = 0.72            // NPC Y threshold to be "deep/back"

        // Height reach — replaces the old hard height gate (0.20).
        // Balls within reach are hittable; excess height adds to 3D distance.
        // Athleticism = avg(speed, reflexes) / 99. Higher DUPR = more athletic = higher reach.
        static let baseHeightReach: CGFloat = 0.05       // minimum reach (low-stat players struggle with high balls)
        static let maxHeightReachBonus: CGFloat = 0.30   // stat 99 adds 0.30 → total 0.35

        /// NPC stat boost disabled — stats now fully driven by base + GlobalMultiplier.
        static let npcStatBoostFraction: CGFloat = 0
        static let npcStatBoostMin: Int = 0

        /// Compute the stat boost for an NPC based on their base stat average.
        static func npcStatBoost(forBaseStatAverage avg: CGFloat) -> Int {
            0
        }

        // Player movement (court units per second)
        static let baseMoveSpeed: CGFloat = 0.2000
        static let maxMoveSpeedBonus: CGFloat = 0.5600

        // NPC move speed DUPR scaling — REMOVED. Speed GlobalMultiplier now handles
        // DUPR scaling of the speed stat, which feeds into the move speed formula.
        // npcMoveSpeedScale kept only for HeadlessMatchSimulator training overrides.

        // MARK: NPC Stat Global Multipliers
        // Scale NPC effective stats by DUPR: DUPR 2.0 uses Low, DUPR 8.0 uses High.
        // Interpolated linearly. Applied after stat boost, before stats are used.
        // Search: "GlobalMultiplier" to find all per-stat multipliers.
        static let npcPowerGlobalMultiplierLow: CGFloat = 0.10
        static let npcPowerGlobalMultiplierHigh: CGFloat = 1.0
        static let npcAccuracyGlobalMultiplierLow: CGFloat = 0.10
        static let npcAccuracyGlobalMultiplierHigh: CGFloat = 1.0
        static let npcSpinGlobalMultiplierLow: CGFloat = 0.10
        static let npcSpinGlobalMultiplierHigh: CGFloat = 1.0
        static let npcSpeedGlobalMultiplierLow: CGFloat = 0.10
        static let npcSpeedGlobalMultiplierHigh: CGFloat = 1.0
        static let npcDefenseGlobalMultiplierLow: CGFloat = 0.10
        static let npcDefenseGlobalMultiplierHigh: CGFloat = 1.0
        static let npcReflexesGlobalMultiplierLow: CGFloat = 0.10
        static let npcReflexesGlobalMultiplierHigh: CGFloat = 1.0
        static let npcPositioningGlobalMultiplierLow: CGFloat = 0.10
        static let npcPositioningGlobalMultiplierHigh: CGFloat = 1.0
        static let npcClutchGlobalMultiplierLow: CGFloat = 0.10
        static let npcClutchGlobalMultiplierHigh: CGFloat = 1.0
        static let npcFocusGlobalMultiplierLow: CGFloat = 0.10
        static let npcFocusGlobalMultiplierHigh: CGFloat = 1.0
        static let npcStaminaGlobalMultiplierLow: CGFloat = 0.10
        static let npcStaminaGlobalMultiplierHigh: CGFloat = 1.0
        static let npcConsistencyGlobalMultiplierLow: CGFloat = 0.10
        static let npcConsistencyGlobalMultiplierHigh: CGFloat = 1.0

        /// Returns the DUPR-interpolated global multiplier for a given stat.
        static func npcGlobalMultiplier(for stat: StatType, dupr: Double) -> CGFloat {
            let frac = CGFloat(max(0, min(1, (dupr - 2.0) / 6.0)))
            let (low, high): (CGFloat, CGFloat)
            switch stat {
            case .power:        (low, high) = (npcPowerGlobalMultiplierLow, npcPowerGlobalMultiplierHigh)
            case .accuracy:     (low, high) = (npcAccuracyGlobalMultiplierLow, npcAccuracyGlobalMultiplierHigh)
            case .spin:         (low, high) = (npcSpinGlobalMultiplierLow, npcSpinGlobalMultiplierHigh)
            case .speed:        (low, high) = (npcSpeedGlobalMultiplierLow, npcSpeedGlobalMultiplierHigh)
            case .defense:      (low, high) = (npcDefenseGlobalMultiplierLow, npcDefenseGlobalMultiplierHigh)
            case .reflexes:     (low, high) = (npcReflexesGlobalMultiplierLow, npcReflexesGlobalMultiplierHigh)
            case .positioning:  (low, high) = (npcPositioningGlobalMultiplierLow, npcPositioningGlobalMultiplierHigh)
            case .clutch:       (low, high) = (npcClutchGlobalMultiplierLow, npcClutchGlobalMultiplierHigh)
            case .focus:        (low, high) = (npcFocusGlobalMultiplierLow, npcFocusGlobalMultiplierHigh)
            case .stamina:      (low, high) = (npcStaminaGlobalMultiplierLow, npcStaminaGlobalMultiplierHigh)
            case .consistency:  (low, high) = (npcConsistencyGlobalMultiplierLow, npcConsistencyGlobalMultiplierHigh)
            }
            return low + frac * (high - low)
        }

        /// Apply global multipliers to a boosted stat value for a given NPC DUPR.
        static func npcScaledStat(_ stat: StatType, base: Int, boost: Int, dupr: Double) -> Int {
            let boosted = CGFloat(min(99, base + boost))
            let mult = npcGlobalMultiplier(for: stat, dupr: dupr)
            return min(99, Int((boosted * mult).rounded()))
        }

        // Shot quality
        static let heightPowerBonus: CGFloat = 0.3        // bonus power for high ball (overhead smash)

        // Overhead smash (high ball attack — punishes kitchen-line play)
        static let smashHeightThreshold: CGFloat = 0.12   // ball height to trigger smash
        static let smashPowerMultiplier: CGFloat = 2.0    // smash adds 2x what power mode adds
        static let smashBounceMultiplier: CGFloat = 1.8   // smash bounces 80% higher than normal
        static let smashArcBonus: CGFloat = 0.15          // steeper descent for realistic overhead angle

        // Drill ball count
        static let drillBallCount: Int = 10
        static let feedDelay: TimeInterval = 0.8

        // Serve swipe
        static let serveSwipeMinDistance: CGFloat = 50
        static let serveSwipeMaxPower: CGFloat = 200
        static let serveSwipeAngleRange: CGFloat = 0.5

        // Stamina (sprint system in drills — separate from persistent energy)
        static let maxStamina: CGFloat = 100
        static let sprintDrainRate: CGFloat = 12        // per second while sprinting
        static let staminaRecoveryRate: CGFloat = 8     // per second while walking/standing
        static let staminaRecoveryDelay: CGFloat = 0.8  // seconds after sprint ends before recovery
        static let powerShotStaminaDrain: CGFloat = 0.12 // fraction of maxStamina per power shot/serve
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

        // NPC error rates (interactive match)
        /// Base error rate on neutral/easy shots (scales with 1 - statFraction).
        /// At stat 1: ~79% unforced errors. At stat 99: ~0%.
        static let npcBaseErrorRate: CGFloat = 0.80
        /// Error scaling from incoming shot difficulty (speed + spin pressure)
        static let npcPowerErrorScale: CGFloat = 0.50
        /// Minimum error rate floor per unit of shot difficulty (even stat 99 NPCs)
        static let npcMinPowerErrorFloor: CGFloat = 0.01
        /// NPC serve fault rate at stat 1 (chance of double fault per serve)
        static let npcBaseServeFaultRate: CGFloat = 0.2409
        /// Exponent for stat→fault scaling: pow(1 - stat/99, exponent).
        /// Higher = steeper curve (more separation between beginner and advanced).
        static let npcServeFaultStatExponent: CGFloat = 3.0

        /// Minimum serve power — ensures even beginners can physically reach the
        /// service box. At 0.42, the arc stays under the 0.85 cap for full-court serves.
        static let serveMinPower: CGFloat = 0.42

        /// Maximum serve power — pickleball serves are underhand, significantly
        /// slower than rally drives. Controls ace rate: lower = fewer aces.
        /// At 0.45, serve speed ≈ 0.60 (vs rally max ~0.90). Tunable training param.
        static let servePowerCap: CGFloat = 0.45

        // MARK: Jump Mechanic
        static let jumpStaminaCost: CGFloat = 15       // per jump (power shot = 20 for comparison)
        static let jumpDuration: CGFloat = 0.45        // total seconds: rise + hang + fall
        static let jumpRiseFraction: CGFloat = 0.33    // first 33% rising
        static let jumpHangFraction: CGFloat = 0.34    // middle 34% at peak
        static let jumpFallFraction: CGFloat = 0.33    // last 33% falling
        static let jumpHeightReachBonus: CGFloat = 0.25 // added to heightReach at peak
        static let jumpSpriteYOffset: CGFloat = 40.0   // max pixel offset at peak (before perspective)
        static let jumpCooldown: CGFloat = 0.3         // seconds after landing before next jump
        static let jumpMinStamina: CGFloat = 10        // minimum stamina to jump
        static let jumpAirMobilityFactor: CGFloat = 0.3 // movement speed multiplier while airborne

        // MARK: NPC Jump
        static let npcJumpAthleticismThreshold: CGFloat = 0.25 // NPC won't attempt below this
        static let npcJumpDecisionLeadTime: CGFloat = 0.3      // seconds before contact to decide
        static let npcJumpChanceScale: CGFloat = 0.8           // max jump chance = athleticism * scale

        // MARK: Kitchen Volley Power
        static let kitchenVolleyMaxBonus: CGFloat = 0.8   // max additional power at net with high ball
        static let kitchenVolleyRange: CGFloat = 0.25     // court distance from net (0.5) for kitchen zone

        // MARK: High Ball Indicator
        static let highBallWarningThreshold: CGFloat = 0.08    // excess height above reach triggers warning
        static let highBallIndicatorDistance: CGFloat = 0.3     // only show when ball within this court distance
    }

    // MARK: - Put-Away Balance
    enum PutAway {
        static let baseReturnRate: CGFloat = 0.3561      // return chance at DUPR 4.0
        static let returnDUPRScale: CGFloat = 0.2452     // change per 1.0 DUPR
        static let returnFloor: CGFloat = 0.0          // min return rate
        static let returnCeiling: CGFloat = 0.65       // max return rate (put-aways are winners)
        static let stretchPenalty: CGFloat = 0.1485      // stretch reduces return rate significantly

        // Accuracy: put-away scatter multiplier (lower = more accurate, put-aways are easy to place)
        static let scatterMultiplier: CGFloat = 0.30
    }

    // MARK: - Smash Balance
    enum Smash {
        static let baseReturnRate: CGFloat = 0.5626     // return chance at DUPR 4.0
        static let returnDUPRScale: CGFloat = 0.2097    // change per 1.0 DUPR
        static let returnFloor: CGFloat = 0.0         // min return rate
        static let returnCeiling: CGFloat = 0.90      // max return rate (after stretch → effective ~80%)
        static let stretchPenalty: CGFloat = 0.1704      // stretch reduces return rate

        // Power: reduced from 2.0 to prevent wild/out-of-bounds shots
        static let powerMultiplier: CGFloat = 1.5
    }

    // MARK: - NPC Strategy
    enum NPCStrategy {
        // Shot difficulty factor weights (must sum to 1.0)
        static let reachStretchWeight: CGFloat = 0.35
        static let incomingSpeedWeight: CGFloat = 0.30
        static let ballHeightWeight: CGFloat = 0.15
        static let spinPressureWeight: CGFloat = 0.20

        // Ball height thresholds for difficulty assessment
        static let lowBallThreshold: CGFloat = 0.03   // below this = hard
        static let highBallThreshold: CGFloat = 0.12   // above this = easy (sitter)

        // Aggression control
        static let baseAggressionFloor: CGFloat = 0.5  // min aggression scale from aggressionControl

        // Serve return deep positioning
        static let deepReturnNYMin: CGFloat = 0.95
        static let deepReturnNYMax: CGFloat = 0.98
        static let defaultReturnNY: CGFloat = 0.92

        // Difficulty threshold for "hard shot" reset trigger
        static let hardShotDifficultyThreshold: CGFloat = 0.6

        // NPC serve targeting — how deep the serve lands on the opponent's side
        // Lower DUPR aims deeper (safer) to avoid kitchen faults; higher DUPR pushes closer
        static let npcServeTargetMinNY: CGFloat = 0.050         // deepest serve target (all DUPR)
        static let npcServeTargetMaxNY_Low: CGFloat = 0.250     // max target NY at DUPR 2.0
        static let npcServeTargetMaxNY_High: CGFloat = 0.250    // max target NY at DUPR 8.0

        // Serve fault mode penalties — power/spin serves are harder to land
        // Raw penalty is reduced by aggressionControl (skilled NPCs manage the risk)
        static let npcServePowerFaultPenalty: CGFloat = 0.08   // raw fault increase for power serves
        static let npcServeSpinFaultPenalty: CGFloat = 0.05    // raw fault increase for spin serves
        static let npcServeControlExponent: CGFloat = 1.2      // how fast skill reduces mode fault risk

        // Shot quality modifiers (interactive match)
        static let goodShotErrorBonus: CGFloat = 0.25     // max NPC error rate increase from good player shot
        static let badShotErrorPenalty: CGFloat = -0.20    // max NPC error rate decrease from bad player shot

        // Exponential DUPR error scaling (replaces linear duprGapErrorScale)
        static let duprErrorDecayRate: CGFloat = 4.0      // exp(-gap * rate); stronger NPC error reduction
        static let duprErrorGrowthRate: CGFloat = 2.5     // weaker NPC error growth
        static let duprErrorFloor: CGFloat = 0.05         // NPC min error fraction (even at huge gaps)
        static let duprErrorCeiling: CGFloat = 3.0        // NPC max error multiplier when weaker

        // Rally pressure system
        static let pressureBaseThreshold: CGFloat = 2.0   // base pressure tolerance
        static let pressureStatScale: CGFloat = 3.0       // bonus threshold per avgDefense/99
        static let pressureErrorScale: CGFloat = 0.15     // forced error increase per pressure overflow
        static let pressureDecayPerShot: CGFloat = 0.3    // per-shot recovery

        // DUPR gap forced error amplifier (player side)
        static let duprForcedErrorAmplifier: CGFloat = 2.0 // 0.1 gap → 1.2x whiffs, 1.0 gap → 3x
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
        static let fieldSpawnIntervalMin: TimeInterval = 1500  // 25 minutes minimum
        static let fieldSpawnIntervalMax: TimeInterval = 2100  // 35 minutes maximum
        static let fieldDespawnTime: TimeInterval = 1800       // 30 minutes
        static let maxActiveFieldDrops: Int = 2
        static let spawnRadius: Double = 300                   // meters
        static let fieldDropMinSpacing: Double = 150           // meters — minimum distance between field drops
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

    // MARK: - Skills
    enum Skills {
        static let skillPointsPerLevel: Int = 1
        static let maxSkillRank: Int = 5
        static let lessonsToAcquire: Int = 5
    }

    // MARK: - Pressure Shots (NPC deep + opponent at net)
    enum PressureShots {
        // --- Shot Selection (NPC deep NY>0.82, opponent at net NY<0.38) ---

        // Drop shot selection rate: how often NPC chooses touch/drop under pressure
        // 2.0→~12%, 3.5→~36%, 5.0→~58%, 6.5→~75%
        static let dropSelectBase: CGFloat = 0.4400       // rate at DUPR 4.0
        static let dropSelectSlope: CGFloat = 0.1400      // per DUPR
        static let dropSelectFloor: CGFloat = 0.05
        static let dropSelectCeiling: CGFloat = 0.80

        // Lob selection rate: panic lobs decrease with skill
        // 2.0→~25%, 3.5→~10%, 5.0→~5%, 6.5→~3%
        static let lobSelectBase: CGFloat = 0.08        // rate at DUPR 4.0
        static let lobSelectSlope: CGFloat = -0.04      // per DUPR (decreases)
        static let lobSelectFloor: CGFloat = 0.02
        static let lobSelectCeiling: CGFloat = 0.30

        // Drive = 1 - drop - lob (remainder)

        // --- Drop Shot Quality (% of attempted drops) ---

        // Perfect drop: lands in kitchen, low, unattackable
        // 2.0→~8%, 3.5→~35%, 5.0→~62%, 6.5→~85%
        static let dropPerfectBase: CGFloat = 0.4500      // rate at DUPR 4.0
        static let dropPerfectSlope: CGFloat = 0.1800     // per DUPR
        static let dropPerfectFloor: CGFloat = 0.02
        static let dropPerfectCeiling: CGFloat = 0.92

        // Drop error: net or out (total whiff)
        // 2.0→~50%, 3.5→~22%, 5.0→~10%, 6.5→~3%
        static let dropErrorBase: CGFloat = 0.1800        // rate at DUPR 4.0
        static let dropErrorSlope: CGFloat = -0.1000      // per DUPR (decreases)
        static let dropErrorFloor: CGFloat = 0.02
        static let dropErrorCeiling: CGFloat = 0.70

        // Pop-up (attackable) = 1 - perfect - error (remainder)

        // --- Drive Quality Under Pressure ---

        // Clean drive: gets past net player or puts them in trouble
        // 2.0→~15%, 3.5→~40%, 5.0→~65%, 6.5→~82%
        static let driveCleanBase: CGFloat = 0.4935       // rate at DUPR 4.0
        static let driveCleanSlope: CGFloat = 0.1500      // per DUPR
        static let driveCleanFloor: CGFloat = 0.08
        static let driveCleanCeiling: CGFloat = 0.88

        // --- Kitchen Approach After Drop ---

        // Probability NPC moves to kitchen line after making a successful drop
        // 2.0→~12%, 3.5→~45%, 5.0→~80%, 6.5→~95%
        static let kitchenApproachAfterDropBase: CGFloat = 0.5500   // rate at DUPR 4.0
        static let kitchenApproachAfterDropSlope: CGFloat = 0.2000  // per DUPR
        static let kitchenApproachAfterDropFloor: CGFloat = 0.02
        static let kitchenApproachAfterDropCeiling: CGFloat = 0.98

        // --- Pressure Detection Thresholds ---

        // NPC is "deep" when further than this from the net
        static let deepThresholdNY: CGFloat = 0.82      // NPC side: 0.82+ is deep
        // Opponent is "at net" when closer than this to the net
        static let opponentAtNetThresholdNY: CGFloat = 0.38  // Player side: <0.38 is at net
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
