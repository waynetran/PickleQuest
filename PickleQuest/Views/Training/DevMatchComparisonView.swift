import SwiftUI

struct DevMatchComparisonView: View {
    @State private var viewModel = DevTrainingMatchViewModel()
    @State private var selectedTab = 0
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedTab) {
                    Text("Comparison").tag(0)
                    Text("Raw Log").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if selectedTab == 0 {
                    comparisonTab
                } else {
                    rawLogTab
                }
            }
            .navigationTitle("Match Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            UIPasteboard.general.string = viewModel.exportLogAsText()
                        } label: {
                            Label("Export to Clipboard", systemImage: "doc.on.clipboard")
                        }

                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Label("Clear All Data", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog("Clear all match data?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear All", role: .destructive) {
                    Task { await viewModel.clearLog() }
                }
            }
            .task {
                await viewModel.loadEntries()
            }
        }
    }

    // MARK: - Comparison Tab

    private var comparisonTab: some View {
        List {
            if viewModel.comparisonRows.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.bar",
                    description: Text("Play practice matches or run headless validation to see comparison data.")
                )
            } else {
                ForEach(viewModel.comparisonRows) { row in
                    comparisonSection(row)
                }
            }
        }
    }

    private func comparisonSection(_ row: DevTrainingMatchViewModel.ComparisonRow) -> some View {
        Section("DUPR \(String(format: "%.1f", row.dupr))") {
            Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("")
                        .gridColumnAlignment(.leading)
                    Text("Real (\(row.realCount))")
                        .font(.caption.bold())
                    Text("Headless (\(row.headlessCount))")
                        .font(.caption.bold())
                }
                .foregroundStyle(.secondary)

                Divider()
                    .gridCellColumns(3)

                comparisonGridRow("Win Rate", format(row.realWinRate, pct: true), format(row.headlessWinRate, pct: true))
                comparisonGridRow("Pt Diff", format(row.realAvgPointDiff, signed: true), format(row.headlessAvgPointDiff, signed: true))
                comparisonGridRow("Rally", format(row.realAvgRallyLength), format(row.headlessAvgRallyLength))
                comparisonGridRow("Errors", format(row.realAvgErrors), format(row.headlessAvgErrors))
            }
            .padding(.vertical, 4)
        }
    }

    private func comparisonGridRow(_ label: String, _ real: String, _ headless: String) -> some View {
        GridRow {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.leading)
            Text(real)
                .font(.body.monospacedDigit())
            Text(headless)
                .font(.body.monospacedDigit())
        }
    }

    private func format(_ value: Double?, pct: Bool = false, signed: Bool = false) -> String {
        guard let value else { return "—" }
        if pct { return String(format: "%.1f%%", value * 100) }
        if signed { return String(format: "%+.1f", value) }
        return String(format: "%.1f", value)
    }

    // MARK: - Raw Log Tab

    private var rawLogTab: some View {
        List {
            if viewModel.loggedEntries.isEmpty {
                ContentUnavailableView(
                    "No Entries",
                    systemImage: "list.bullet",
                    description: Text("Match log entries will appear here.")
                )
            } else {
                ForEach(viewModel.loggedEntries.reversed()) { entry in
                    rawLogRow(entry)
                }
            }
        }
    }

    private func rawLogRow(_ entry: DevMatchLogEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    sourceBadge(entry.source)
                    Text("DUPR \(String(format: "%.1f", entry.opponentDUPR))")
                        .font(.subheadline.bold())
                }

                Text("\(entry.playerScore)–\(entry.opponentScore)")
                    .font(.body.monospacedDigit())
                +
                Text(entry.didPlayerWin ? " W" : " L")
                    .font(.body.bold())
                    .foregroundColor(entry.didPlayerWin ? .green : .red)
            }

            Spacer()

            Text(entry.date, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func sourceBadge(_ source: DevMatchSource) -> some View {
        Text(source == .interactive ? "REAL" : "SIM")
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(source == .interactive ? Color.blue : Color.purple)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}
