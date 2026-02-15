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
