import Foundation

struct CharacterAppearance: Codable, Equatable, Hashable, Sendable {
    var hairColor: String
    var skinTone: String
    var shirtColor: String
    var shortsColor: String
    var headbandColor: String
    var shoeColor: String
    var paddleColor: String
    var spriteSheet: String = "character1-Sheet"

    init(hairColor: String, skinTone: String, shirtColor: String, shortsColor: String,
         headbandColor: String, shoeColor: String, paddleColor: String, spriteSheet: String = "character1-Sheet") {
        self.hairColor = hairColor
        self.skinTone = skinTone
        self.shirtColor = shirtColor
        self.shortsColor = shortsColor
        self.headbandColor = headbandColor
        self.shoeColor = shoeColor
        self.paddleColor = paddleColor
        self.spriteSheet = spriteSheet
    }

    // MARK: - Codable (backwards-compatible with older saves)

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hairColor = try c.decode(String.self, forKey: .hairColor)
        skinTone = try c.decode(String.self, forKey: .skinTone)
        shirtColor = try c.decode(String.self, forKey: .shirtColor)
        shortsColor = try c.decode(String.self, forKey: .shortsColor)
        headbandColor = try c.decode(String.self, forKey: .headbandColor)
        shoeColor = try c.decode(String.self, forKey: .shoeColor)
        paddleColor = try c.decode(String.self, forKey: .paddleColor)
        spriteSheet = try c.decodeIfPresent(String.self, forKey: .spriteSheet) ?? "character1-Sheet"
    }

    static let defaultPlayer = CharacterAppearance(
        hairColor: "#5D4037",
        skinTone: "#D2A373",
        shirtColor: "#3498DB",
        shortsColor: "#2C3E50",
        headbandColor: "#3498DB",
        shoeColor: "#ECEFF1",
        paddleColor: "#37474F",
        spriteSheet: "character1-Sheet"
    )

    static let defaultOpponent = CharacterAppearance(
        hairColor: "#212121",
        skinTone: "#D2A373",
        shirtColor: "#E74C3C",
        shortsColor: "#2C3E50",
        headbandColor: "#E74C3C",
        shoeColor: "#ECEFF1",
        paddleColor: "#37474F",
        spriteSheet: "character2-Sheet"
    )
}
