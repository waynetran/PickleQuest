import SwiftUI

struct DevHeadlessRunnerView: View {
    @State private var viewModel = DevTrainingMatchViewModel()

    var body: some View {
        NavigationStack {
            List {
                configSection
                if viewModel.isRunningHeadless {
                    progressSection
                }
                if !viewModel.headlessResults.isEmpty {
                    resultsSection
                }
            }
            .navigationTitle("Headless Validation")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Config

    private var configSection: some View {
        Section {
            Stepper("Matches per level: \(viewModel.matchesPerLevel)",
                    value: $viewModel.matchesPerLevel,
                    in: 10...200,
                    step: 10)

            Button {
                Task { await viewModel.runHeadless() }
            } label: {
                Label("Run Headless Validation", systemImage: "bolt.fill")
            }
            .disabled(viewModel.isRunningHeadless)
        } header: {
            Text("Configuration")
        } footer: {
            Text("Runs \(viewModel.matchesPerLevel) matches at each DUPR level (2.0–7.0) using the headless interactive engine.")
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        Section("Progress") {
            ProgressView(value: viewModel.headlessProgress)
            Text("\(Int(viewModel.headlessProgress * 100))% — \(viewModel.headlessResults.count)/6 levels")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Results

    private var resultsSection: some View {
        Section("Results") {
            ForEach(viewModel.headlessResults) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("DUPR \(String(format: "%.1f", row.dupr))")
                            .font(.headline)
                        Spacer()
                        Text("\(row.matchCount) matches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 16) {
                        statCell("Win%", String(format: "%.0f%%", row.winRate * 100))
                        statCell("PtDiff", String(format: "%+.1f", row.avgPointDiff))
                        statCell("Rally", String(format: "%.1f", row.avgRallyLength))
                        statCell("PErr", String(format: "%.1f", row.avgPlayerErrors))
                        statCell("OErr", String(format: "%.1f", row.avgOpponentErrors))
                    }
                    .font(.caption)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}
