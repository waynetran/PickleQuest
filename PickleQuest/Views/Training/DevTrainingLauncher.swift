import SwiftUI

// TODO: Remove this entire file — temporary dev shortcut to test interactive drills

/// Dev-only view that launches directly into an interactive drill without navigating through the normal app flow.
struct DevTrainingLauncher: View {
    @Environment(AppState.self) private var appState
    @State private var showDrill = true
    @State private var drillType: DrillType = .baselineRally
    @State private var showLevelPicker = false
    @State private var showPracticeMatch = false
    @State private var practiceMatchNPC: NPC?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showDrill {
                InteractiveDrillView(
                    drill: TrainingDrill(type: drillType),
                    statGained: .accuracy,
                    playerStats: appState.player.stats,
                    appearance: appState.player.appearance,
                    coachAppearance: .defaultOpponent,
                    coachLevel: 3,
                    coachPersonality: CoachPersonality(type: .jokester),
                    playerEnergy: 100.0,
                    coachEnergy: 100.0,
                    onComplete: { result in
                        print("[DEV] Drill complete: \(result.performanceGrade.rawValue) — \(result.successfulReturns)/\(result.totalBalls) returns, longest rally: \(result.longestRally)")
                        showDrill = false
                    }
                )
            } else if showPracticeMatch, let npc = practiceMatchNPC {
                InteractiveMatchView(
                    player: appState.player,
                    npc: npc,
                    npcAppearance: .defaultOpponent,
                    isRated: false,
                    wagerAmount: 0
                ) { _ in
                    showPracticeMatch = false
                    practiceMatchNPC = nil
                }
            } else {
                VStack(spacing: 20) {
                    Text("Drill Complete")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    // Drill type picker
                    ForEach(DrillType.allCases, id: \.self) { type in
                        Button("Play \(type.displayName)") {
                            drillType = type
                            showDrill = true
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(drillType == type ? .green : .blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 40)
                    }

                    // Practice Match button
                    Button("Practice Match") {
                        showLevelPicker = true
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 40)

                    Spacer().frame(height: 20)

                    Button("Exit to Normal App") {
                        appState.devTrainingEnabled = false
                        appState.appPhase = .loading
                    }
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.red.opacity(0.8))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .sheet(isPresented: $showLevelPicker) {
            practiceMatchLevelPicker
        }
    }

    // MARK: - Practice Match Level Picker

    private static let practiceMatchLevels: [(dupr: Double, label: String)] = [
        (2.0, "2.0"), (2.5, "2.5"), (3.0, "3.0"), (3.5, "3.5"),
        (4.0, "4.0"), (4.5, "4.5"), (5.0, "5.0"),
        (6.0, "6.0"), (7.0, "7.0"), (8.0, "Impossible")
    ]

    private var practiceMatchLevelPicker: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Self.practiceMatchLevels, id: \.dupr) { level in
                        Button {
                            showLevelPicker = false
                            practiceMatchNPC = NPC.practiceOpponent(dupr: level.dupr)
                            showPracticeMatch = true
                        } label: {
                            HStack {
                                Text("DUPR \(level.label)")
                                    .font(.body.bold())
                                Spacer()
                                Text(difficultyLabel(for: level.dupr))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Choose Opponent Level")
                }
            }
            .navigationTitle("Practice Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showLevelPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func difficultyLabel(for dupr: Double) -> String {
        switch dupr {
        case ..<3.0: return "Beginner"
        case ..<4.0: return "Intermediate"
        case ..<5.0: return "Advanced"
        case ..<6.5: return "Expert"
        case ..<8.0: return "Master"
        default: return "Impossible"
        }
    }
}
