import SwiftUI

struct MatchResultView: View {
    let result: MatchResult
    let opponent: NPC?
    let levelUpRewards: [LevelUpReward]
    let duprChange: Double?
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Victory/Defeat header
                VStack(spacing: 8) {
                    Image(systemName: result.didPlayerWin ? "trophy.fill" : "xmark.circle")
                        .font(.system(size: 60))
                        .foregroundStyle(result.didPlayerWin ? .yellow : .red)

                    Text(result.didPlayerWin ? "Victory!" : "Defeat")
                        .font(.largeTitle.bold())

                    Text(result.formattedScore)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                // Level Up Banner
                LevelUpBanner(rewards: levelUpRewards)

                // Rewards
                HStack(spacing: 32) {
                    RewardBadge(icon: "star.fill", label: "XP", value: "+\(result.xpEarned)", color: .blue)
                    RewardBadge(icon: "dollarsign.circle.fill", label: "Coins", value: "+\(result.coinsEarned)", color: .yellow)
                    suprBadge
                }

                // Loot Drops
                if !result.loot.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Loot Drops")
                            .font(.headline)

                        ForEach(result.loot) { item in
                            LootDropRow(equipment: item)
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Stats comparison
                VStack(alignment: .leading, spacing: 12) {
                    Text("Match Stats")
                        .font(.headline)

                    StatRow(label: "Aces", player: result.playerStats.aces, opponent: result.opponentStats.aces)
                    StatRow(label: "Winners", player: result.playerStats.winners, opponent: result.opponentStats.winners)
                    StatRow(label: "Unforced Errors", player: result.playerStats.unforcedErrors, opponent: result.opponentStats.unforcedErrors)
                    StatRow(label: "Forced Errors", player: result.playerStats.forcedErrors, opponent: result.opponentStats.forcedErrors)
                    StatRow(label: "Longest Streak", player: result.playerStats.longestStreak, opponent: result.opponentStats.longestStreak)
                    StatRow(label: "Longest Rally", player: result.playerStats.longestRally, opponent: result.opponentStats.longestRally)

                    HStack {
                        Text("Energy Remaining")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(result.playerStats.finalEnergy))%")
                            .font(.subheadline.monospacedDigit())
                        Text("vs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(result.opponentStats.finalEnergy))%")
                            .font(.subheadline.monospacedDigit())
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Continue button
                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var suprBadge: some View {
        if let change = duprChange {
            let isPositive = change >= 0
            RewardBadge(
                icon: "chart.line.uptrend.xyaxis",
                label: "SUPR",
                value: String(format: "%@%.2f", isPositive ? "+" : "", change),
                color: isPositive ? .green : .red
            )
        } else {
            RewardBadge(
                icon: "chart.line.uptrend.xyaxis",
                label: "SUPR",
                value: "Unrated",
                color: .gray
            )
        }
    }
}

struct RewardBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct StatRow: View {
    let label: String
    let player: Int
    let opponent: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(player)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(player > opponent ? .green : .primary)
            Text("vs")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(opponent)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(opponent > player ? .red : .primary)
        }
    }
}
