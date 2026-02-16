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

            // Skip button (bottom right, during active drill only)
            if !showInstructions && drillResult == nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            scene?.skipDrill()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 16))
                                Text("Skip")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(.black.opacity(0.6))
                            .clipShape(Capsule())
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 8)
                    }
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
                        Text("\(result.ralliesCompleted)/10")
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
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
    }
}
