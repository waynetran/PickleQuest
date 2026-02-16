import SwiftUI

struct WagerSelectionSheet: View {
    let npc: NPC
    let playerCoins: Int
    let playerSUPR: Double
    let consecutiveWins: Int
    let npcPurse: Int
    let onAccept: (Int) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTier: Int = 0
    @State private var rejectionMessage: String?

    private var isHustler: Bool { npc.isHustler }

    private var effectiveWager: Int {
        isHustler ? min(npc.baseWagerAmount, npcPurse) : selectedTier
    }

    private var canAfford: Bool {
        playerCoins >= effectiveWager
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // NPC info
                npcHeader

                Divider()

                if let message = rejectionMessage {
                    rejectionView(message: message)
                } else {
                    wagerContent
                }

                Spacer()

                // Bottom buttons
                bottomButtons
            }
            .padding()
            .navigationTitle("Wager Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
            .onAppear {
                evaluateWager()
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - NPC Header

    private var npcHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(npc.isHustler ? Color.purple.opacity(0.2) : difficultyColor.opacity(0.2))
                    .frame(width: 56, height: 56)
                if npc.isHustler {
                    Image(systemName: "questionmark")
                        .font(.title2.bold())
                        .foregroundStyle(.purple)
                } else {
                    Text(String(npc.name.prefix(1)))
                        .font(.title2.bold())
                        .foregroundStyle(difficultyColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(npc.name)
                    .font(.headline)
                Text(npc.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if npc.hiddenStats {
                    Text("SUPR ???")
                        .font(.caption.bold())
                        .foregroundStyle(.purple)
                } else {
                    Text("SUPR \(String(format: "%.2f", npc.duprRating))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Wager Content

    @ViewBuilder
    private var wagerContent: some View {
        if isHustler {
            hustlerWagerView
        } else {
            regularWagerView
        }
    }

    private var hustlerWagerView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Forced Wager")
                    .font(.headline)
            }

            if npcPurse < npc.baseWagerAmount && npcPurse > 0 {
                Text("\(npc.name) demands a wager but only has \(npcPurse) coins. Effective wager: \(effectiveWager) coins.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("\(npc.name) demands a wager of \(npc.baseWagerAmount) coins. Take it or leave it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            wagerAmountDisplay(amount: effectiveWager)
        }
    }

    private var availableTiers: [Int] {
        GameConstants.Wager.wagerTiers.filter { $0 == 0 || $0 <= npcPurse }
    }

    private var regularWagerView: some View {
        VStack(spacing: 16) {
            Text("Choose Your Wager")
                .font(.headline)

            // NPC purse display
            if npcPurse < GameConstants.Wager.wagerTiers.last ?? 0 {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(.yellow)
                    Text("\(npc.name) has \(npcPurse) coins")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Tier picker (filtered by NPC purse)
            HStack(spacing: 8) {
                ForEach(availableTiers, id: \.self) { tier in
                    Button {
                        selectedTier = tier
                        evaluateWager()
                    } label: {
                        VStack(spacing: 4) {
                            Text(tier == 0 ? "Free" : "\(tier)")
                                .font(.subheadline.bold())
                            if tier > 0 {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTier == tier ? Color.green.opacity(0.2) : Color(.systemGray6))
                        .foregroundStyle(selectedTier == tier ? .green : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedTier == tier ? Color.green : Color.clear, lineWidth: 2)
                        )
                    }
                    .disabled(tier > playerCoins)
                    .opacity(tier > playerCoins ? 0.4 : 1.0)
                }
            }

            if selectedTier > 0 {
                wagerAmountDisplay(amount: selectedTier)
            }
        }
    }

    private func wagerAmountDisplay(amount: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Balance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(.yellow)
                    Text("\(playerCoins)")
                        .font(.subheadline.bold())
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("At Stake")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(amount)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .background(.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Rejection

    private func rejectionView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .italic()
        }
        .padding()
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack(spacing: 12) {
            if rejectionMessage == nil {
                Button {
                    onAccept(effectiveWager)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "figure.pickleball")
                        Text(effectiveWager > 0 ? "Challenge for \(effectiveWager) Coins" : "Challenge (Free)")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canAfford ? .green : .gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canAfford)
            }

            Button {
                onCancel()
                dismiss()
            } label: {
                Text("Walk Away")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Logic

    private func evaluateWager() {
        let decision = WagerDecision.evaluate(
            npc: npc,
            wagerAmount: effectiveWager,
            playerSUPR: playerSUPR,
            consecutivePlayerWins: consecutiveWins,
            npcPurse: npcPurse
        )

        switch decision {
        case .accepted:
            rejectionMessage = nil
        case .rejected(let reason):
            rejectionMessage = reason
        }
    }

    private var difficultyColor: Color {
        switch npc.difficulty {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .purple
        case .expert: return .orange
        case .master: return .red
        }
    }
}
