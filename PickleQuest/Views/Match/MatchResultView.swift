import SwiftUI

struct MatchResultView: View {
    let result: MatchResult
    let opponent: NPC?
    var matchVM: MatchViewModel
    let levelUpRewards: [LevelUpReward]
    let duprChange: Double?
    let potentialDuprChange: Double
    let repChange: Int?
    let brokenEquipment: [Equipment]
    let energyDrain: Double
    let onDismiss: () -> Void

    @State private var showDiscardAlert = false

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

                    // Doubles info
                    if result.isDoubles {
                        VStack(spacing: 4) {
                            if let partner = result.partnerName {
                                Text("Partner: \(partner)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let opp2 = result.opponent2Name, let opp = opponent {
                                Text("vs \(opp.name) & \(opp2)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let synergy = result.teamSynergy {
                                Text(synergy.description)
                                    .font(.caption.bold())
                                    .foregroundStyle(synergy.multiplier >= 1.0 ? .green : .orange)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        (synergy.multiplier >= 1.0 ? Color.green : Color.orange)
                                            .opacity(0.15)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.top, 24)

                // Level Up Banner
                LevelUpBanner(rewards: levelUpRewards)

                // Rewards
                HStack(spacing: 24) {
                    RewardBadge(icon: "star.fill", label: "XP", value: "+\(result.xpEarned)", color: .blue)
                    if result.coinsEarned > 0 {
                        RewardBadge(icon: "dollarsign.circle.fill", label: "Coins", value: "+\(result.coinsEarned)", color: .yellow)
                    }
                    suprBadge
                    repBadge
                }

                // Energy drain indicator
                if energyDrain > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.slash.fill")
                            .foregroundStyle(.orange)
                        Text("Energy drained: -\(Int(energyDrain))%")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Broken equipment warning
                if !brokenEquipment.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text("Equipment Broken!")
                                .font(.headline)
                                .foregroundStyle(.red)
                        }

                        ForEach(brokenEquipment) { item in
                            HStack(spacing: 8) {
                                Text(item.slot.icon)
                                Text(item.name)
                                    .font(.subheadline)
                                    .foregroundStyle(item.rarity.color)
                                    .strikethrough()
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Loot Drops
                if !result.loot.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Loot Drops")
                            .font(.headline)

                        ForEach(result.loot) { item in
                            LootDropRow(
                                equipment: item,
                                decision: Binding(
                                    get: { matchVM.lootDecisions[item.id] },
                                    set: { matchVM.lootDecisions[item.id] = $0 }
                                )
                            )
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
                Button {
                    if matchVM.hasUnhandledLoot {
                        showDiscardAlert = true
                    } else {
                        onDismiss()
                    }
                } label: {
                    Text("Continue")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .alert("Discard Loot?", isPresented: $showDiscardAlert) {
                    Button("Go Back", role: .cancel) { }
                    Button("Discard & Continue", role: .destructive) {
                        onDismiss()
                    }
                } message: {
                    let count = matchVM.lootDrops.filter { matchVM.lootDecisions[$0.id] == nil }.count
                    Text("\(count) item(s) will be discarded.")
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var repBadge: some View {
        if let change = repChange, change != 0 {
            let isPositive = change > 0
            RewardBadge(
                icon: isPositive ? "hand.thumbsup.fill" : "hand.thumbsdown.fill",
                label: "Rep",
                value: "\(isPositive ? "+" : "")\(change)",
                color: isPositive ? .purple : .red
            )
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
            let isPositive = potentialDuprChange >= 0
            RewardBadge(
                icon: "chart.line.uptrend.xyaxis",
                label: "SUPR",
                value: String(format: "(%@%.2f)", isPositive ? "+" : "", potentialDuprChange),
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
