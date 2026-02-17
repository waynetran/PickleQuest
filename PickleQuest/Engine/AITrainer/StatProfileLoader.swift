import Foundation

enum StatProfileLoader {
    /// Loaded once from bundle. Falls back to .defaults if missing or corrupt.
    static let shared: SimulationParameters = {
        guard let url = Bundle.main.url(forResource: "stat_profiles", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let params = try? JSONDecoder().decode(SimulationParameters.self, from: data) else {
            return .defaults
        }
        return params.clamped()
    }()

    /// Trained starter stats for new players. Uses trained values from the profile,
    /// falling back to defaults if not available.
    static var trainedStarterStats: PlayerStats {
        shared.toPlayerStarterStats()
    }
}
