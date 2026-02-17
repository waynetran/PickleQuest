import Foundation

/// Per-stat linear mapping coefficients optimized by the ES trainer.
/// For each of 11 stats: `stat(dupr) = slope * normalizedDupr + offset`
/// where `normalizedDupr = (dupr - 2.0) / 6.0` (0.0 at DUPR 2.0, 1.0 at DUPR 8.0).
struct SimulationParameters: Sendable, Codable {
    /// Stat increase from DUPR 2.0 to DUPR 8.0 (per stat)
    var slopes: [Double]   // 11 values
    /// Base stat value at DUPR 2.0 (per stat)
    var offsets: [Double]  // 11 values

    static let statCount = 11
    static let parameterCount = 22 // 11 slopes + 11 offsets

    static let statNames: [String] = [
        "power", "accuracy", "spin", "speed",
        "defense", "reflexes", "positioning",
        "clutch", "focus", "stamina", "consistency"
    ]

    /// Initialize from current linear mapping (matches NPC.practiceOpponent behavior).
    /// Default: all stats use slope=98, offset=1 (stat goes from 1 at DUPR 2.0 to 99 at DUPR 8.0).
    static let defaults: SimulationParameters = {
        let slope = 98.0
        let offset = 1.0
        return SimulationParameters(
            slopes: [Double](repeating: slope, count: statCount),
            offsets: [Double](repeating: offset, count: statCount)
        )
    }()

    init(slopes: [Double], offsets: [Double]) {
        self.slopes = slopes
        self.offsets = offsets
    }

    init(fromArray a: [Double]) {
        slopes = Array(a[0..<SimulationParameters.statCount])
        offsets = Array(a[SimulationParameters.statCount..<SimulationParameters.parameterCount])
    }

    func toArray() -> [Double] {
        slopes + offsets
    }

    /// Clamp slopes and offsets to ensure stats stay in 1-99 range across DUPR 2.0-8.0.
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
        return SimulationParameters(slopes: s, offsets: o)
    }

    /// Generate a PlayerStats block for a given DUPR level.
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
}
