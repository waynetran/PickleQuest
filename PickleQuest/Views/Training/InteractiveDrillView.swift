import SwiftUI
import SpriteKit

struct InteractiveDrillView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let drill: TrainingDrill
    let statGained: StatType
    let playerStats: PlayerStats
    let appearance: CharacterAppearance
    let coachAppearance: CharacterAppearance
    let coachLevel: Int
    let coachPersonality: CoachPersonality
    let playerEnergy: Double
    let coachEnergy: Double
    let onComplete: (InteractiveDrillResult) -> Void

    @State private var drillResult: InteractiveDrillResult?
    @State private var showInstructions = true
    @State private var scene: InteractiveDrillScene?
    @State private var showLevelPicker = false
    @State private var practiceMatchNPC: NPC?

    var body: some View {
        ZStack {
            // SpriteKit scene
            if let scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
            } else {
                Color(UIColor(hex: "#2C3E50"))
                    .ignoresSafeArea()
            }

            // Instruction overlay (before drill starts)
            if showInstructions {
                VStack {
                    Spacer()
                    instructionOverlay
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Exit button (top right, below HUD, during active drill only)
            if !showInstructions && drillResult == nil {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            scene?.skipDrill()
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 12)
                        .padding(.top, 110)
                    }
                    Spacer()
                }
            }

            // Result overlay (after drill ends)
            if let result = drillResult {
                VStack {
                    Spacer()
                    resultOverlay(result: result)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showInstructions)
        .animation(.easeInOut(duration: 0.3), value: drillResult != nil)
        .navigationBarBackButtonHidden(true)
        .task {
            scene = makeScene()
        }
        .sheet(isPresented: $showLevelPicker) {
            practiceMatchLevelPicker
        }
        .navigationDestination(item: $practiceMatchNPC) { npc in
            InteractiveMatchView(
                player: appState.player,
                npc: npc,
                npcAppearance: .defaultOpponent,
                isRated: false,
                wagerAmount: 0
            ) { _ in
                // Practice match — no rewards to process
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
        }
    }

    private func makeScene() -> InteractiveDrillScene {
        InteractiveDrillScene(
            drill: drill,
            statGained: statGained,
            playerStats: playerStats,
            appearance: appearance,
            coachAppearance: coachAppearance,
            coachLevel: coachLevel,
            coachPersonality: coachPersonality,
            playerEnergy: playerEnergy,
            coachEnergy: coachEnergy,
            onComplete: { result in
                drillResult = result
            }
        )
    }

    // MARK: - Instruction Overlay

    private var instructionOverlay: some View {
        let config = DrillConfig.config(for: drill.type)
        return VStack(spacing: 16) {
            Text(drill.type.displayName)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.green)

            Divider()

            Text(config.instructions)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if config.inputMode == .joystick {
                VStack(spacing: 4) {
                    Label("Center hits = harder shots", systemImage: "target")
                    Label("High balls = extra power", systemImage: "arrow.up.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Divider()

            Button {
                showInstructions = false
                scene?.beginDrill()
            } label: {
                Text("Let's Play Pickleball!")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    // MARK: - Result Overlay

    private func resultOverlay(result: InteractiveDrillResult) -> some View {
        VStack(spacing: 16) {
            // Performance grade
            Text(result.performanceGrade.rawValue)
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(
                    red: result.performanceGrade.colorRed,
                    green: result.performanceGrade.colorGreen,
                    blue: result.performanceGrade.colorBlue
                ))

            Text(result.performanceGrade.displayName)
                .font(.title3.bold())
                .foregroundStyle(.secondary)

            Divider()

            // Stats (varies by drill type)
            HStack(spacing: 24) {
                if result.drill.type == .baselineRally || result.drill.type == .dinkingDrill {
                    // Rally drills: show rallies completed + best streak
                    VStack(spacing: 4) {
                        Text("\(result.ralliesCompleted)/\(result.totalRounds)")
                            .font(.title2.bold().monospacedDigit())
                        Text("Rallies")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 4) {
                        Text("\(result.longestRally)")
                            .font(.title2.bold().monospacedDigit())
                        Text("Best Streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if result.drill.type == .accuracyDrill || result.drill.type == .returnOfServe {
                    VStack(spacing: 4) {
                        Text("\(result.successfulReturns)/\(result.totalBalls)")
                            .font(.title2.bold().monospacedDigit())
                        Text("Returns")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 4) {
                        Text("\(result.coneHits)")
                            .font(.title2.bold().monospacedDigit())
                        Text("Cone Hits")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 4) {
                        Text("\(result.successfulReturns)/\(result.totalBalls)")
                            .font(.title2.bold().monospacedDigit())
                        Text("In")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Stat gain
            Text("+\(result.statGainAmount) \(result.statGained.displayName)")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.green)

            // XP
            Label("+\(result.xpEarned) XP", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(.yellow)

            // Coach dialogue
            Text("\"\(coachPersonality.drillEndLine(grade: result.performanceGrade))\"")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()

            HStack(spacing: 12) {
                Button {
                    onComplete(result)
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    showLevelPicker = true
                } label: {
                    Text("Practice Match")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
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
                            // Complete the drill first, then navigate to practice match
                            if let result = drillResult {
                                onComplete(result)
                            }
                            practiceMatchNPC = NPC.practiceOpponent(dupr: level.dupr)
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
