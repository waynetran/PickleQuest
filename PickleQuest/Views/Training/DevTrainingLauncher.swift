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
    @State private var showHeadlessRunner = false
    @State private var showMatchComparison = false

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
                ) { result in
                    if let npc = practiceMatchNPC {
                        Task {
                            let entry = DevMatchLogEntry(
                                id: UUID(),
                                date: Date(),
                                source: .interactive,
                                playerDUPR: appState.player.duprRating,
                                opponentDUPR: npc.duprRating,
                                playerScore: result.finalScore.playerPoints,
                                opponentScore: result.finalScore.opponentPoints,
                                didPlayerWin: result.didPlayerWin,
                                totalPoints: result.totalPoints,
                                avgRallyLength: result.playerStats.averageRallyLength,
                                playerAces: result.playerStats.aces,
                                playerWinners: result.playerStats.winners,
                                playerErrors: result.playerStats.unforcedErrors,
                                opponentAces: result.opponentStats.aces,
                                opponentWinners: result.opponentStats.winners,
                                opponentErrors: result.opponentStats.unforcedErrors,
                                matchDurationSeconds: result.duration
                            )
                            await DevMatchLogStore.shared.append(entry)
                        }
                    }
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

                    // Headless Validation button
                    Button("Headless Validation") {
                        showHeadlessRunner = true
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 40)

                    // Match Data button
                    Button("Match Data") {
                        showMatchComparison = true
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.teal)
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
        .sheet(isPresented: $showHeadlessRunner) {
            DevHeadlessRunnerView()
        }
        .sheet(isPresented: $showMatchComparison) {
            DevMatchComparisonView()
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
