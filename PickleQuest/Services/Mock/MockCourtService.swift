import Foundation
import CoreLocation
@preconcurrency import MapKit

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

        // Phase 1: Search for real-world POIs (parks, rec centers, pickleball courts)
        var pois = await CourtPOISearch.findCourtLocations(around: center)

        // Phase 2: Deduplicate locations within 100m of each other
        pois = Self.deduplicateByProximity(pois, threshold: 100)

        // Phase 3: If fewer than 10, generate random safe locations
        if pois.count < 10 {
            let needed = 10 - pois.count
            let extras = await CourtPOISearch.generateSafeRandomLocations(
                count: needed,
                around: center,
                avoiding: pois.map(\.coordinate),
                searchRadius: 2500
            )
            pois.append(contentsOf: extras)
        }

        // Phase 4: Sort by distance, take 10
        let sorted = pois.sorted { $0.distance(from: center) < $1.distance(from: center) }
        let best = Array(sorted.prefix(10))

        // Phase 5: Assign difficulty tiers based on distance ordering
        courts = Self.buildCourts(from: best)

        // Phase 6: Distribute NPCs to courts by difficulty tier
        await distributeNPCs()

        generated = true
    }

    func getAllCourts() async -> [Court] { courts }

    func getCourt(by id: UUID) async -> Court? {
        courts.first { $0.id == id }
    }

    func getNPCsAtCourt(_ courtID: UUID) async -> [NPC] {
        courtNPCAssignments[courtID] ?? []
    }

    // MARK: - NPC Distribution

    private func distributeNPCs() async {
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
    }

    // MARK: - Deduplication

    private static func deduplicateByProximity(_ pois: [CourtPOI], threshold: CLLocationDistance) -> [CourtPOI] {
        var result: [CourtPOI] = []
        for poi in pois {
            let tooClose = result.contains { existing in
                poi.distance(from: existing.coordinate) < threshold
            }
            if !tooClose {
                result.append(poi)
            }
        }
        return result
    }

    // MARK: - Difficulty Tier Assignment

    private static let tierAssignments: [Set<NPCDifficulty>] = [
        [.beginner],
        [.beginner],
        [.beginner, .intermediate],
        [.intermediate],
        [.intermediate, .advanced],
        [.advanced],
        [.advanced, .expert],
        [.expert],
        [.expert, .master],
        [.master],
    ]

    private static let tierDescriptions: [String: [String]] = [
        "beginner": [
            "A welcoming spot for casual rallies and friendly competition.",
            "Perfect for warming up and learning the basics of pickleball.",
        ],
        "beginner+intermediate": [
            "Popular courts where beginners meet rising players.",
        ],
        "intermediate": [
            "Competitive atmosphere where regulars sharpen their game.",
            "Well-maintained courts attracting dedicated players.",
        ],
        "intermediate+advanced": [
            "A stepping stone to serious competition. Skilled players frequent here.",
        ],
        "advanced": [
            "High-level courts with a reputation for tough matches.",
        ],
        "advanced+expert": [
            "Where regional-level players come to prove themselves.",
        ],
        "expert": [
            "Elite facility for serious competitors. Only the skilled dare enter.",
        ],
        "expert+master": [
            "A legendary venue whispered about in pickleball circles.",
        ],
        "master": [
            "The pinnacle. Few have earned the right to play here.",
        ],
    ]

    private static func tierKey(_ tiers: Set<NPCDifficulty>) -> String {
        tiers.sorted().map(\.rawValue).joined(separator: "+")
    }

    private static func buildCourts(from pois: [CourtPOI]) -> [Court] {
        pois.enumerated().map { index, poi in
            let tiers = index < tierAssignments.count ? tierAssignments[index] : [.beginner]
            let key = tierKey(tiers)
            let descriptions = tierDescriptions[key] ?? ["A local pickleball court."]

            // Use POI description if available, otherwise tier-based description
            let desc = poi.poiDescription.isEmpty
                ? (descriptions.randomElement() ?? "A local pickleball court.")
                : poi.poiDescription

            return Court(
                id: UUID(),
                name: poi.name,
                description: desc,
                latitude: poi.coordinate.latitude,
                longitude: poi.coordinate.longitude,
                difficultyTiers: tiers,
                courtCount: poi.courtCount
            )
        }
    }
}

// MARK: - POI Data

struct CourtPOI: Sendable {
    let name: String
    let poiDescription: String
    let coordinate: CLLocationCoordinate2D
    let courtCount: Int

    func distance(from center: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .distance(from: CLLocation(latitude: center.latitude, longitude: center.longitude))
    }
}

// MARK: - POI Search (@MainActor for MapKit / CLGeocoder)

@MainActor
enum CourtPOISearch {
    private static let searchQueries = ["pickleball court", "recreation center", "park"]
    private static let searchRadius: CLLocationDistance = 3000

    static func findCourtLocations(around center: CLLocationCoordinate2D) async -> [CourtPOI] {
        var results: [CourtPOI] = []

        for query in searchQueries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(
                center: center,
                latitudinalMeters: searchRadius * 2,
                longitudinalMeters: searchRadius * 2
            )

            let search = MKLocalSearch(request: request)
            guard let response = try? await search.start() else { continue }

            for item in response.mapItems {
                guard let name = item.name else { continue }
                results.append(CourtPOI(
                    name: name,
                    poiDescription: "",
                    coordinate: item.placemark.coordinate,
                    courtCount: Int.random(in: 2...4)
                ))
            }
        }

        return results
    }

    static func generateSafeRandomLocations(
        count: Int,
        around center: CLLocationCoordinate2D,
        avoiding existing: [CLLocationCoordinate2D],
        searchRadius: Double
    ) async -> [CourtPOI] {
        var results: [CourtPOI] = []
        var attempts = 0
        let maxAttempts = count * 5

        while results.count < count && attempts < maxAttempts {
            attempts += 1

            // Random offset between 200m and searchRadius
            let distance = Double.random(in: 200...searchRadius)
            let angle = Double.random(in: 0...(2 * .pi))
            let northOffset = distance * cos(angle)
            let eastOffset = distance * sin(angle)

            let lat = center.latitude + northOffset / 111_000.0
            let lng = center.longitude + eastOffset / (111_000.0 * cos(center.latitude * .pi / 180))
            let candidate = CLLocationCoordinate2D(latitude: lat, longitude: lng)

            // Check not too close to existing locations
            let tooClose = existing.contains { coord in
                CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)
                    .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude)) < 200
            } || results.contains { poi in
                poi.distance(from: candidate) < 200
            }
            if tooClose { continue }

            // Validate safety via reverse geocoding
            if let poi = await validateAndNameLocation(candidate) {
                results.append(poi)
            }
        }

        // Last resort: fill remaining with generic locations if geocoding kept failing
        while results.count < count {
            let distance = Double.random(in: 300...searchRadius)
            let angle = Double.random(in: 0...(2 * .pi))
            let northOffset = distance * cos(angle)
            let eastOffset = distance * sin(angle)

            let lat = center.latitude + northOffset / 111_000.0
            let lng = center.longitude + eastOffset / (111_000.0 * cos(center.latitude * .pi / 180))

            results.append(CourtPOI(
                name: "Local Court \(results.count + 1)",
                poiDescription: "",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                courtCount: Int.random(in: 2...3)
            ))
        }

        return results
    }

    private static func validateAndNameLocation(_ coordinate: CLLocationCoordinate2D) async -> CourtPOI? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        guard let placemarks = try? await geocoder.reverseGeocodeLocation(location),
              let placemark = placemarks.first else {
            return nil // No data — likely water or unmapped area
        }

        // Reject if in water
        if placemark.inlandWater != nil || placemark.ocean != nil {
            return nil
        }

        // Must have some form of address
        guard placemark.locality != nil || placemark.subLocality != nil else {
            return nil
        }

        // Reject unsafe thoroughfares (highways, bridges, etc.)
        if let thoroughfare = placemark.thoroughfare?.lowercased() {
            let unsafeKeywords = [
                "highway", "interstate", "freeway", "expressway",
                "bridge", "overpass", "tunnel", "ramp", "turnpike",
            ]
            if unsafeKeywords.contains(where: { thoroughfare.contains($0) }) {
                return nil
            }
        }

        // Build a name from the address
        let name: String
        if let subLocality = placemark.subLocality {
            name = "\(subLocality) Courts"
        } else if let thoroughfare = placemark.thoroughfare {
            name = "\(thoroughfare) Courts"
        } else if let locality = placemark.locality {
            name = "\(locality) Community Courts"
        } else {
            name = "Neighborhood Courts"
        }

        return CourtPOI(
            name: name,
            poiDescription: "",
            coordinate: coordinate,
            courtCount: Int.random(in: 2...3)
        )
    }
}
