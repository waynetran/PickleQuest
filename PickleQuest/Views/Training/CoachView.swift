import SwiftUI

struct CoachView: View {
    let coach: Coach
    let player: Player
    let onTrain: () -> Void

    var body: some View {
        let stat = coach.dailySpecialtyStat
        let currentBoost = player.coachingRecord.currentBoost(for: stat)
        let fee = player.coachingRecord.fee(for: coach)
        let atCap = currentBoost >= GameConstants.Coaching.maxCoachingBoostPerStat
        let hasSessionToday = player.coachingRecord.hasSessionToday(coachID: coach.id)
        let canAfford = player.wallet.coins >= fee
        let expectedGain = max(1, Int((player.currentEnergy / 100.0) * Double(coach.level)))

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

                    // Level stars
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= coach.level ? "star.fill" : "star")
                                .font(.system(size: 9))
                                .foregroundStyle(star <= coach.level ? .yellow : .gray.opacity(0.4))
                        }
                    }
                }

                Spacer()

                VStack(spacing: 4) {
                    if coach.isAlphaCoach && coach.alphaDefeated {
                        Label("50% Off", systemImage: "tag.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                    if hasSessionToday {
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

            // Daily specialty + train button
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: coach.dailyDrillType.iconName)
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Today: \(stat.displayName)")
                            .font(.subheadline.bold())
                    }

                    HStack(spacing: 8) {
                        Text("+\(expectedGain)")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                        Text("\(currentBoost)/\(GameConstants.Coaching.maxCoachingBoostPerStat) boosts")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    onTrain()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle")
                            .font(.caption2)
                        Text("\(fee)")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(trainEnabled(hasSession: hasSessionToday, atCap: atCap, canAfford: canAfford) ? .green : .gray)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .disabled(!trainEnabled(hasSession: hasSessionToday, atCap: atCap, canAfford: canAfford))
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .background(.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.blue.opacity(0.2), lineWidth: 1)
        )
    }

    private func trainEnabled(hasSession: Bool, atCap: Bool, canAfford: Bool) -> Bool {
        !hasSession && !atCap && canAfford
            && player.currentEnergy >= GameConstants.Training.drillEnergyCost
    }
}
