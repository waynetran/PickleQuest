import Foundation

enum AlphaNPCGenerator {
    /// Generate an alpha boss NPC for a court based on its strongest regular NPC.
    /// Uses a deterministic UUID derived from the court ID so the same alpha regenerates.
    static func generateAlpha(for court: Court, strongestNPC: NPC) -> NPC {
        let alphaID = deterministicAlphaID(courtID: court.id)
        let scaledStats = scaleStats(strongestNPC.stats)
        let bumpedDifficulty = bumpDifficulty(strongestNPC.difficulty)

        return NPC(
            id: alphaID,
            name: alphaName(courtName: court.name),
            title: "Court Alpha",
            difficulty: bumpedDifficulty,
            stats: scaledStats,
            playerType: .allRounder,
            dialogue: alphaDialogue(courtName: court.name),
            portraitName: "alpha_boss",
            rewardMultiplier: GameConstants.CourtProgression.alphaRewardMultiplier,
            skills: MockNPCService.generateSkills(playerType: .allRounder, difficulty: bumpedDifficulty)
        )
    }

    /// Deterministic UUID from court ID so the alpha always regenerates the same.
    static func deterministicAlphaID(courtID: UUID) -> UUID {
        let courtString = courtID.uuidString
        // Create a deterministic UUID by hashing the court ID with a salt
        let saltedString = "alpha-\(courtString)"
        let bytes = Array(saltedString.utf8)
        // Simple hash → UUID bytes
        var hashBytes = [UInt8](repeating: 0, count: 16)
        for (i, byte) in bytes.enumerated() {
            hashBytes[i % 16] ^= byte &+ UInt8(i % 256)
        }
        // Set version 4 and variant bits
        hashBytes[6] = (hashBytes[6] & 0x0F) | 0x40
        hashBytes[8] = (hashBytes[8] & 0x3F) | 0x80
        let uuid = NSUUID(uuidBytes: hashBytes) as UUID
        return uuid
    }

    // MARK: - Private

    private static func scaleStats(_ stats: PlayerStats) -> PlayerStats {
        let scale = GameConstants.CourtProgression.alphaStatScale
        let cap = GameConstants.CourtProgression.alphaStatCap

        func scaled(_ value: Int) -> Int {
            min(cap, Int(Double(value) * scale))
        }

        return PlayerStats(
            power: scaled(stats.power),
            accuracy: scaled(stats.accuracy),
            spin: scaled(stats.spin),
            speed: scaled(stats.speed),
            defense: scaled(stats.defense),
            reflexes: scaled(stats.reflexes),
            positioning: scaled(stats.positioning),
            clutch: scaled(stats.clutch),
            focus: scaled(stats.focus),
            stamina: scaled(stats.stamina),
            consistency: scaled(stats.consistency)
        )
    }

    private static func bumpDifficulty(_ difficulty: NPCDifficulty) -> NPCDifficulty {
        switch difficulty {
        case .beginner: return .intermediate
        case .intermediate: return .advanced
        case .advanced: return .expert
        case .expert: return .master
        case .master: return .master
        }
    }

    private static func alphaName(courtName: String) -> String {
        "Alpha of \(courtName)"
    }

    private static func alphaDialogue(courtName: String) -> NPCDialogue {
        NPCDialogue(
            greeting: "You've beaten everyone else here. But I'm not like them. I AM \(courtName).",
            onWin: "This court is mine. Always has been, always will be.",
            onLose: "Impossible... You've earned the crown. But I'll be back.",
            taunt: "You think beating a few regulars makes you ready for me?"
        )
    }
}
