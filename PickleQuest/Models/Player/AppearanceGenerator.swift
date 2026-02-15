import Foundation

enum AppearanceGenerator {
    // MARK: - Hair Colors
    private static let hairColors: [String] = [
        "#212121", // black
        "#5D4037", // dark brown
        "#8D6E63", // medium brown
        "#A1887F", // light brown
        "#F9A825", // blonde
        "#BF360C", // auburn
        "#D84315", // ginger
        "#78909C"  // gray
    ]

    // MARK: - Skin Tones
    private static let skinTones: [String] = [
        "#FDDBB8", // light
        "#E8B88A", // light-medium
        "#D2A373", // medium
        "#B07D56", // medium-dark
        "#8D5524", // dark
        "#6B3A1F"  // deep
    ]

    // MARK: - Shirt Palettes by Personality
    private static let aggressiveShirts: [String] = ["#E74C3C", "#C0392B", "#FF5722", "#D32F2F"]
    private static let defensiveShirts: [String] = ["#2196F3", "#1976D2", "#03A9F4", "#0288D1"]
    private static let speedsterShirts: [String] = ["#FFC107", "#FFB300", "#FF9800", "#F57C00"]
    private static let strategistShirts: [String] = ["#9C27B0", "#7B1FA2", "#AB47BC", "#8E24AA"]
    private static let allRounderShirts: [String] = ["#4CAF50", "#388E3C", "#66BB6A", "#2E7D32"]

    // MARK: - Shorts Colors
    private static let shortsColors: [String] = [
        "#2C3E50", "#1A237E", "#263238", "#37474F",
        "#3E2723", "#212121", "#455A64", "#1B5E20"
    ]

    // MARK: - Shoe Colors
    private static let shoeColors: [String] = [
        "#ECEFF1", "#F5F5F5", "#E0E0E0", "#B0BEC5",
        "#FF5722", "#2196F3", "#4CAF50", "#212121"
    ]

    // MARK: - Paddle Colors
    private static let paddleColors: [String] = [
        "#37474F", "#1565C0", "#C62828", "#2E7D32",
        "#F57F17", "#6A1B9A", "#00838F", "#212121"
    ]

    // MARK: - Generation

    static func appearance(for npc: NPC) -> CharacterAppearance {
        let hash = stableHash(from: npc.id)

        let hairIndex = hash[0] % hairColors.count
        let skinIndex = hash[1] % skinTones.count
        let shortsIndex = hash[2] % shortsColors.count
        let shoeIndex = hash[3] % shoeColors.count
        let paddleIndex = hash[4] % paddleColors.count

        let shirtPalette = shirtPalette(for: npc.personality)
        let shirtIndex = hash[5] % shirtPalette.count
        let shirtColor = shirtPalette[shirtIndex]

        var appearance = CharacterAppearance(
            hairColor: hairColors[hairIndex],
            skinTone: skinTones[skinIndex],
            shirtColor: shirtColor,
            shortsColor: shortsColors[shortsIndex],
            headbandColor: shirtColor,
            shoeColor: shoeColors[shoeIndex],
            paddleColor: paddleColors[paddleIndex]
        )

        // Higher difficulty → more vivid colors (increase saturation)
        if npc.difficulty >= .expert {
            appearance = boostSaturation(appearance, factor: 1.15)
        }

        return appearance
    }

    // MARK: - Helpers

    private static func shirtPalette(for personality: NPCPersonality) -> [String] {
        switch personality {
        case .aggressive: return aggressiveShirts
        case .defensive: return defensiveShirts
        case .speedster: return speedsterShirts
        case .strategist: return strategistShirts
        case .allRounder: return allRounderShirts
        }
    }

    private static func stableHash(from uuid: UUID) -> [Int] {
        let uuidString = uuid.uuidString
        var bytes = [Int]()
        for (i, char) in uuidString.unicodeScalars.enumerated() {
            if char != "-" {
                bytes.append(Int(char.value) &* (i + 1))
            }
        }
        // Generate 8 stable indices by combining byte pairs
        var result = [Int]()
        for i in stride(from: 0, to: min(bytes.count, 16), by: 2) {
            let combined = abs(bytes[i] &+ (i + 1 < bytes.count ? bytes[i + 1] * 7 : 0))
            result.append(combined)
        }
        return result
    }

    private static func boostSaturation(_ appearance: CharacterAppearance, factor: Double) -> CharacterAppearance {
        // Only boost shirt color — keeps it simple and avoids unnatural skin/hair
        var result = appearance
        result.shirtColor = adjustSaturation(hex: appearance.shirtColor, factor: factor)
        return result
    }

    private static func adjustSaturation(hex: String, factor: Double) -> String {
        let stripped = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgbValue: UInt64 = 0
        Scanner(string: stripped).scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let l = (maxC + minC) / 2.0

        // Move each channel away from luminance by factor
        let newR = min(1, max(0, l + (r - l) * factor))
        let newG = min(1, max(0, l + (g - l) * factor))
        let newB = min(1, max(0, l + (b - l) * factor))

        return String(format: "#%02X%02X%02X", Int(newR * 255), Int(newG * 255), Int(newB * 255))
    }
}
