import Foundation

struct EquipmentBrand: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let tagline: String
    let slots: Set<EquipmentSlot>
}

struct EquipmentModel: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let brandID: String
    let slot: EquipmentSlot
    let baseStat: StatType
}

// MARK: - Brand Catalog

enum EquipmentBrandCatalog {
    // MARK: - Multi-Slot Brands (6)

    static let dinkmaster = EquipmentBrand(
        id: "dinkmaster", name: "Dinkmaster", tagline: "Precision is everything.",
        slots: [.paddle, .wristband, .headwear]
    )
    static let courtKraft = EquipmentBrand(
        id: "court_kraft", name: "CourtKraft", tagline: "Engineered for the court.",
        slots: [.paddle, .shoes, .shirt]
    )
    static let rallyCo = EquipmentBrand(
        id: "rally_co", name: "RallyCo", tagline: "Built to last every rally.",
        slots: [.shirt, .bottoms, .wristband]
    )
    static let zenithGear = EquipmentBrand(
        id: "zenith_gear", name: "Zenith Gear", tagline: "Peak performance, every point.",
        slots: [.shoes, .bottoms, .headwear]
    )
    static let ironWall = EquipmentBrand(
        id: "iron_wall", name: "Iron Wall", tagline: "Nothing gets past you.",
        slots: [.paddle, .shirt, .shoes]
    )
    static let apexAthlete = EquipmentBrand(
        id: "apex_athlete", name: "Apex Athlete", tagline: "For those who refuse to lose.",
        slots: [.shirt, .bottoms, .headwear, .wristband]
    )

    // MARK: - Single-Slot Specialists (8)

    static let vortexPaddles = EquipmentBrand(
        id: "vortex_paddles", name: "Vortex", tagline: "Spin doctors since day one.",
        slots: [.paddle]
    )
    static let thunderStrike = EquipmentBrand(
        id: "thunder_strike", name: "ThunderStrike", tagline: "Pure power, pure paddle.",
        slots: [.paddle]
    )
    static let swiftSole = EquipmentBrand(
        id: "swift_sole", name: "SwiftSole", tagline: "Speed from the ground up.",
        slots: [.shoes]
    )
    static let groundForce = EquipmentBrand(
        id: "ground_force", name: "GroundForce", tagline: "Planted. Ready. Dominant.",
        slots: [.shoes]
    )
    static let enduroWear = EquipmentBrand(
        id: "enduro_wear", name: "EnduroWear", tagline: "Outlast everyone.",
        slots: [.shirt]
    )
    static let flexForm = EquipmentBrand(
        id: "flex_form", name: "FlexForm", tagline: "Move without limits.",
        slots: [.bottoms]
    )
    static let focusBand = EquipmentBrand(
        id: "focus_band", name: "FocusBand", tagline: "Stay locked in.",
        slots: [.headwear]
    )
    static let gripTech = EquipmentBrand(
        id: "grip_tech", name: "GripTech", tagline: "Control at your fingertips.",
        slots: [.wristband]
    )

    static let allBrands: [EquipmentBrand] = [
        dinkmaster, courtKraft, rallyCo, zenithGear, ironWall, apexAthlete,
        vortexPaddles, thunderStrike, swiftSole, groundForce,
        enduroWear, flexForm, focusBand, gripTech
    ]

    // MARK: - Models

    static let allModels: [EquipmentModel] = {
        var models: [EquipmentModel] = []

        // Slot-relevant stats:
        // Paddle: power, accuracy, spin, consistency
        // Shoes: speed, positioning, reflexes, defense
        // Shirt: stamina, consistency, clutch, defense
        // Bottoms: speed, positioning, stamina
        // Headwear: clutch, focus, consistency, accuracy
        // Wristband: spin, accuracy, reflexes

        // --- Dinkmaster (paddle, wristband, headwear) ---
        models += [
            EquipmentModel(id: "dm_vortex", name: "Vortex", brandID: "dinkmaster", slot: .paddle, baseStat: .spin),
            EquipmentModel(id: "dm_sniper", name: "Sniper", brandID: "dinkmaster", slot: .paddle, baseStat: .accuracy),
            EquipmentModel(id: "dm_metronome", name: "Metronome", brandID: "dinkmaster", slot: .paddle, baseStat: .consistency),
            EquipmentModel(id: "dm_precision_band", name: "Precision Band", brandID: "dinkmaster", slot: .wristband, baseStat: .accuracy),
            EquipmentModel(id: "dm_spin_wrap", name: "Spin Wrap", brandID: "dinkmaster", slot: .wristband, baseStat: .spin),
            EquipmentModel(id: "dm_focus_cap", name: "Focus Cap", brandID: "dinkmaster", slot: .headwear, baseStat: .focus),
            EquipmentModel(id: "dm_steady_visor", name: "Steady Visor", brandID: "dinkmaster", slot: .headwear, baseStat: .consistency),
        ]

        // --- CourtKraft (paddle, shoes, shirt) ---
        models += [
            EquipmentModel(id: "ck_hammer", name: "Hammer", brandID: "court_kraft", slot: .paddle, baseStat: .power),
            EquipmentModel(id: "ck_control", name: "Control", brandID: "court_kraft", slot: .paddle, baseStat: .accuracy),
            EquipmentModel(id: "ck_runner", name: "Runner", brandID: "court_kraft", slot: .shoes, baseStat: .speed),
            EquipmentModel(id: "ck_anchor", name: "Anchor", brandID: "court_kraft", slot: .shoes, baseStat: .defense),
            EquipmentModel(id: "ck_enduro_tee", name: "Enduro Tee", brandID: "court_kraft", slot: .shirt, baseStat: .stamina),
            EquipmentModel(id: "ck_shield_jersey", name: "Shield Jersey", brandID: "court_kraft", slot: .shirt, baseStat: .defense),
        ]

        // --- RallyCo (shirt, bottoms, wristband) ---
        models += [
            EquipmentModel(id: "rc_marathon", name: "Marathon", brandID: "rally_co", slot: .shirt, baseStat: .stamina),
            EquipmentModel(id: "rc_clutch_tee", name: "Clutch Tee", brandID: "rally_co", slot: .shirt, baseStat: .clutch),
            EquipmentModel(id: "rc_steady_shirt", name: "Steady Shirt", brandID: "rally_co", slot: .shirt, baseStat: .consistency),
            EquipmentModel(id: "rc_stride", name: "Stride", brandID: "rally_co", slot: .bottoms, baseStat: .speed),
            EquipmentModel(id: "rc_anchor_shorts", name: "Anchor Shorts", brandID: "rally_co", slot: .bottoms, baseStat: .positioning),
            EquipmentModel(id: "rc_reflex_wrap", name: "Reflex Wrap", brandID: "rally_co", slot: .wristband, baseStat: .reflexes),
            EquipmentModel(id: "rc_spin_sleeve", name: "Spin Sleeve", brandID: "rally_co", slot: .wristband, baseStat: .spin),
        ]

        // --- Zenith Gear (shoes, bottoms, headwear) ---
        models += [
            EquipmentModel(id: "zg_velocity", name: "Velocity", brandID: "zenith_gear", slot: .shoes, baseStat: .speed),
            EquipmentModel(id: "zg_pivot", name: "Pivot", brandID: "zenith_gear", slot: .shoes, baseStat: .positioning),
            EquipmentModel(id: "zg_reflex_shoe", name: "Reflex", brandID: "zenith_gear", slot: .shoes, baseStat: .reflexes),
            EquipmentModel(id: "zg_sprint", name: "Sprint", brandID: "zenith_gear", slot: .bottoms, baseStat: .speed),
            EquipmentModel(id: "zg_enduro_pants", name: "Enduro Pants", brandID: "zenith_gear", slot: .bottoms, baseStat: .stamina),
            EquipmentModel(id: "zg_ice_cap", name: "Ice Cap", brandID: "zenith_gear", slot: .headwear, baseStat: .clutch),
            EquipmentModel(id: "zg_zone_visor", name: "Zone Visor", brandID: "zenith_gear", slot: .headwear, baseStat: .consistency),
        ]

        // --- Iron Wall (paddle, shirt, shoes) ---
        models += [
            EquipmentModel(id: "iw_fortress", name: "Fortress", brandID: "iron_wall", slot: .paddle, baseStat: .consistency),
            EquipmentModel(id: "iw_bulwark", name: "Bulwark", brandID: "iron_wall", slot: .paddle, baseStat: .accuracy),
            EquipmentModel(id: "iw_guardian", name: "Guardian", brandID: "iron_wall", slot: .shirt, baseStat: .defense),
            EquipmentModel(id: "iw_resolve", name: "Resolve", brandID: "iron_wall", slot: .shirt, baseStat: .clutch),
            EquipmentModel(id: "iw_sentinel", name: "Sentinel", brandID: "iron_wall", slot: .shoes, baseStat: .defense),
            EquipmentModel(id: "iw_warden", name: "Warden", brandID: "iron_wall", slot: .shoes, baseStat: .positioning),
        ]

        // --- Apex Athlete (shirt, bottoms, headwear, wristband) ---
        models += [
            EquipmentModel(id: "aa_peak", name: "Peak", brandID: "apex_athlete", slot: .shirt, baseStat: .stamina),
            EquipmentModel(id: "aa_clutch_jersey", name: "Clutch Jersey", brandID: "apex_athlete", slot: .shirt, baseStat: .clutch),
            EquipmentModel(id: "aa_agility", name: "Agility", brandID: "apex_athlete", slot: .bottoms, baseStat: .speed),
            EquipmentModel(id: "aa_court_shorts", name: "Court Shorts", brandID: "apex_athlete", slot: .bottoms, baseStat: .positioning),
            EquipmentModel(id: "aa_nerve_cap", name: "Nerve Cap", brandID: "apex_athlete", slot: .headwear, baseStat: .clutch),
            EquipmentModel(id: "aa_laser_visor", name: "Laser Visor", brandID: "apex_athlete", slot: .headwear, baseStat: .accuracy),
            EquipmentModel(id: "aa_control_band", name: "Control Band", brandID: "apex_athlete", slot: .wristband, baseStat: .accuracy),
            EquipmentModel(id: "aa_twist_wrap", name: "Twist Wrap", brandID: "apex_athlete", slot: .wristband, baseStat: .spin),
        ]

        // --- Vortex (paddle only) ---
        models += [
            EquipmentModel(id: "vx_cyclone", name: "Cyclone", brandID: "vortex_paddles", slot: .paddle, baseStat: .spin),
            EquipmentModel(id: "vx_tornado", name: "Tornado", brandID: "vortex_paddles", slot: .paddle, baseStat: .power),
            EquipmentModel(id: "vx_twister", name: "Twister", brandID: "vortex_paddles", slot: .paddle, baseStat: .accuracy),
        ]

        // --- ThunderStrike (paddle only) ---
        models += [
            EquipmentModel(id: "ts_bolt", name: "Bolt", brandID: "thunder_strike", slot: .paddle, baseStat: .power),
            EquipmentModel(id: "ts_surge", name: "Surge", brandID: "thunder_strike", slot: .paddle, baseStat: .power),
            EquipmentModel(id: "ts_arc", name: "Arc", brandID: "thunder_strike", slot: .paddle, baseStat: .accuracy),
        ]

        // --- SwiftSole (shoes only) ---
        models += [
            EquipmentModel(id: "ss_dash", name: "Dash", brandID: "swift_sole", slot: .shoes, baseStat: .speed),
            EquipmentModel(id: "ss_flash", name: "Flash", brandID: "swift_sole", slot: .shoes, baseStat: .speed),
            EquipmentModel(id: "ss_react", name: "React", brandID: "swift_sole", slot: .shoes, baseStat: .reflexes),
        ]

        // --- GroundForce (shoes only) ---
        models += [
            EquipmentModel(id: "gf_titan", name: "Titan", brandID: "ground_force", slot: .shoes, baseStat: .defense),
            EquipmentModel(id: "gf_anchor", name: "Anchor", brandID: "ground_force", slot: .shoes, baseStat: .positioning),
            EquipmentModel(id: "gf_base", name: "Base", brandID: "ground_force", slot: .shoes, baseStat: .positioning),
        ]

        // --- EnduroWear (shirt only) ---
        models += [
            EquipmentModel(id: "ew_ironlung", name: "Iron Lung", brandID: "enduro_wear", slot: .shirt, baseStat: .stamina),
            EquipmentModel(id: "ew_grit", name: "Grit", brandID: "enduro_wear", slot: .shirt, baseStat: .consistency),
            EquipmentModel(id: "ew_resolve", name: "Resolve", brandID: "enduro_wear", slot: .shirt, baseStat: .defense),
        ]

        // --- FlexForm (bottoms only) ---
        models += [
            EquipmentModel(id: "ff_blitz", name: "Blitz", brandID: "flex_form", slot: .bottoms, baseStat: .speed),
            EquipmentModel(id: "ff_pivot", name: "Pivot", brandID: "flex_form", slot: .bottoms, baseStat: .positioning),
            EquipmentModel(id: "ff_enduro", name: "Enduro", brandID: "flex_form", slot: .bottoms, baseStat: .stamina),
        ]

        // --- FocusBand (headwear only) ---
        models += [
            EquipmentModel(id: "fb_zen", name: "Zen", brandID: "focus_band", slot: .headwear, baseStat: .clutch),
            EquipmentModel(id: "fb_focus", name: "Focus", brandID: "focus_band", slot: .headwear, baseStat: .focus),
            EquipmentModel(id: "fb_steady", name: "Steady", brandID: "focus_band", slot: .headwear, baseStat: .consistency),
            EquipmentModel(id: "fb_hawk", name: "Hawk", brandID: "focus_band", slot: .headwear, baseStat: .accuracy),
        ]

        // --- GripTech (wristband only) ---
        models += [
            EquipmentModel(id: "gt_torque", name: "Torque", brandID: "grip_tech", slot: .wristband, baseStat: .spin),
            EquipmentModel(id: "gt_lock", name: "Lock", brandID: "grip_tech", slot: .wristband, baseStat: .accuracy),
            EquipmentModel(id: "gt_snap", name: "Snap", brandID: "grip_tech", slot: .wristband, baseStat: .reflexes),
        ]

        return models
    }()

    // MARK: - Lookup Helpers

    static func brands(for slot: EquipmentSlot) -> [EquipmentBrand] {
        allBrands.filter { $0.slots.contains(slot) }
    }

    static func models(for brandID: String, slot: EquipmentSlot) -> [EquipmentModel] {
        allModels.filter { $0.brandID == brandID && $0.slot == slot }
    }

    static func brand(for id: String) -> EquipmentBrand? {
        allBrands.first { $0.id == id }
    }

    static func model(for id: String) -> EquipmentModel? {
        allModels.first { $0.id == id }
    }

    static func randomModel(for slot: EquipmentSlot, using rng: RandomSource) -> EquipmentModel {
        let slotBrands = brands(for: slot)
        let brand = slotBrands[rng.nextInt(in: 0...slotBrands.count - 1)]
        let brandModels = models(for: brand.id, slot: slot)
        return brandModels[rng.nextInt(in: 0...brandModels.count - 1)]
    }
}
