import Foundation

@MainActor
@Observable
final class CharacterCreationViewModel {
    var playerName: String = ""
    var selectedPreset: CharacterPreset = CharacterPreset.allPresets[0]
    var selectedSpriteSheet: String = "character1-Sheet"
    var selectedPersonality: NPCPersonality = .allRounder
    var currentStep: CreationStep = .name

    enum CreationStep: Int, CaseIterable {
        case name
        case appearance
        case personality
    }

    /// Preview appearance combining preset colors with selected sprite sheet
    var previewAppearance: CharacterAppearance {
        var appearance = selectedPreset.appearance
        appearance.spriteSheet = selectedSpriteSheet
        return appearance
    }

    var isNameValid: Bool {
        let trimmed = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 1 && trimmed.count <= 20
    }

    var canAdvance: Bool {
        switch currentStep {
        case .name: return isNameValid
        case .appearance: return true
        case .personality: return true
        }
    }

    var isLastStep: Bool {
        currentStep == .personality
    }

    func advance() {
        guard let nextIndex = CreationStep.allCases.firstIndex(of: currentStep).map({ $0 + 1 }),
              nextIndex < CreationStep.allCases.count else { return }
        currentStep = CreationStep.allCases[nextIndex]
    }

    func goBack() {
        guard let prevIndex = CreationStep.allCases.firstIndex(of: currentStep).map({ $0 - 1 }),
              prevIndex >= 0 else { return }
        currentStep = CreationStep.allCases[prevIndex]
    }

    func createPlayer() -> Player {
        let name = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        var player = Player.newPlayer(name: name)
        var appearance = selectedPreset.appearance
        appearance.spriteSheet = selectedSpriteSheet
        player.appearance = appearance
        player.personality = selectedPersonality

        // Apply personality stat bias (keeps total equal)
        for (stat, bias) in selectedPersonality.statBias {
            let current = player.stats.stat(stat)
            player.stats.setStat(stat, value: current + bias)
        }

        return player
    }
}
