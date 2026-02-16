import SwiftUI

struct CharacterCreationView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel = CharacterCreationViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step indicator
                stepIndicator
                    .padding(.top, 8)

                // Content
                TabView(selection: $viewModel.currentStep) {
                    nameStep
                        .tag(CharacterCreationViewModel.CreationStep.name)

                    appearanceStep
                        .tag(CharacterCreationViewModel.CreationStep.appearance)

                    personalityStep
                        .tag(CharacterCreationViewModel.CreationStep.personality)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.currentStep)

                // Bottom buttons
                bottomButtons
                    .padding()
            }
            .navigationTitle("Create Your Player")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(CharacterCreationViewModel.CreationStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(step.rawValue <= viewModel.currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Name Step

    private var nameStep: some View {
        VStack(spacing: 24) {
            Spacer()

            AnimatedSpriteView(
                appearance: viewModel.previewAppearance,
                size: 100,
                animationState: .idleFront
            )

            Text("What's your name, player?")
                .font(.title2.bold())

            TextField("Enter your name", text: $viewModel.playerName)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .submitLabel(.next)
                .onSubmit {
                    if viewModel.canAdvance { viewModel.advance() }
                }

            Text("1-20 characters")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
            Spacer()
        }
        .padding()
    }

    // MARK: - Appearance Step

    private var appearanceStep: some View {
        VStack(spacing: 20) {
            Text("Choose Your Look")
                .font(.title2.bold())
                .padding(.top)

            // Large preview
            AnimatedSpriteView(
                appearance: viewModel.previewAppearance,
                size: 120,
                animationState: .idleFront
            )
            .padding(.vertical, 8)

            // Body type picker
            HStack(spacing: 16) {
                spriteSheetOption("character1-Sheet", label: "Body 1")
                spriteSheetOption("character2-Sheet", label: "Body 2")
            }

            Text(viewModel.selectedPreset.name)
                .font(.headline)
            Text(viewModel.selectedPreset.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Horizontal scroll of presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(CharacterPreset.allPresets) { preset in
                        presetCard(preset)
                    }
                }
                .padding(.horizontal)
            }

            Spacer()
        }
    }

    private func spriteSheetOption(_ sheet: String, label: String) -> some View {
        let isSelected = viewModel.selectedSpriteSheet == sheet
        var previewApp = viewModel.selectedPreset.appearance
        previewApp.spriteSheet = sheet
        return VStack(spacing: 6) {
            AnimatedSpriteView(
                appearance: previewApp,
                size: 56,
                animationState: .idleFront
            )
            Text(label)
                .font(.caption.bold())
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .onTapGesture {
            viewModel.selectedSpriteSheet = sheet
        }
    }

    private func presetCard(_ preset: CharacterPreset) -> some View {
        VStack(spacing: 6) {
            AnimatedSpriteView(
                appearance: preset.appearance,
                size: 48,
                animationState: .idleFront
            )

            Text(preset.name)
                .font(.caption2)
                .lineLimit(1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(preset.id == viewModel.selectedPreset.id ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(preset.id == viewModel.selectedPreset.id ? Color.accentColor : .clear, lineWidth: 2)
        )
        .onTapGesture {
            viewModel.selectedPreset = preset
        }
    }

    // MARK: - Personality Step

    private var personalityStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Choose Your Playstyle")
                    .font(.title2.bold())
                    .padding(.top)

                ForEach(NPCPersonality.allCases, id: \.self) { personality in
                    personalityCard(personality)
                }
            }
            .padding(.horizontal)
        }
    }

    private func personalityCard(_ personality: NPCPersonality) -> some View {
        let isSelected = personality == viewModel.selectedPersonality
        return HStack(spacing: 12) {
            Image(systemName: personality.displayIcon)
                .font(.title2)
                .foregroundStyle(isSelected ? .white : .accentColor)
                .frame(width: 44, height: 44)
                .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(personality.displayName)
                    .font(.headline)
                Text(personality.displayDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .onTapGesture {
            viewModel.selectedPersonality = personality
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack {
            if viewModel.currentStep != .name {
                Button("Back") {
                    viewModel.goBack()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if viewModel.isLastStep {
                Button("Create Character") {
                    Task { await createCharacter() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Next") {
                    viewModel.advance()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canAdvance)
            }
        }
    }

    private func createCharacter() async {
        let player = viewModel.createPlayer()
        let inventory = MockInventoryService.starterInventory()
        let consumables = MockInventoryService.starterConsumables()

        let bundle = SavedPlayerBundle(
            player: player,
            inventory: inventory,
            consumables: consumables,
            fogCells: [],
            tutorialCompleted: false
        )

        do {
            try await container.persistenceService.createPlayer(bundle)
            appState.loadFromBundle(bundle)
            await resetServices(inventory: inventory, consumables: consumables)
            appState.appPhase = .tutorialMatch
        } catch {
            // Fallback: proceed without persistence
            appState.loadFromBundle(bundle)
            await resetServices(inventory: inventory, consumables: consumables)
            appState.appPhase = .tutorialMatch
        }
    }

    private func resetServices(inventory: [Equipment], consumables: [Consumable]) async {
        if let mockInventory = container.inventoryService as? MockInventoryService {
            await mockInventory.reset(inventory: inventory, consumables: consumables)
        }
    }
}

// Make NPCPersonality CaseIterable for the personality picker
extension NPCPersonality: CaseIterable {
    static var allCases: [NPCPersonality] {
        [.aggressive, .defensive, .allRounder, .speedster, .strategist]
    }
}
