import SwiftUI

struct LevelUpBanner: View {
    let rewards: [LevelUpReward]
    let onAllocate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        if !rewards.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Level Up!")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)

                    let totalPoints = rewards.reduce(0) { $0 + $1.statPointsGained }
                    let topLevel = rewards.last?.newLevel ?? 0
                    Text("Lv.\(topLevel) — +\(totalPoints) stat points")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Button {
                    onAllocate()
                } label: {
                    Text("Upgrade")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.yellow)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .yellow.opacity(0.3), radius: 8, y: 2)
            .padding(.horizontal)
        }
    }
}
