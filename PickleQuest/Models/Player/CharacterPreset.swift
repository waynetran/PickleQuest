import Foundation

struct CharacterPreset: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let appearance: CharacterAppearance

    static let allPresets: [CharacterPreset] = [
        CharacterPreset(
            id: "classic_blue",
            name: "Classic Blue",
            description: "The tried-and-true court look",
            appearance: CharacterAppearance(
                hairColor: "#5D4037",
                skinTone: "#D2A373",
                shirtColor: "#3498DB",
                shortsColor: "#2C3E50",
                headbandColor: "#3498DB",
                shoeColor: "#ECEFF1",
                paddleColor: "#37474F"
            )
        ),
        CharacterPreset(
            id: "fire_red",
            name: "Fire Red",
            description: "Bring the heat to every rally",
            appearance: CharacterAppearance(
                hairColor: "#212121",
                skinTone: "#C68642",
                shirtColor: "#E74C3C",
                shortsColor: "#1A1A2E",
                headbandColor: "#FF6B35",
                shoeColor: "#E0E0E0",
                paddleColor: "#C0392B"
            )
        ),
        CharacterPreset(
            id: "chill_green",
            name: "Chill Green",
            description: "Cool, calm, and collected",
            appearance: CharacterAppearance(
                hairColor: "#3E2723",
                skinTone: "#FFCD94",
                shirtColor: "#27AE60",
                shortsColor: "#2C3E50",
                headbandColor: "#2ECC71",
                shoeColor: "#F5F5F5",
                paddleColor: "#1E8449"
            )
        ),
        CharacterPreset(
            id: "sunset_orange",
            name: "Sunset Orange",
            description: "Golden hour on the court",
            appearance: CharacterAppearance(
                hairColor: "#4E342E",
                skinTone: "#D2A373",
                shirtColor: "#F39C12",
                shortsColor: "#34495E",
                headbandColor: "#E67E22",
                shoeColor: "#FAFAFA",
                paddleColor: "#D35400"
            )
        ),
        CharacterPreset(
            id: "royal_purple",
            name: "Royal Purple",
            description: "Play like pickleball royalty",
            appearance: CharacterAppearance(
                hairColor: "#1A1A1A",
                skinTone: "#8D5524",
                shirtColor: "#8E44AD",
                shortsColor: "#2C3E50",
                headbandColor: "#9B59B6",
                shoeColor: "#E0E0E0",
                paddleColor: "#6C3483"
            )
        ),
        CharacterPreset(
            id: "shadow_black",
            name: "Shadow Black",
            description: "Sleek and mysterious",
            appearance: CharacterAppearance(
                hairColor: "#0D0D0D",
                skinTone: "#FFCD94",
                shirtColor: "#2C2C2C",
                shortsColor: "#1A1A1A",
                headbandColor: "#424242",
                shoeColor: "#BDBDBD",
                paddleColor: "#212121"
            )
        ),
        CharacterPreset(
            id: "golden_hour",
            name: "Golden Hour",
            description: "Shine bright on every point",
            appearance: CharacterAppearance(
                hairColor: "#5D4037",
                skinTone: "#C68642",
                shirtColor: "#F1C40F",
                shortsColor: "#2C3E50",
                headbandColor: "#F9E74D",
                shoeColor: "#FFFFFF",
                paddleColor: "#D4AC0D"
            )
        ),
        CharacterPreset(
            id: "arctic_white",
            name: "Arctic White",
            description: "Ice cold under pressure",
            appearance: CharacterAppearance(
                hairColor: "#795548",
                skinTone: "#FFDBAC",
                shirtColor: "#ECF0F1",
                shortsColor: "#BDC3C7",
                headbandColor: "#FFFFFF",
                shoeColor: "#F5F5F5",
                paddleColor: "#95A5A6"
            )
        ),
    ]
}
