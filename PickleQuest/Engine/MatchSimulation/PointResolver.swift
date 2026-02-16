import Foundation

/// Resolves a single point in a match, coordinating stats, fatigue, momentum, and rally simulation.
struct PointResolver: Sendable {
    let statCalculator: StatCalculator
    let rallySimulator: RallySimulator

    init(statCalculator: StatCalculator = StatCalculator(), rallySimulator: RallySimulator = RallySimulator()) {
        self.statCalculator = statCalculator
        self.rallySimulator = rallySimulator
    }

    struct ResolvedPoint: Sendable {
        let result: RallySimulator.RallyResult
        let playerEnergyAfter: Double
        let opponentEnergyAfter: Double
    }

    /// Resolve a single point with full stat modifiers applied.
    func resolvePoint(
        playerBaseStats: PlayerStats,
        opponentBaseStats: PlayerStats,
        playerEquipment: [Equipment],
        opponentEquipment: [Equipment],
        playerFatigue: inout FatigueModel,
        opponentFatigue: inout FatigueModel,
        momentum: MomentumTracker,
        servingSide: MatchSide,
        isClutch: Bool,
        playerLevel: Int = 50,
        opponentLevel: Int = 50
    ) -> ResolvedPoint {
        // 1. Base + equipment (with level gating)
        var playerEffective = statCalculator.effectiveStats(base: playerBaseStats, equipment: playerEquipment, playerLevel: playerLevel)
        var opponentEffective = statCalculator.effectiveStats(base: opponentBaseStats, equipment: opponentEquipment, playerLevel: opponentLevel)

        // 2. Apply fatigue
        playerEffective = statCalculator.applyFatigue(stats: playerEffective, energy: playerFatigue.energy)
        opponentEffective = statCalculator.applyFatigue(stats: opponentEffective, energy: opponentFatigue.energy)

        // 3. Apply momentum
        let playerMomentum = momentum.modifier(for: .player)
        let opponentMomentum = momentum.modifier(for: .opponent)
        playerEffective = statCalculator.applyMomentum(stats: playerEffective, modifier: playerMomentum)
        opponentEffective = statCalculator.applyMomentum(stats: opponentEffective, modifier: opponentMomentum)

        // 4. Clutch modifier — boost clutch stat effect in close games
        if isClutch {
            let clutchBoost = 0.05
            playerEffective = statCalculator.applyMomentum(stats: playerEffective, modifier: Double(playerEffective.clutch) / 100.0 * clutchBoost)
            opponentEffective = statCalculator.applyMomentum(stats: opponentEffective, modifier: Double(opponentEffective.clutch) / 100.0 * clutchBoost)
        }

        // 5. Simulate the rally
        let result = rallySimulator.simulatePoint(
            serverSide: servingSide,
            playerStats: playerEffective,
            opponentStats: opponentEffective
        )

        // 6. Drain energy
        let playerEnergy = playerFatigue.drainEnergy(rallyLength: result.rallyLength)
        let opponentEnergy = opponentFatigue.drainEnergy(rallyLength: result.rallyLength)

        return ResolvedPoint(
            result: result,
            playerEnergyAfter: playerEnergy,
            opponentEnergyAfter: opponentEnergy
        )
    }
}
