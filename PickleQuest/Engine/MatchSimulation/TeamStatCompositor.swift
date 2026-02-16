import Foundation

/// Composites two players' stats into a single PlayerStats for doubles team play.
/// The existing rally/point pipeline takes one PlayerStats per side — this creates that composite.
enum TeamStatCompositor {
    private static let statCalc = StatCalculator()

    /// Composite two players' effective stats into a single team stat line.
    /// Formula: average effective stats, then apply synergy multiplier.
    static func compositeStats(
        p1Stats: PlayerStats,
        p1Equipment: [Equipment],
        p2Stats: PlayerStats,
        p2Equipment: [Equipment],
        synergy: TeamSynergy,
        p1Level: Int = 50,
        p2Level: Int = 50
    ) -> PlayerStats {
        let p1Effective = statCalc.effectiveStats(base: p1Stats, equipment: p1Equipment, playerLevel: p1Level)
        let p2Effective = statCalc.effectiveStats(base: p2Stats, equipment: p2Equipment, playerLevel: p2Level)

        var composite = PlayerStats(
            power: avg(p1Effective.power, p2Effective.power),
            accuracy: avg(p1Effective.accuracy, p2Effective.accuracy),
            spin: avg(p1Effective.spin, p2Effective.spin),
            speed: avg(p1Effective.speed, p2Effective.speed),
            defense: avg(p1Effective.defense, p2Effective.defense),
            reflexes: avg(p1Effective.reflexes, p2Effective.reflexes),
            positioning: avg(p1Effective.positioning, p2Effective.positioning),
            clutch: avg(p1Effective.clutch, p2Effective.clutch),
            stamina: avg(p1Effective.stamina, p2Effective.stamina),
            consistency: avg(p1Effective.consistency, p2Effective.consistency)
        )

        // Apply synergy multiplier to all stats
        for type in StatType.allCases {
            let current = Double(composite.stat(type))
            let modified = Int((current * synergy.multiplier).rounded())
            composite.setStat(type, value: modified)
        }

        return composite
    }

    /// Composite with pre-computed effective stats (for when fatigue is already applied).
    static func compositeEffectiveStats(
        p1Effective: PlayerStats,
        p2Effective: PlayerStats,
        synergy: TeamSynergy
    ) -> PlayerStats {
        var composite = PlayerStats(
            power: avg(p1Effective.power, p2Effective.power),
            accuracy: avg(p1Effective.accuracy, p2Effective.accuracy),
            spin: avg(p1Effective.spin, p2Effective.spin),
            speed: avg(p1Effective.speed, p2Effective.speed),
            defense: avg(p1Effective.defense, p2Effective.defense),
            reflexes: avg(p1Effective.reflexes, p2Effective.reflexes),
            positioning: avg(p1Effective.positioning, p2Effective.positioning),
            clutch: avg(p1Effective.clutch, p2Effective.clutch),
            stamina: avg(p1Effective.stamina, p2Effective.stamina),
            consistency: avg(p1Effective.consistency, p2Effective.consistency)
        )

        for type in StatType.allCases {
            let current = Double(composite.stat(type))
            let modified = Int((current * synergy.multiplier).rounded())
            composite.setStat(type, value: modified)
        }

        return composite
    }

    private static func avg(_ a: Int, _ b: Int) -> Int {
        (a + b) / 2
    }
}
