import Foundation

struct EquipmentNameGenerator: Sendable {
    private let rng: RandomSource

    init(rng: RandomSource = SystemRandomSource()) {
        self.rng = rng
    }

    func generateName(slot: EquipmentSlot, rarity: EquipmentRarity) -> String {
        let prefix = prefixes(for: rarity).randomElement(using: rng)
        let base = baseNames(for: slot).randomElement(using: rng)
        return "\(prefix) \(base)"
    }

    private func prefixes(for rarity: EquipmentRarity) -> [String] {
        switch rarity {
        case .common:
            return ["Basic", "Simple", "Plain", "Standard", "Starter"]
        case .uncommon:
            return ["Sturdy", "Reliable", "Refined", "Solid", "Improved"]
        case .rare:
            return ["Elite", "Superior", "Premium", "Advanced", "Pro"]
        case .epic:
            return ["Champion's", "Masterwork", "Fierce", "Blazing", "Thundering"]
        case .legendary:
            return ["Legendary", "Mythic", "Celestial", "Transcendent", "Apex"]
        }
    }

    private func baseNames(for slot: EquipmentSlot) -> [String] {
        switch slot {
        case .paddle:
            return ["Paddle", "Racket", "Striker", "Smasher", "Blade"]
        case .shirt:
            return ["Jersey", "Top", "Tee", "Compression Shirt", "Tank"]
        case .shoes:
            return ["Court Shoes", "Trainers", "Kicks", "Sneakers", "Runners"]
        case .shorts:
            return ["Shorts", "Athletic Shorts", "Court Shorts", "Training Shorts", "Flex Shorts"]
        case .eyewear:
            return ["Shades", "Sport Glasses", "Visor", "Goggles", "Sunglasses"]
        case .wristband:
            return ["Wristband", "Sweatband", "Arm Sleeve", "Wrist Wrap", "Bracer"]
        }
    }
}

private extension Array {
    func randomElement(using rng: RandomSource) -> Element {
        let index = rng.nextInt(in: 0...count - 1)
        return self[index]
    }
}
