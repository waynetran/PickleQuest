import SwiftUI

struct LevelUpBanner: View {
    let rewards: [LevelUpReward]

    var body: some View {
        if !rewards.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.yellow)

                Text("Level Up!")
                    .font(.title2.bold())
                    .foregroundStyle(.yellow)

                ForEach(rewards, id: \.newLevel) { reward in
                    HStack(spacing: 4) {
                        Text("Level \(reward.newLevel)")
                            .font(.headline)
                        Text("+\(reward.statPointsGained) stat points")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.yellow.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
