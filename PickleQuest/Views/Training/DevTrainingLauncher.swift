import SwiftUI

// TODO: Remove this entire file — temporary dev shortcut to test interactive drills

/// Dev-only view that launches directly into an interactive drill without navigating through the normal app flow.
struct DevTrainingLauncher: View {
    @Environment(AppState.self) private var appState
    @State private var showDrill = true
    @State private var drillType: DrillType = .baselineRally

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
                    coachDialogue: "Good session! You're improving.",
                    playerEnergy: 100.0,
                    coachEnergy: 100.0,
                    onComplete: { result in
                        print("[DEV] Drill complete: \(result.performanceGrade.rawValue) — \(result.successfulReturns)/\(result.totalBalls) returns, longest rally: \(result.longestRally)")
                        showDrill = false
                    }
                )
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
                    }
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
    }
}
