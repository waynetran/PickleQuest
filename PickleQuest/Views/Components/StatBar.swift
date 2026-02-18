import SwiftUI

struct StatBar: View {
    let name: String
    let value: Int
    let maxValue: Int
    var color: Color = .green

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.caption)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                        .frame(height: 8)

                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value) / CGFloat(maxValue), height: 8)
                }
            }
            .frame(height: 8)

            Text("\(value)")
                .font(.caption.monospacedDigit().bold())
                .frame(width: 28, alignment: .trailing)
        }
    }
}

struct DifficultyBadge: View {
    let difficulty: NPCDifficulty

    var body: some View {
        Text(difficulty.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        AppTheme.difficultyColor(difficulty)
    }
}
