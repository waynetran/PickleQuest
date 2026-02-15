import Foundation

struct SetBonusTier: Sendable, Codable, Equatable {
    let piecesRequired: Int
    let bonuses: [StatBonus]
    let label: String
}

struct EquipmentSet: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let pieces: Set<EquipmentSlot>
    let bonusTiers: [SetBonusTier]

    static func set(for id: String) -> EquipmentSet? {
        allSets.first { $0.id == id }
    }

    static let allSets: [EquipmentSet] = [
        EquipmentSet(
            id: "court_king",
            name: "Court King",
            description: "Dominate every inch of the court with raw power and precision.",
            pieces: [.paddle, .shirt, .shoes, .bottoms, .headwear, .wristband],
            bonusTiers: [
                SetBonusTier(piecesRequired: 2, bonuses: [StatBonus(stat: .power, value: 3)], label: "Royal Strike"),
                SetBonusTier(piecesRequired: 4, bonuses: [StatBonus(stat: .power, value: 5), StatBonus(stat: .accuracy, value: 3)], label: "King's Authority"),
                SetBonusTier(piecesRequired: 6, bonuses: [StatBonus(stat: .power, value: 8), StatBonus(stat: .accuracy, value: 5), StatBonus(stat: .speed, value: 3)], label: "Court Coronation")
            ]
        ),
        EquipmentSet(
            id: "speed_demon",
            name: "Speed Demon",
            description: "Blinding speed and razor-sharp reflexes leave opponents frozen.",
            pieces: [.shoes, .bottoms, .wristband, .headwear],
            bonusTiers: [
                SetBonusTier(piecesRequired: 2, bonuses: [StatBonus(stat: .speed, value: 3)], label: "Quick Feet"),
                SetBonusTier(piecesRequired: 3, bonuses: [StatBonus(stat: .speed, value: 5), StatBonus(stat: .reflexes, value: 3)], label: "Demon Rush"),
                SetBonusTier(piecesRequired: 4, bonuses: [StatBonus(stat: .speed, value: 8), StatBonus(stat: .reflexes, value: 5), StatBonus(stat: .positioning, value: 3)], label: "Terminal Velocity")
            ]
        ),
        EquipmentSet(
            id: "iron_wall",
            name: "Iron Wall",
            description: "An impenetrable defense that turns every rally into a war of attrition.",
            pieces: [.paddle, .shirt, .shoes, .bottoms],
            bonusTiers: [
                SetBonusTier(piecesRequired: 2, bonuses: [StatBonus(stat: .defense, value: 3)], label: "Stone Guard"),
                SetBonusTier(piecesRequired: 3, bonuses: [StatBonus(stat: .defense, value: 5), StatBonus(stat: .positioning, value: 3)], label: "Fortress"),
                SetBonusTier(piecesRequired: 4, bonuses: [StatBonus(stat: .defense, value: 8), StatBonus(stat: .positioning, value: 5), StatBonus(stat: .reflexes, value: 3)], label: "Iron Curtain")
            ]
        ),
        EquipmentSet(
            id: "mind_games",
            name: "Mind Games",
            description: "Outsmart opponents with clutch plays and maddening consistency.",
            pieces: [.paddle, .headwear, .wristband, .shirt],
            bonusTiers: [
                SetBonusTier(piecesRequired: 2, bonuses: [StatBonus(stat: .clutch, value: 3)], label: "Mind Reader"),
                SetBonusTier(piecesRequired: 3, bonuses: [StatBonus(stat: .clutch, value: 5), StatBonus(stat: .consistency, value: 3)], label: "Psych Out"),
                SetBonusTier(piecesRequired: 4, bonuses: [StatBonus(stat: .clutch, value: 8), StatBonus(stat: .consistency, value: 5), StatBonus(stat: .spin, value: 3)], label: "Checkmate")
            ]
        ),
        EquipmentSet(
            id: "endurance_pro",
            name: "Endurance Pro",
            description: "Outlast anyone on the court with tireless energy and steady play.",
            pieces: [.shoes, .shirt, .bottoms, .wristband],
            bonusTiers: [
                SetBonusTier(piecesRequired: 2, bonuses: [StatBonus(stat: .stamina, value: 3)], label: "Second Wind"),
                SetBonusTier(piecesRequired: 3, bonuses: [StatBonus(stat: .stamina, value: 5), StatBonus(stat: .consistency, value: 3)], label: "Marathon Mode"),
                SetBonusTier(piecesRequired: 4, bonuses: [StatBonus(stat: .stamina, value: 8), StatBonus(stat: .consistency, value: 5), StatBonus(stat: .defense, value: 3)], label: "Ironman")
            ]
        )
    ]
}
