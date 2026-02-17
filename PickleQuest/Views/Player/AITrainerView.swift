import SwiftUI

struct AITrainerView: View {
    @State private var viewModel = AITrainerViewModel()

    var body: some View {
        List {
            controlSection
            progressSection
            if !viewModel.session.npcVsNPCResults.isEmpty {
                pointDiffSection
            }
            if !viewModel.session.playerVsNPCResults.isEmpty {
                playerVsNPCSection
            }
            if let report = viewModel.report {
                reportSection(report)
            }
        }
        .navigationTitle("AI Trainer")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Control

    private var controlSection: some View {
        Section {
            if viewModel.isTraining {
                Button("Stop Training", role: .destructive) {
                    viewModel.stopTraining()
                }
            } else {
                Button("Start Training") {
                    viewModel.startTraining()
                }
            }
        } footer: {
            Text("Optimizes NPC stat profiles so match simulation produces DUPR-expected point differentials (1.2 pts per 0.1 DUPR gap).")
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        Section("Progress") {
            LabeledContent("Generation") {
                Text("\(viewModel.session.generation) / 300")
                    .monospacedDigit()
            }
            .font(.subheadline)

            ProgressView(value: viewModel.session.progress)

            LabeledContent("Current Fitness") {
                Text(viewModel.session.currentFitness == .infinity
                     ? "—"
                     : String(format: "%.4f", viewModel.session.currentFitness))
                    .monospacedDigit()
            }
            .font(.subheadline)

            LabeledContent("Best Fitness") {
                Text(viewModel.session.bestFitness == .infinity
                     ? "—"
                     : String(format: "%.4f", viewModel.session.bestFitness))
                    .monospacedDigit()
            }
            .font(.subheadline)

            LabeledContent("Avg Rally Length") {
                Text(viewModel.session.avgRallyLength == 0
                     ? "—"
                     : String(format: "%.1f shots", viewModel.session.avgRallyLength))
                    .monospacedDigit()
            }
            .font(.subheadline)
        }
    }

    // MARK: - NPC-vs-NPC Point Diff Table

    private var pointDiffSection: some View {
        Section("NPC Point Differentials") {
            ForEach(viewModel.session.npcVsNPCResults) { entry in
                HStack {
                    Text(String(format: "%.1f vs %.1f", entry.higherDUPR, entry.lowerDUPR))
                        .font(.caption.monospacedDigit())
                        .frame(width: 100, alignment: .leading)

                    let diff = abs(entry.actualPointDiff - entry.targetPointDiff)
                    let color: Color = diff < 1.0 ? .green : diff < 3.0 ? .yellow : .red

                    Text(String(format: "%+.1f", entry.actualPointDiff))
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(color)

                    Text(String(format: "(target %+.1f)", entry.targetPointDiff))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(String(format: "%.0f%%", entry.actualWinRate * 100))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Player-vs-NPC Balance

    private var playerVsNPCSection: some View {
        Section("Player vs NPC Balance") {
            ForEach(viewModel.session.playerVsNPCResults) { entry in
                HStack {
                    Text(String(format: "DUPR %.1f", entry.dupr))
                        .font(.caption.monospacedDigit())
                        .frame(width: 80, alignment: .leading)

                    Text(String(format: "+%d equip", entry.npcEquipBonus))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()

                    let diff = abs(entry.actualPointDiff - entry.targetPointDiff)
                    let color: Color = diff < 1.0 ? .green : diff < 2.0 ? .yellow : .red

                    Text(String(format: "%+.1f pts", entry.actualPointDiff))
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(color)
                }
            }

            if let starter = viewModel.session.starterBalance {
                HStack {
                    Text("Starter")
                        .font(.caption.monospacedDigit())
                        .frame(width: 80, alignment: .leading)

                    Text("vs NPC 2.0")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()

                    let diff = abs(starter.actualPointDiff - starter.targetPointDiff)
                    let color: Color = diff < 1.0 ? .green : diff < 2.0 ? .yellow : .red

                    Text(String(format: "%+.1f pts", starter.actualPointDiff))
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(color)
                }
            }
        }
    }

    // MARK: - Report

    private func reportSection(_ report: TrainingReport) -> some View {
        Section("Report") {
            LabeledContent("Generations") {
                Text("\(report.generationCount)")
                    .monospacedDigit()
            }
            .font(.subheadline)

            LabeledContent("Final Fitness") {
                Text(String(format: "%.4f", report.fitnessScore))
                    .monospacedDigit()
            }
            .font(.subheadline)

            let mins = Int(report.elapsedSeconds) / 60
            let secs = Int(report.elapsedSeconds) % 60
            LabeledContent("Duration") {
                Text("\(mins)m \(secs)s")
                    .monospacedDigit()
            }
            .font(.subheadline)

            ShareLink(
                item: report.formattedReport(),
                subject: Text("PickleQuest AI Training Report"),
                message: Text("Training results from PickleQuest AI stat profile optimizer")
            ) {
                Label("Share Report", systemImage: "square.and.arrow.up")
            }

            // Show optimized stat profiles by DUPR
            DisclosureGroup("Stat Profiles by DUPR") {
                let profiles = report.statProfiles()
                let names = SimulationParameters.statNames

                ForEach(profiles) { profile in
                    DisclosureGroup("DUPR \(String(format: "%.1f", profile.dupr))") {
                        ForEach(0..<names.count, id: \.self) { i in
                            HStack {
                                Text(names[i].capitalized)
                                    .font(.caption2)
                                Spacer()
                                Text("\(profile.stats[i])")
                                    .font(.caption2.bold().monospacedDigit())
                            }
                        }
                    }
                    .font(.caption)
                }
            }
            .font(.subheadline)
        }
    }
}
