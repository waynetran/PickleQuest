import SwiftUI

struct CoachView: View {
    let coach: Coach
    let player: Player
    let onTrainStat: (StatType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Coach header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.2))
                        .frame(width: 52, height: 52)
                    Image(systemName: "figure.run")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(coach.name)
                        .font(.subheadline.bold())
                    Text(coach.title)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                Spacer()

                VStack(spacing: 4) {
                    if coach.isAlphaCoach && coach.alphaDefeated {
                        Label("50% Off", systemImage: "tag.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                    if player.coachingRecord.hasSessionToday(coachID: coach.id) {
                        Label("Done Today", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }

            // Greeting
            Text(coach.dialogue.greeting)
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()

            if coach.isAlphaCoach && !coach.alphaDefeated {
                Text("Beat me in a match for discounted lessons!")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            }

            // Specialty stat buttons
            ForEach(coach.specialtyStats, id: \.self) { stat in
                let currentBoost = player.coachingRecord.currentBoost(for: stat)
                let fee = player.coachingRecord.fee(for: coach, stat: stat)
                let atCap = currentBoost >= GameConstants.Coaching.maxCoachingBoostPerStat
                let hasSessionToday = player.coachingRecord.hasSessionToday(coachID: coach.id)
                let canAfford = player.wallet.coins >= fee

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stat.displayName)
                            .font(.subheadline.bold())
                        HStack(spacing: 4) {
                            Text("\(currentBoost)/\(GameConstants.Coaching.maxCoachingBoostPerStat)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if currentBoost > 0 {
                                Text("(+\(currentBoost) from coaching)")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    Spacer()

                    Button {
                        onTrainStat(stat)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle")
                                .font(.caption2)
                            Text("\(fee)")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(buttonEnabled(hasSessionToday: hasSessionToday, atCap: atCap, canAfford: canAfford) ? .blue : .gray)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .disabled(!buttonEnabled(hasSessionToday: hasSessionToday, atCap: atCap, canAfford: canAfford))
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.blue.opacity(0.2), lineWidth: 1)
        )
    }

    private func buttonEnabled(hasSessionToday: Bool, atCap: Bool, canAfford: Bool) -> Bool {
        !hasSessionToday && !atCap && canAfford
    }
}
