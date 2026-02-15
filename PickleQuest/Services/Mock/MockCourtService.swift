import Foundation
import CoreLocation

actor MockCourtService: CourtService {
    private var courts: [Court] = []
    private var courtNPCAssignments: [UUID: [NPC]] = [:]
    private var generated = false
    private let npcService: NPCService

    init(npcService: NPCService) {
        self.npcService = npcService
    }

    var hasGenerated: Bool { generated }

    func generateCourts(around center: CLLocationCoordinate2D) async {
        guard !generated else { return }

        // Create courts at fixed offsets from player's location
        courts = Self.templates.map { t in
            let lat = center.latitude + t.northOffset / 111_000.0
            let lng = center.longitude + t.eastOffset / (111_000.0 * cos(center.latitude * .pi / 180))
            return Court(
                id: t.id,
                name: t.name,
                description: t.description,
                latitude: lat,
                longitude: lng,
                difficultyTiers: t.difficultyTiers,
                courtCount: t.courtCount
            )
        }

        // Distribute NPCs to courts by difficulty tier
        let allNPCs = await npcService.getAllNPCs()
        var npcsByTier: [NPCDifficulty: [NPC]] = [:]
        for npc in allNPCs {
            npcsByTier[npc.difficulty, default: []].append(npc)
        }

        var tierCursor: [NPCDifficulty: Int] = [:]
        for court in courts {
            var npcs: [NPC] = []
            for tier in court.difficultyTiers.sorted() {
                guard let pool = npcsByTier[tier], !pool.isEmpty else { continue }
                let cursor = tierCursor[tier, default: 0]
                let take = min(2, pool.count)
                for i in 0..<take {
                    npcs.append(pool[(cursor + i) % pool.count])
                }
                tierCursor[tier] = (cursor + take) % pool.count
            }
            courtNPCAssignments[court.id] = npcs
        }

        generated = true
    }

    func getAllCourts() async -> [Court] { courts }

    func getCourt(by id: UUID) async -> Court? {
        courts.first { $0.id == id }
    }

    func getNPCsAtCourt(_ courtID: UUID) async -> [NPC] {
        courtNPCAssignments[courtID] ?? []
    }

    // MARK: - Court Templates

    private struct CourtTemplate {
        let id: UUID
        let name: String
        let description: String
        let northOffset: Double // meters from player
        let eastOffset: Double
        let difficultyTiers: Set<NPCDifficulty>
        let courtCount: Int
    }

    private static let templates: [CourtTemplate] = [
        CourtTemplate(
            id: UUID(uuidString: "20000001-0000-0000-0000-000000000001")!,
            name: "Sunrise Recreation Center",
            description: "A friendly facility with well-maintained courts. Perfect for newcomers.",
            northOffset: 200, eastOffset: 150,
            difficultyTiers: [.beginner],
            courtCount: 2
        ),
        CourtTemplate(
            id: UUID(uuidString: "20000002-0000-0000-0000-000000000002")!,
            name: "Lakeside Park Courts",
            description: "Scenic outdoor courts by the lake. Casual atmosphere.",
            northOffset: -300, eastOffset: 400,
            difficultyTiers: [.beginner],
            courtCount: 2
        ),
        CourtTemplate(
            id: UUID(uuidString: "20000003-0000-0000-0000-000000000003")!,
            name: "Community Center",
            description: "Popular courts where beginners meet rising players.",
            northOffset: 500, eastOffset: -200,
            difficultyTiers: [.beginner, .intermediate],
            courtCount: 4
        ),
        CourtTemplate(
            id: UUID(uuidString: "20000004-0000-0000-0000-000000000004")!,
            name: "Downtown Athletic Club",
            description: "Indoor courts with a competitive edge. Members mean business.",
            northOffset: -600, eastOffset: -450,
            difficultyTiers: [.intermediate],
            courtCount: 3
        ),
        CourtTemplate(
            id: UUID(uuidString: "20000005-0000-0000-0000-000000000005")!,
            name: "Riverside Sports Complex",
            description: "A multi-sport facility attracting skilled players.",
            northOffset: 800, eastOffset: 600,
            difficultyTiers: [.intermediate, .advanced],
            courtCount: 4
        ),
        CourtTemplate(
            id: UUID(uuidString: "20000006-0000-0000-0000-000000000006")!,
            name: "Highland Park Courts",
            description: "Elevated courts with a reputation for tough competition.",
            northOffset: -900, eastOffset: 300,
            difficultyTiers: [.advanced],
            courtCount: 3
        ),
        CourtTemplate(
            id: UUID(uuidString: "20000007-0000-0000-0000-000000000007")!,
            name: "Metro Championship Arena",
            description: "Where regional tournaments are held. Only strong players dare enter.",
            northOffset: 1200, eastOffset: -800,
            difficultyTiers: [.advanced, .expert],
            courtCount: 6
        ),
        CourtTemplate(
            id: UUID(uuidString: "20000008-0000-0000-0000-000000000008")!,
            name: "Grand Slam Sports Center",
            description: "Elite facility for serious competitors. Sponsorship opportunities abound.",
            northOffset: -1400, eastOffset: -1000,
            difficultyTiers: [.expert],
            courtCount: 4
        ),
        CourtTemplate(
            id: UUID(uuidString: "20000009-0000-0000-0000-000000000009")!,
            name: "The Proving Grounds",
            description: "A legendary venue whispered about in pickleball circles. Only the best survive.",
            northOffset: 1800, eastOffset: 1200,
            difficultyTiers: [.expert, .master],
            courtCount: 2
        ),
        CourtTemplate(
            id: UUID(uuidString: "2000000a-0000-0000-0000-00000000000a")!,
            name: "Legends Court",
            description: "The pinnacle. Few have earned the right to play here.",
            northOffset: -2000, eastOffset: 1500,
            difficultyTiers: [.master],
            courtCount: 1
        ),
    ]
}
