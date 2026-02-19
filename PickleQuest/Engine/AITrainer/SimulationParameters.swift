import Foundation

/// Per-stat linear mapping coefficients optimized by the ES trainer.
/// For each of 11 stats: `stat(dupr) = slope * normalizedDupr + offset`
/// where `normalizedDupr = (dupr - 2.0) / 6.0` (0.0 at DUPR 2.0, 1.0 at DUPR 8.0).
struct SimulationParameters: Sendable, Codable {
    /// Stat increase from DUPR 2.0 to DUPR 8.0 (per stat)
    var slopes: [Double]   // 11 values
    /// Base stat value at DUPR 2.0 (per stat)
    var offsets: [Double]  // 11 values
    /// NPC virtual equipment: bonus increase from DUPR 2.0 to DUPR 8.0
    var npcEquipSlope: Double
    /// NPC virtual equipment: minimum bonus at DUPR 2.0
    var npcEquipOffset: Double
    /// Trained starting stats for a new player (11 values in statNames order)
    var playerStarterStats: [Double]  // 11 values
    /// NPC move speed multiplier at DUPR 2.0 (low end)
    var npcMoveSpeedScaleLow: Double
    /// NPC move speed multiplier at DUPR 8.0 (high end)
    var npcMoveSpeedScaleHigh: Double

    static let statCount = 11
    static let parameterCount = 37 // 11 slopes + 11 offsets + 2 npcEquip + 11 starter + 2 speedScale

    static let statNames: [String] = [
        "power", "accuracy", "spin", "speed",
        "defense", "reflexes", "positioning",
        "clutch", "focus", "stamina", "consistency"
    ]

    /// Default: stats go from 10 at DUPR 2.0 to 99 at DUPR 8.0 (slope=89, offset=10).
    /// NPC equip starts at slope=5, offset=2. Starter stats near DUPR 2.0 NPC level.
    static let defaults: SimulationParameters = {
        let slope = 89.0
        let offset = 10.0
        return SimulationParameters(
            slopes: [Double](repeating: slope, count: statCount),
            offsets: [Double](repeating: offset, count: statCount),
            npcEquipSlope: 4.0,
            npcEquipOffset: 3.0,
            playerStarterStats: [10, 10, 10, 10, 10, 10, 10, 10, 10, 13, 13],
            npcMoveSpeedScaleLow: 0.55,
            npcMoveSpeedScaleHigh: 1.0
        )
    }()

    init(slopes: [Double], offsets: [Double],
         npcEquipSlope: Double = 4.0, npcEquipOffset: Double = 3.0,
         playerStarterStats: [Double] = [10, 10, 10, 10, 10, 10, 10, 10, 10, 13, 13],
         npcMoveSpeedScaleLow: Double = 0.55, npcMoveSpeedScaleHigh: Double = 1.0) {
        self.slopes = slopes
        self.offsets = offsets
        self.npcEquipSlope = npcEquipSlope
        self.npcEquipOffset = npcEquipOffset
        self.playerStarterStats = playerStarterStats
        self.npcMoveSpeedScaleLow = npcMoveSpeedScaleLow
        self.npcMoveSpeedScaleHigh = npcMoveSpeedScaleHigh
    }

    init(fromArray a: [Double]) {
        let sc = SimulationParameters.statCount
        slopes = Array(a[0..<sc])
        offsets = Array(a[sc..<(2 * sc)])
        npcEquipSlope = a[2 * sc]
        npcEquipOffset = a[2 * sc + 1]
        playerStarterStats = Array(a[(2 * sc + 2)..<(2 * sc + 2 + sc)])
        npcMoveSpeedScaleLow = a[2 * sc + 2 + sc]
        npcMoveSpeedScaleHigh = a[2 * sc + 2 + sc + 1]
    }

    // MARK: - Codable (backward compatible)

    enum CodingKeys: String, CodingKey {
        case slopes, offsets, npcEquipSlope, npcEquipOffset, playerStarterStats
        case npcMoveSpeedScaleLow, npcMoveSpeedScaleHigh
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slopes = try c.decode([Double].self, forKey: .slopes)
        offsets = try c.decode([Double].self, forKey: .offsets)
        npcEquipSlope = try c.decodeIfPresent(Double.self, forKey: .npcEquipSlope) ?? 5.0
        npcEquipOffset = try c.decodeIfPresent(Double.self, forKey: .npcEquipOffset) ?? 3.0
        playerStarterStats = try c.decodeIfPresent([Double].self, forKey: .playerStarterStats)
            ?? [10, 10, 7, 10, 10, 10, 10, 7, 10, 13, 13]
        npcMoveSpeedScaleLow = try c.decodeIfPresent(Double.self, forKey: .npcMoveSpeedScaleLow) ?? 0.55
        npcMoveSpeedScaleHigh = try c.decodeIfPresent(Double.self, forKey: .npcMoveSpeedScaleHigh) ?? 1.0
    }

    func toArray() -> [Double] {
        slopes + offsets + [npcEquipSlope, npcEquipOffset] + playerStarterStats
            + [npcMoveSpeedScaleLow, npcMoveSpeedScaleHigh]
    }

    /// Clamp all parameters to valid ranges.
    func clamped() -> SimulationParameters {
        var s = slopes
        var o = offsets
        for i in 0..<SimulationParameters.statCount {
            s[i] = max(0, min(120, s[i]))
            o[i] = max(1, min(50, o[i]))
            // Ensure stat at DUPR 8.0 (n=1.0) doesn't exceed 99
            if s[i] + o[i] > 99 {
                s[i] = 99 - o[i]
            }
        }
        let eqSlope = max(0, min(30, npcEquipSlope))
        let eqOffset = max(0, min(15, npcEquipOffset))
        var starter = playerStarterStats
        for i in 0..<SimulationParameters.statCount {
            starter[i] = max(1, min(40, starter[i]))
        }
        let speedScaleLow = max(0.3, min(1.0, npcMoveSpeedScaleLow))
        let speedScaleHigh = max(0.5, min(1.2, npcMoveSpeedScaleHigh))
        return SimulationParameters(
            slopes: s, offsets: o,
            npcEquipSlope: eqSlope, npcEquipOffset: eqOffset,
            playerStarterStats: starter,
            npcMoveSpeedScaleLow: speedScaleLow,
            npcMoveSpeedScaleHigh: speedScaleHigh
        )
    }

    /// Generate a PlayerStats block for a given DUPR level (bare NPC stats, no equipment).
    func toPlayerStats(dupr: Double) -> PlayerStats {
        let n = (dupr - 2.0) / 6.0
        func stat(_ index: Int) -> Int {
            max(1, min(99, Int((slopes[index] * n + offsets[index]).rounded())))
        }
        return PlayerStats(
            power: stat(0), accuracy: stat(1), spin: stat(2), speed: stat(3),
            defense: stat(4), reflexes: stat(5), positioning: stat(6),
            clutch: stat(7), focus: stat(8), stamina: stat(9), consistency: stat(10)
        )
    }

    /// Flat per-stat equipment bonus for an NPC at a given DUPR.
    func npcEquipmentBonus(dupr: Double) -> Int {
        let n = (dupr - 2.0) / 6.0
        return max(0, Int((npcEquipSlope * n + npcEquipOffset).rounded()))
    }

    /// Generate NPC stats with virtual equipment bonus applied.
    func toNPCStats(dupr: Double) -> PlayerStats {
        var stats = toPlayerStats(dupr: dupr)
        let bonus = npcEquipmentBonus(dupr: dupr)
        stats.power = min(99, stats.power + bonus)
        stats.accuracy = min(99, stats.accuracy + bonus)
        stats.spin = min(99, stats.spin + bonus)
        stats.speed = min(99, stats.speed + bonus)
        stats.defense = min(99, stats.defense + bonus)
        stats.reflexes = min(99, stats.reflexes + bonus)
        stats.positioning = min(99, stats.positioning + bonus)
        stats.clutch = min(99, stats.clutch + bonus)
        stats.focus = min(99, stats.focus + bonus)
        stats.stamina = min(99, stats.stamina + bonus)
        stats.consistency = min(99, stats.consistency + bonus)
        return stats
    }

    /// Convert trained starter array to PlayerStats.
    func toPlayerStarterStats() -> PlayerStats {
        func s(_ i: Int) -> Int { max(1, min(99, Int(playerStarterStats[i].rounded()))) }
        return PlayerStats(
            power: s(0), accuracy: s(1), spin: s(2), speed: s(3),
            defense: s(4), reflexes: s(5), positioning: s(6),
            clutch: s(7), focus: s(8), stamina: s(9), consistency: s(10)
        )
    }

    /// DUPR-based move speed multiplier. Interpolates linearly from low (DUPR 2.0) to high (DUPR 8.0).
    func moveSpeedScale(dupr: Double) -> CGFloat {
        let n = max(0, min(1, (dupr - 2.0) / 6.0))
        return CGFloat(npcMoveSpeedScaleLow + (npcMoveSpeedScaleHigh - npcMoveSpeedScaleLow) * n)
    }
}
