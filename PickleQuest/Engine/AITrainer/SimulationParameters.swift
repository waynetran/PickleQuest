import Foundation

/// Mutable set of tunable rally constants used by `LightweightMatchSimulator`.
/// Mirrors the values from `GameConstants.Rally` but allows the ES trainer to perturb them.
struct SimulationParameters: Sendable {
    // Serve phase
    var baseAceChance: Double
    var powerAceScaling: Double
    var reflexDefenseScale: Double

    // Rally phase — winners and errors
    var baseWinnerChance: Double
    var baseErrorChance: Double

    // Forced errors
    var forcedErrorBase: Double
    var attackPressureScale: Double
    var defenseResistScale: Double

    // Winner shot bonus (per-shot increase in winner chance as rally extends)
    var winnerShotBonus: Double

    // Error scaling from stats
    var errorConsistencyScale: Double
    var errorAccuracyScale: Double
    var errorFatigueScale: Double

    // Overall advantage weight (max-rally stat comparison)
    var overallAdvantageScale: Double

    /// Initialize from current `GameConstants.Rally` values.
    static let defaults = SimulationParameters(
        baseAceChance: GameConstants.Rally.baseAceChance,
        powerAceScaling: GameConstants.Rally.powerAceScaling,
        reflexDefenseScale: GameConstants.Rally.reflexDefenseScale,
        baseWinnerChance: GameConstants.Rally.baseWinnerChance,
        baseErrorChance: GameConstants.Rally.baseErrorChance,
        forcedErrorBase: 0.08,
        attackPressureScale: 1.0 / 200.0,
        defenseResistScale: 1.0 / 200.0,
        winnerShotBonus: 0.005,
        errorConsistencyScale: 1.0 / 200.0,
        errorAccuracyScale: 1.0 / 200.0,
        errorFatigueScale: 0.003,
        overallAdvantageScale: 1.0 / 200.0
    )

    // MARK: - Vector Operations

    static let parameterCount = 13

    func toArray() -> [Double] {
        [
            baseAceChance, powerAceScaling, reflexDefenseScale,
            baseWinnerChance, baseErrorChance,
            forcedErrorBase, attackPressureScale, defenseResistScale,
            winnerShotBonus,
            errorConsistencyScale, errorAccuracyScale, errorFatigueScale,
            overallAdvantageScale
        ]
    }

    init(fromArray a: [Double]) {
        baseAceChance = a[0]
        powerAceScaling = a[1]
        reflexDefenseScale = a[2]
        baseWinnerChance = a[3]
        baseErrorChance = a[4]
        forcedErrorBase = a[5]
        attackPressureScale = a[6]
        defenseResistScale = a[7]
        winnerShotBonus = a[8]
        errorConsistencyScale = a[9]
        errorAccuracyScale = a[10]
        errorFatigueScale = a[11]
        overallAdvantageScale = a[12]
    }

    init(
        baseAceChance: Double, powerAceScaling: Double, reflexDefenseScale: Double,
        baseWinnerChance: Double, baseErrorChance: Double,
        forcedErrorBase: Double, attackPressureScale: Double, defenseResistScale: Double,
        winnerShotBonus: Double,
        errorConsistencyScale: Double, errorAccuracyScale: Double, errorFatigueScale: Double,
        overallAdvantageScale: Double
    ) {
        self.baseAceChance = baseAceChance
        self.powerAceScaling = powerAceScaling
        self.reflexDefenseScale = reflexDefenseScale
        self.baseWinnerChance = baseWinnerChance
        self.baseErrorChance = baseErrorChance
        self.forcedErrorBase = forcedErrorBase
        self.attackPressureScale = attackPressureScale
        self.defenseResistScale = defenseResistScale
        self.winnerShotBonus = winnerShotBonus
        self.errorConsistencyScale = errorConsistencyScale
        self.errorAccuracyScale = errorAccuracyScale
        self.errorFatigueScale = errorFatigueScale
        self.overallAdvantageScale = overallAdvantageScale
    }

    /// Clamp all values to sensible ranges (no negative probabilities, reasonable caps).
    func clamped() -> SimulationParameters {
        SimulationParameters(
            baseAceChance: max(0.001, min(0.25, baseAceChance)),
            powerAceScaling: max(0.0001, min(0.01, powerAceScaling)),
            reflexDefenseScale: max(0.0001, min(0.01, reflexDefenseScale)),
            baseWinnerChance: max(0.02, min(0.40, baseWinnerChance)),
            baseErrorChance: max(0.02, min(0.40, baseErrorChance)),
            forcedErrorBase: max(0.01, min(0.25, forcedErrorBase)),
            attackPressureScale: max(0.001, min(0.02, attackPressureScale)),
            defenseResistScale: max(0.001, min(0.02, defenseResistScale)),
            winnerShotBonus: max(0.0, min(0.02, winnerShotBonus)),
            errorConsistencyScale: max(0.001, min(0.02, errorConsistencyScale)),
            errorAccuracyScale: max(0.001, min(0.02, errorAccuracyScale)),
            errorFatigueScale: max(0.0, min(0.01, errorFatigueScale)),
            overallAdvantageScale: max(0.001, min(0.02, overallAdvantageScale))
        )
    }

    static let parameterNames: [String] = [
        "baseAceChance", "powerAceScaling", "reflexDefenseScale",
        "baseWinnerChance", "baseErrorChance",
        "forcedErrorBase", "attackPressureScale", "defenseResistScale",
        "winnerShotBonus",
        "errorConsistencyScale", "errorAccuracyScale", "errorFatigueScale",
        "overallAdvantageScale"
    ]
}
