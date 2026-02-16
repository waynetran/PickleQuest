import SwiftUI

struct PlayerSlotCard: View {
    let summary: SavedPlayerSummary

    var body: some View {
        VStack(spacing: 10) {
            AnimatedSpriteView(
                appearance: summary.appearance,
                size: 120,
                animationState: .idleFront
            )

            VStack(spacing: 4) {
                Text(summary.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("Lv. \(summary.level)")
                        .font(.caption)
                    if summary.duprRating > 0 {
                        Text(String(format: "%.1f", summary.duprRating))
                            .font(.caption.monospacedDigit())
                    }
                }
                .foregroundStyle(.secondary)

                Text(summary.lastPlayedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !summary.tutorialCompleted {
                Text("Tutorial pending")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
