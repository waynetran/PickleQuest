import SwiftUI

struct MatchHistoryRow: View {
    let entry: MatchHistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            // W/L indicator
            Image(systemName: entry.didWin ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(entry.didWin ? .green : .red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.opponentName)
                        .font(.subheadline.bold())

                    Text(entry.opponentDifficulty.displayName)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.2))
                        .foregroundStyle(difficultyColor)
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    Text(entry.scoreString)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(entry.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // SUPR change
                if let change = entry.duprChange {
                    let isPositive = change >= 0
                    Text(String(format: "%@%.2f", isPositive ? "+" : "", change))
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(isPositive ? .green : .red)
                }

                // Rep change
                if entry.repChange != 0 {
                    let isPositive = entry.repChange > 0
                    Text("\(isPositive ? "+" : "")\(entry.repChange) rep")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(isPositive ? .purple : .red)
                }

                // Broken equipment
                if !entry.equipmentBroken.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                        Text("\(entry.equipmentBroken.count) broken")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var difficultyColor: Color {
        switch entry.opponentDifficulty {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .purple
        case .expert: return .orange
        case .master: return .red
        }
    }
}
