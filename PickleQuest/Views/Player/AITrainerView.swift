import SwiftUI

struct AITrainerView: View {
    @State private var viewModel = AITrainerViewModel()

    var body: some View {
        List {
            controlSection
            progressSection
            if !viewModel.session.winRateResults.isEmpty {
                winRateSection
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
            Text("Runs NPC-vs-NPC matches across DUPR pairings to optimize rally probability constants using evolution strategy.")
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        Section("Progress") {
            LabeledContent("Generation") {
                Text("\(viewModel.session.generation) / 200")
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

    // MARK: - Win Rate Table

    private var winRateSection: some View {
        Section("Win Rates") {
            ForEach(viewModel.session.winRateResults) { entry in
                HStack {
                    Text(String(format: "%.1f vs %.1f", entry.higherDUPR, entry.lowerDUPR))
                        .font(.caption.monospacedDigit())
                        .frame(width: 100, alignment: .leading)

                    let diff = abs(entry.actualWinRate - entry.targetWinRate)
                    let color: Color = diff < 0.03 ? .green : diff < 0.08 ? .yellow : .red

                    Text(String(format: "%.0f%%", entry.actualWinRate * 100))
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(color)

                    Text(String(format: "(target %.0f%%)", entry.targetWinRate * 100))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(String(format: "±%.1f", entry.avgScoreMargin))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
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
                message: Text("Training results from PickleQuest AI parameter optimizer")
            ) {
                Label("Share Report", systemImage: "square.and.arrow.up")
            }

            // Show optimized parameters
            DisclosureGroup("Optimized Parameters") {
                let defaults = SimulationParameters.defaults.toArray()
                let current = report.parameters.toArray()
                let names = SimulationParameters.parameterNames

                ForEach(0..<names.count, id: \.self) { i in
                    HStack {
                        Text(names[i])
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer()
                        Text(String(format: "%.4f", current[i]))
                            .font(.caption2.bold().monospacedDigit())
                        if abs(current[i] - defaults[i]) > 0.0001 {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text(String(format: "%.4f", defaults[i]))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .font(.subheadline)
        }
    }
}
