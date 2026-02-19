import Foundation

/// Captures results of an AI training session.
struct TrainingReport: Sendable {
    let parameters: SimulationParameters
    let fitnessScore: Double
    let generationCount: Int
    let npcVsNPCTable: [PointDiffEntry]
    let playerVsNPCTable: [PlayerVsNPCEntry]
    let starterBalance: PlayerVsNPCEntry
    let avgRallyLength: Double
    let elapsedSeconds: Double
    let headlessInteractiveTable: [HeadlessInteractiveEntry]

    struct PointDiffEntry: Sendable, Identifiable {
        let id = UUID()
        let higherDUPR: Double
        let lowerDUPR: Double
        let actualPointDiff: Double
        let targetPointDiff: Double
        let actualWinRate: Double
        let matchesPlayed: Int
    }

    struct PlayerVsNPCEntry: Sendable, Identifiable {
        let id = UUID()
        let dupr: Double
        let npcEquipBonus: Int
        let actualPointDiff: Double
        let targetPointDiff: Double
        let actualWinRate: Double
        let matchesPlayed: Int
    }

    struct HeadlessInteractiveEntry: Sendable, Identifiable {
        let id = UUID()
        let dupr: Double
        let actualPointDiff: Double
        let actualWinRate: Double
        let avgRallyLength: Double
        let matchesPlayed: Int
    }

    /// Stat profile for a single DUPR level (for display).
    struct StatProfile: Sendable, Identifiable {
        let id = UUID()
        let dupr: Double
        let stats: [Int] // 11 values in statNames order
    }

    /// Generate stat profiles for display DUPR levels.
    func statProfiles() -> [StatProfile] {
        let duprLevels = stride(from: 2.0, through: 8.0, by: 1.0)
        return duprLevels.map { dupr in
            let ps = parameters.toPlayerStats(dupr: dupr)
            return StatProfile(dupr: dupr, stats: [
                ps.power, ps.accuracy, ps.spin, ps.speed,
                ps.defense, ps.reflexes, ps.positioning,
                ps.clutch, ps.focus, ps.stamina, ps.consistency
            ])
        }
    }

    func formattedReport() -> String {
        var lines: [String] = []
        lines.append("PickleQuest AI Training Report")
        lines.append("==============================")
        lines.append("Generations: \(generationCount)")
        lines.append(String(format: "Final Fitness: %.4f", fitnessScore))
        lines.append(String(format: "Avg Rally Length: %.1f shots", avgRallyLength))

        let mins = Int(elapsedSeconds) / 60
        let secs = Int(elapsedSeconds) % 60
        lines.append("Duration: \(mins)m \(secs)s")
        lines.append("")

        // Stat profiles table
        let profiles = statProfiles()
        let names = SimulationParameters.statNames

        lines.append("Stat Profiles by DUPR (bare NPC stats):")
        var header = "             "
        for p in profiles {
            header += String(format: "  %4.1f", p.dupr)
        }
        lines.append(header)

        for (i, name) in names.enumerated() {
            var row = name.padding(toLength: 13, withPad: " ", startingAt: 0)
            for p in profiles {
                row += String(format: "  %4d", p.stats[i])
            }
            lines.append(row)
        }
        lines.append("")

        // NPC virtual equipment bonuses
        lines.append("NPC Virtual Equipment Bonus by DUPR:")
        let duprLevels = stride(from: 2.0, through: 8.0, by: 1.0)
        for dupr in duprLevels {
            let bonus = parameters.npcEquipmentBonus(dupr: dupr)
            lines.append(String(format: "  DUPR %.1f: +%d per stat", dupr, bonus))
        }
        lines.append("")

        // NPC Move Speed Scale by DUPR
        lines.append("NPC Move Speed Scale by DUPR:")
        for dupr in duprLevels {
            let scale = parameters.moveSpeedScale(dupr: dupr)
            lines.append(String(format: "  DUPR %.1f: %.2fx", dupr, scale))
        }
        lines.append("")

        // NPC-vs-NPC point differentials
        lines.append("NPC-vs-NPC Point Differentials (Higher - Lower):")
        lines.append("  Matchup           Target   Actual   WinRate")
        for entry in npcVsNPCTable {
            let matchup = String(format: "%.1f vs %.1f", entry.higherDUPR, entry.lowerDUPR)
                .padding(toLength: 16, withPad: " ", startingAt: 0)
            let target = String(format: "%+5.1f", entry.targetPointDiff)
            let actual = String(format: "%+5.1f", entry.actualPointDiff)
            let winRate = String(format: "%5.1f%%", entry.actualWinRate * 100)
            lines.append("  \(matchup)  \(target)    \(actual)    \(winRate)")
        }
        lines.append("")

        // Player-vs-NPC balance
        lines.append("Player vs NPC Balance (bare stats vs NPC+equip, same DUPR):")
        lines.append("  DUPR   Equip   Target   Actual   WinRate")
        for entry in playerVsNPCTable {
            let dupr = String(format: "%.1f", entry.dupr)
            let equip = String(format: "+%d", entry.npcEquipBonus)
            let target = String(format: "%+5.1f", entry.targetPointDiff)
            let actual = String(format: "%+5.1f", entry.actualPointDiff)
            let winRate = String(format: "%5.1f%%", entry.actualWinRate * 100)
            lines.append("  \(dupr)     \(equip)     \(target)    \(actual)    \(winRate)")
        }
        lines.append("")

        // Starter balance
        lines.append("Starter Balance (trained stats vs NPC at DUPR 2.0):")
        let starter = parameters.toPlayerStarterStats()
        lines.append("  Trained starter: pow=\(starter.power) acc=\(starter.accuracy) spn=\(starter.spin) spd=\(starter.speed) def=\(starter.defense) ref=\(starter.reflexes) pos=\(starter.positioning) clu=\(starter.clutch) foc=\(starter.focus) sta=\(starter.stamina) con=\(starter.consistency)")
        lines.append(String(format: "  Point diff: %+.1f (target: %+.1f), Win rate: %.1f%%",
                            starterBalance.actualPointDiff, starterBalance.targetPointDiff,
                            starterBalance.actualWinRate * 100))

        // Headless interactive validation
        if !headlessInteractiveTable.isEmpty {
            lines.append("")
            lines.append("Headless Interactive Validation (player vs NPC, same DUPR):")
            lines.append("  DUPR   PointDiff   WinRate   AvgRally   Matches")
            for entry in headlessInteractiveTable {
                let dupr = String(format: "%.1f", entry.dupr)
                let diff = String(format: "%+5.1f", entry.actualPointDiff)
                let winRate = String(format: "%5.1f%%", entry.actualWinRate * 100)
                let rally = String(format: "%5.1f", entry.avgRallyLength)
                lines.append("  \(dupr)     \(diff)     \(winRate)     \(rally)       \(entry.matchesPlayed)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
