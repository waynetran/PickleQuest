import SwiftUI
import SpriteKit

struct TrainingDrillView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: TrainingViewModel?
    @State private var showScene = false
    @Environment(\.dismiss) private var dismiss

    let coach: Coach

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if showScene, let result = vm.trainingResult {
                        drillSceneView(result: result, vm: vm)
                    } else {
                        coachTrainingView(vm: vm)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if viewModel == nil {
                    viewModel = TrainingViewModel(
                        trainingService: container.trainingService,
                        coach: coach
                    )
                }
            }
        }
    }

    // MARK: - Coach Training View

    @ViewBuilder
    private func coachTrainingView(vm: TrainingViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Coach info
                coachInfoSection(vm: vm)

                // Daily specialty
                dailySpecialtySection(vm: vm)

                // Training preview
                trainingPreviewSection(vm: vm)

                // Error message
                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                // Start button
                startTrainingButton(vm: vm)
            }
            .padding()
        }
    }

    private func coachInfoSection(vm: TrainingViewModel) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: "figure.run")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(coach.name)
                    .font(.headline)
                Text(coach.title)
                    .font(.caption)
                    .foregroundStyle(.blue)

                // Level stars
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= coach.level ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(star <= coach.level ? .yellow : .gray.opacity(0.4))
                    }
                    Text("Lv.\(coach.level)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if coach.isAlphaCoach && coach.alphaDefeated {
                Label("50% Off", systemImage: "tag.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.blue.opacity(0.2), lineWidth: 1)
        )
    }

    private func dailySpecialtySection(vm: TrainingViewModel) -> some View {
        let stat = coach.dailySpecialtyStat
        let drillType = coach.dailyDrillType

        return VStack(alignment: .leading, spacing: 8) {
            Text("Today's Specialty")
                .font(.headline)

            HStack(spacing: 12) {
                Image(systemName: drillType.iconName)
                    .font(.title2)
                    .foregroundStyle(.green)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.displayName)
                        .font(.subheadline.bold())
                    Text(drillType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(drillType.description)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func trainingPreviewSection(vm: TrainingViewModel) -> some View {
        let stat = coach.dailySpecialtyStat
        let fee = appState.player.coachingRecord.fee(for: coach)
        let coachEnergy = appState.player.coachingRecord.coachRemainingEnergy(coachID: coach.id)
        let expectedGain = vm.expectedGain(playerEnergy: appState.player.currentEnergy, coachEnergy: coachEnergy)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Training Details")
                .font(.headline)

            HStack(spacing: 20) {
                // Cost
                Label("\(fee) coins", systemImage: "dollarsign.circle")
                    .font(.subheadline)
                    .foregroundStyle(.yellow)

                // Energy cost
                Label("\(Int(GameConstants.Training.drillEnergyCost))% energy", systemImage: "bolt.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }

            // Expected gain
            HStack {
                Text("Expected Gain")
                    .font(.subheadline)
                Spacer()
                Text("+\(expectedGain) \(stat.displayName)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            }

            // Player energy bar
            HStack {
                Text("Your Energy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(appState.player.currentEnergy))%")
                    .font(.caption.bold().monospacedDigit())
            }

            // Coach energy
            HStack {
                Text("Coach Energy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(coachEnergy))%")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(coachEnergy <= 20 ? .orange : .secondary)
            }

            if coachEnergy <= 0 {
                Label("Coach is exhausted for today", systemImage: "battery.0")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func startTrainingButton(vm: TrainingViewModel) -> some View {
        Button {
            Task {
                var player = appState.player
                await vm.startDrill(player: &player)
                if vm.trainingResult != nil {
                    player.dailyChallengeState?.incrementProgress(for: .completeDrills)
                }
                appState.player = player
                if vm.trainingResult != nil {
                    showScene = true
                }
            }
        } label: {
            HStack {
                if vm.isSimulating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "play.fill")
                }
                Text("Start Training")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canStart(vm: vm) ? .green : .gray)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canStart(vm: vm) || vm.isSimulating)
    }

    private func canStart(vm: TrainingViewModel) -> Bool {
        let fee = appState.player.coachingRecord.fee(for: coach)
        let coachEnergy = appState.player.coachingRecord.coachRemainingEnergy(coachID: coach.id)
        return appState.player.wallet.coins >= fee
            && appState.player.currentEnergy >= GameConstants.Training.drillEnergyCost
            && coachEnergy > 0
    }

    // MARK: - Drill Scene + Results

    @ViewBuilder
    private func drillSceneView(result: TrainingResult, vm: TrainingViewModel) -> some View {
        ZStack {
            // SpriteKit scene
            SpriteView(scene: TrainingDrillScene(
                drillType: result.drill.type,
                statGained: result.statGained,
                statGainAmount: result.statGainAmount,
                appearance: appState.player.appearance,
                coachAppearance: coach.appearance,
                onComplete: { [weak vm] in
                    vm?.onAnimationComplete()
                }
            ))
            .ignoresSafeArea()

            // Results overlay — only after animation completes
            if vm.animationComplete {
                VStack {
                    Spacer()
                    resultOverlay(result: result, vm: vm)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: vm.animationComplete)
    }

    private func resultOverlay(result: TrainingResult, vm: TrainingViewModel) -> some View {
        VStack(spacing: 12) {
            // Stat gain
            Text("+\(result.statGainAmount) \(result.statGained.displayName)")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(.green)

            Divider()

            // XP earned
            Label("+\(result.xpEarned) XP", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(.yellow)

            // Coach dialogue
            Text(coach.dialogue.onSession)
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()

            Button {
                showScene = false
                vm.clearResult()
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
