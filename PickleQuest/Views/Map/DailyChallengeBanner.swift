import SwiftUI

struct DailyChallengeBanner: View {
    let state: DailyChallengeState
    let onClaimBonus: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Compact header (always visible)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)

                    Text("\(state.completedCount)/\(state.challenges.count) Daily Challenges")
                        .font(.caption.bold())

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                Divider()

                VStack(spacing: 8) {
                    ForEach(state.challenges) { challenge in
                        challengeRow(challenge)
                    }

                    // Completion bonus
                    if state.allCompleted && !state.bonusClaimed {
                        Button {
                            onClaimBonus()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "gift.fill")
                                    .foregroundStyle(.yellow)
                                Text("Claim Bonus: +\(GameConstants.DailyChallenge.completionBonusCoins) coins")
                                    .font(.caption.bold())
                                    .foregroundStyle(.yellow)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(.yellow.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    } else if state.bonusClaimed {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("All bonuses claimed!")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func challengeRow(_ challenge: DailyChallenge) -> some View {
        HStack(spacing: 10) {
            Image(systemName: challenge.isCompleted ? "checkmark.circle.fill" : challenge.type.iconName)
                .foregroundStyle(challenge.isCompleted ? .green : .secondary)
                .font(.caption)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.description)
                    .font(.caption)
                    .foregroundStyle(challenge.isCompleted ? .secondary : .primary)
                    .strikethrough(challenge.isCompleted)

                if challenge.targetCount > 1 {
                    Text("\(challenge.currentCount)/\(challenge.targetCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(challenge.coinReward)")
                    .font(.caption2.bold())
                    .foregroundStyle(.yellow)
                Text("+\(challenge.xpReward) XP")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Full list view for the sheet — shows all challenges without expand/collapse.
struct DailyChallengeListView: View {
    let state: DailyChallengeState
    let onClaimBonus: () -> Void

    var body: some View {
        List {
            ForEach(state.challenges) { challenge in
                HStack(spacing: 12) {
                    Image(systemName: challenge.isCompleted ? "checkmark.circle.fill" : challenge.type.iconName)
                        .foregroundStyle(challenge.isCompleted ? .green : .secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(challenge.description)
                            .font(.subheadline)
                            .foregroundStyle(challenge.isCompleted ? .secondary : .primary)
                            .strikethrough(challenge.isCompleted)

                        if challenge.targetCount > 1 {
                            ProgressView(value: Double(challenge.currentCount), total: Double(challenge.targetCount))
                                .tint(challenge.isCompleted ? .green : .blue)
                            Text("\(challenge.currentCount)/\(challenge.targetCount)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("+\(challenge.coinReward)")
                            .font(.caption.bold())
                            .foregroundStyle(.yellow)
                        Text("+\(challenge.xpReward) XP")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowSeparator(.hidden)
            }

            // Completion bonus
            if state.allCompleted && !state.bonusClaimed {
                Button {
                    onClaimBonus()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                            .foregroundStyle(.yellow)
                        Text("Claim Bonus: +\(GameConstants.DailyChallenge.completionBonusCoins) coins")
                            .font(.subheadline.bold())
                            .foregroundStyle(.yellow)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.yellow.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .listRowSeparator(.hidden)
            } else if state.bonusClaimed {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("All bonuses claimed!")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}
