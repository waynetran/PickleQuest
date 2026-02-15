import SwiftUI
import SpriteKit

struct TrainingDrillView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: TrainingViewModel?
    @State private var showScene = false
    @Environment(\.dismiss) private var dismiss

    let initialDrillType: DrillType?

    init(initialDrillType: DrillType? = nil) {
        self.initialDrillType = initialDrillType
    }

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if showScene, let result = vm.trainingResult {
                        drillSceneView(result: result, vm: vm)
                    } else {
                        drillPickerView(vm: vm)
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
                    let vm = TrainingViewModel(
                        trainingService: container.trainingService,
                        inventoryService: container.inventoryService
                    )
                    if let initial = initialDrillType {
                        vm.selectedDrillType = initial
                    }
                    viewModel = vm
                }
            }
        }
    }

    // MARK: - Drill Picker

    @ViewBuilder
    private func drillPickerView(vm: TrainingViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Drill type grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(DrillType.allCases, id: \.self) { type in
                        drillTypeCard(type: type, vm: vm)
                    }
                }

                // Difficulty picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Difficulty")
                        .font(.headline)
                    Picker("Difficulty", selection: Binding(
                        get: { vm.selectedDifficulty },
                        set: { vm.selectedDifficulty = $0 }
                    )) {
                        ForEach(DrillDifficulty.allCases, id: \.self) { diff in
                            Text(diff.displayName).tag(diff)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Cost display
                let drill = vm.currentDrill
                HStack(spacing: 20) {
                    Label("\(drill.coinCost) coins", systemImage: "dollarsign.circle")
                        .font(.subheadline)
                        .foregroundStyle(.yellow)
                    Label("\(Int(drill.energyCost))% energy", systemImage: "bolt.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }

                // Target stats
                VStack(alignment: .leading, spacing: 6) {
                    Text("Target Stats")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(vm.selectedDrillType.targetStats, id: \.self) { stat in
                            Text(stat.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }

                // Error message
                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                // Start button
                Button {
                    Task {
                        var player = appState.player
                        await vm.startDrill(player: &player)
                        if let result = vm.trainingResult {
                            // Track daily challenge progress
                            player.dailyChallengeState?.incrementProgress(for: .completeDrills)
                            if result.grade <= .B {
                                player.dailyChallengeState?.incrementProgress(for: .earnGrade)
                            }
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
                        Text("Start Drill")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canStartDrill(vm: vm) ? .green : .gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canStartDrill(vm: vm) || vm.isSimulating)
            }
            .padding()
        }
    }

    private func drillTypeCard(type: DrillType, vm: TrainingViewModel) -> some View {
        let isSelected = vm.selectedDrillType == type
        return Button {
            vm.selectedDrillType = type
        } label: {
            VStack(spacing: 8) {
                Image(systemName: type.iconName)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .blue)
                Text(type.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(type.description)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(isSelected ? .blue : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func canStartDrill(vm: TrainingViewModel) -> Bool {
        let drill = vm.currentDrill
        return appState.player.wallet.coins >= drill.coinCost
            && appState.player.currentEnergy >= drill.energyCost
    }

    // MARK: - Drill Scene + Results

    @ViewBuilder
    private func drillSceneView(result: TrainingResult, vm: TrainingViewModel) -> some View {
        ZStack {
            // SpriteKit scene
            SpriteView(scene: TrainingDrillScene(
                drillType: result.drill.type,
                grade: result.grade,
                appearance: appState.player.appearance
            ))
            .ignoresSafeArea()

            // Results overlay
            VStack {
                Spacer()
                resultOverlay(result: result, vm: vm)
            }
        }
    }

    private func resultOverlay(result: TrainingResult, vm: TrainingViewModel) -> some View {
        VStack(spacing: 12) {
            // Grade
            Text(result.grade.rawValue)
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(result.grade.color)

            Text("Grade")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // XP earned
            Label("+\(result.xpEarned) XP", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(.yellow)

            // Target stat breakdown
            ForEach(Array(result.targetStatScores.sorted(by: { $0.key.rawValue < $1.key.rawValue })), id: \.key) { stat, score in
                HStack {
                    Text(stat.displayName)
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(score * 100))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(score >= 0.7 ? .green : score >= 0.4 ? .orange : .red)
                }
            }

            Button {
                showScene = false
                vm.clearResult()
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
