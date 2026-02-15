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

    func generateFlavorText(slot: EquipmentSlot, rarity: EquipmentRarity, statBonuses: [StatBonus]) -> String {
        let dominant = statBonuses.max(by: { $0.value < $1.value })?.stat
        let pool = flavorPool(slot: slot, rarity: rarity, dominantStat: dominant)
        return pool.randomElement(using: rng)
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
        case .bottoms:
            return ["Shorts", "Track Pants", "Athletic Skirt", "Court Leggings", "Gym Joggers"]
        case .headwear:
            return ["Cap", "Visor", "Headband", "Bucket Hat", "Snapback"]
        case .wristband:
            return ["Wristband", "Sweatband", "Arm Sleeve", "Wrist Wrap", "Bracer"]
        }
    }

    // MARK: - Flavor Text

    private func flavorPool(slot: EquipmentSlot, rarity: EquipmentRarity, dominantStat: StatType?) -> [String] {
        var pool: [String] = []

        // Slot-based humor
        switch slot {
        case .paddle:
            pool += [
                "Has more sweet spot than a bakery.",
                "Warning: may cause opponents to rethink life choices.",
                "Scientifically proven to make dinking 47% more satisfying.",
                "The last person who used this paddle retired undefeated. From rec play.",
                "Smells faintly of victory and grip tape.",
                "Handle worn smooth by a thousand third-shot drops.",
                "The sound it makes is basically a lullaby for opponents.",
                "Paddle tech so advanced it's basically cheating. Basically."
            ]
        case .shirt:
            pool += [
                "Moisture-wicking? More like moisture-obliterating.",
                "Makes you look 15% more athletic. Results may vary.",
                "The sweat stains add character, trust us.",
                "Opponents will be too distracted by your style to return serves.",
                "Comes pre-loaded with main character energy.",
                "Thread count so high it has its own zip code.",
                "Warning: may cause spontaneous compliments from strangers.",
                "Certified fresh by the Court Fashion Authority."
            ]
        case .shoes:
            pool += [
                "These shoes were made for sliding. And that's just what they'll do.",
                "Court grip so good you might forget how to fall.",
                "Your feet called. They said 'finally.'",
                "Tested on every court surface. Even that one weird one at the park.",
                "Warning: may cause excessive pivoting and celebration dances.",
                "The laces are basically load-bearing at this point.",
                "Squeaky on purpose. It's a power move.",
                "Ankle support? More like ankle therapy."
            ]
        case .bottoms:
            pool += [
                "Flexible enough for a split. Not that you should try one.",
                "Pockets deep enough for two pickleballs and your ego.",
                "The wind resistance is basically zero. The tan lines are not.",
                "Designed by someone who has definitely lunged for a dink before.",
                "These have seen things. Kitchen things.",
                "Athletic fit means they look good whether you win or lose.",
                "The secret to a great drop shot? Starts with the shorts.",
                "Compression technology: because gravity is not on your side."
            ]
        case .headwear:
            pool += [
                "Keeps the sun out of your eyes and the confidence in your game.",
                "Aerodynamic enough to shave 0.001 seconds off your reaction time.",
                "The brim has been scientifically angled for maximum intimidation.",
                "Sweatband included. You're going to need it.",
                "Certified to survive at least 200 'nice shot' head nods.",
                "Warning: may cause hat hair. Worth it.",
                "The rally cap your grandma warned you about.",
                "Blocks UV rays and bad vibes equally."
            ]
        case .wristband:
            pool += [
                "Absorbs sweat AND opponent tears.",
                "Your wrist called. It wants to thank you.",
                "Adds +10 to post-point fist pump satisfaction.",
                "Doubles as a tiny towel in emergencies.",
                "Endorsed by someone's uncle who's 'really good at pickleball.'",
                "The snap factor on this thing is immaculate.",
                "Wrist support so good you'll forget you have bones.",
                "Matches everything. Especially your winning attitude."
            ]
        }

        // Dominant stat humor
        if let stat = dominantStat {
            switch stat {
            case .power:
                pool += ["Caution: contains raw power.", "Not responsible for broken pickleballs.", "Goes to 11."]
            case .accuracy:
                pool += ["Pinpoint precision, zero excuses.", "Hits the line. Every. Time.", "Your opponents' corners are not safe."]
            case .spin:
                pool += ["Puts more spin on it than a politician.", "Warning: physics-defying trajectories ahead.", "The ball does things. Weird things."]
            case .speed:
                pool += ["Blink and you'll miss the point. Literally.", "Speed demon certified.", "Fast enough to make wind jealous."]
            case .defense:
                pool += ["Good luck getting anything past this.", "Built like a brick wall with better footwork.", "The kitchen is now a fortress."]
            case .reflexes:
                pool += ["Reaction time: basically precognition.", "Your reflexes called. They said 'you're welcome.'", "Catches things before they happen."]
            case .positioning:
                pool += ["Always in the right place. It's eerie.", "GPS-guided court awareness.", "The court is a chessboard and you're the queen."]
            case .clutch:
                pool += ["Ice in the veins, fire in the shots.", "Match point? More like comfort zone.", "Thrives under pressure like a deep-sea fish."]
            case .stamina:
                pool += ["Outlasts opponents and most batteries.", "Still fresh in the fifth game.", "Cardio is a personality trait now."]
            case .consistency:
                pool += ["Boring? No. Reliable? Absolutely.", "Error rate: statistically insignificant.", "Does the same thing. Perfectly. Every time."]
            }
        }

        // Rarity flair
        switch rarity {
        case .legendary:
            pool += ["Whispered about in locker rooms across the land.", "They say only the worthy can wield this."]
        case .epic:
            pool += ["Has its own fan club.", "Forged in the fires of a very competitive rec league."]
        default:
            break
        }

        return pool
    }
}

private extension Array {
    func randomElement(using rng: RandomSource) -> Element {
        let index = rng.nextInt(in: 0...count - 1)
        return self[index]
    }
}
