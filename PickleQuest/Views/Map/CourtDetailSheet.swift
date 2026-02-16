import SwiftUI

struct CourtDetailSheet: View {
    let court: Court
    let npcs: [NPC]
    let hustlers: [NPC]
    let npcPurses: [UUID: Int]
    let playerRating: Double
    let ladder: CourtLadder?
    let doublesLadder: CourtLadder?
    let courtPerk: CourtPerk?
    let alphaNPC: NPC?
    let doublesAlphaNPC: NPC?
    let playerPersonality: NPCPersonality
    let coach: Coach?
    let player: Player
    @Binding var isRated: Bool
    @Binding var isDoublesMode: Bool
    let onChallenge: (NPC) -> Void
    let onDoublesChallenge: (NPC, NPC) -> Void
    let onTournament: () -> Void
    let onCoachTraining: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    courtHeader
                    Divider()
                    matchModeToggle
                    ratedToggle
                    perkBadges
                    coachSection
                    tournamentButton
                    if isDoublesMode {
                        doublesSection
                    } else {
                        ladderSection
                    }
                    hustlerSection
                }
                .padding()
            }
            .navigationTitle("Court Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Court Header

    private var courtHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(difficultyColor.opacity(0.2))
                    .frame(width: 64, height: 64)
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(difficultyColor)

                // King of the Court crown
                if courtPerk?.isFullyDominated == true {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.yellow)
                        .offset(y: -38)
                }
            }

            Text(court.name)
                .font(.title2.bold())

            if ladder?.alphaDefeated == true {
                Text("King of the Court")
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.yellow.opacity(0.15))
                    .clipShape(Capsule())
            }

            Text(court.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                ForEach(court.difficultyTiers.sorted(), id: \.self) { tier in
                    DifficultyBadge(difficulty: tier)
                }
                Label("\(court.courtCount) courts", systemImage: "rectangle.split.2x1")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top)
    }

    // MARK: - Match Mode Toggle

    private var matchModeToggle: some View {
        Picker("Mode", selection: $isDoublesMode) {
            Text("Singles").tag(false)
            Text("Doubles").tag(true)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Rated Toggle

    private var ratedToggle: some View {
        Toggle(isOn: $isRated) {
            HStack(spacing: 6) {
                Image(systemName: isRated ? "chart.line.uptrend.xyaxis" : "minus.circle")
                    .foregroundStyle(isRated ? .green : .secondary)
                Text(isRated ? "Rated Match" : "Unrated Match")
                    .font(.subheadline)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Perk Badges

    @ViewBuilder
    private var perkBadges: some View {
        if let perk = courtPerk, perk.isFullyDominated {
            VStack(alignment: .leading, spacing: 8) {
                Text("Court Perks")
                    .font(.headline)

                HStack(spacing: 12) {
                    perkBadge(icon: "trophy.fill", label: "Tournament Invite", color: .yellow)
                    perkBadge(icon: "tag.fill", label: "20% Store Discount", color: .green)
                    perkBadge(icon: "figure.run", label: "Coaching", color: .blue)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.yellow.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func perkBadge(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Coach Section

    @ViewBuilder
    private var coachSection: some View {
        if let coach {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coach")
                    .font(.headline)
                    .padding(.horizontal)

                CoachView(coach: coach, player: player) {
                    dismiss()
                    onCoachTraining()
                }
            }
        }
    }

    // MARK: - Ladder Section

    private var ladderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Challenge Ladder")
                    .font(.headline)
                Spacer()
                if let ladder {
                    Text("\(ladder.defeatedNPCIDs.count)/\(ladder.rankedNPCIDs.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            if npcs.isEmpty {
                Text("No opponents at this court right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                // Regular NPCs in natural order (weakest at top, strongest at bottom)
                ForEach(Array(npcs.enumerated()), id: \.element.id) { index, npc in
                    ladderRungCard(npc: npc, position: index)
                }

                // Alpha boss card (bottom of ladder)
                alphaCard
            }
        }
    }

    // MARK: - Alpha Card

    @ViewBuilder
    private var alphaCard: some View {
        if let ladder {
            if ladder.alphaUnlocked, let alpha = alphaNPC {
                // Alpha is unlocked
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // Alpha portrait
                        ZStack {
                            Circle()
                                .fill(.red.opacity(0.3))
                                .frame(width: 52, height: 52)
                            Image(systemName: "flame.fill")
                                .font(.title2)
                                .foregroundStyle(.red)
                        }
                        .overlay(
                            Circle()
                                .stroke(.red, lineWidth: 2)
                                .frame(width: 52, height: 52)
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                                Text(alpha.name)
                                    .font(.subheadline.bold())
                            }
                            Text(alpha.title)
                                .font(.caption)
                                .foregroundStyle(.red)
                            HStack(spacing: 6) {
                                DifficultyBadge(difficulty: alpha.difficulty)
                                Text("SUPR \(String(format: "%.2f", alpha.duprRating))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if ladder.alphaDefeated {
                            // Already beaten — show crown + re-challenge
                            VStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                                Button {
                                    dismiss()
                                    onChallenge(alpha)
                                } label: {
                                    Text("Re-challenge")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.orange)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                            }
                        } else {
                            Button {
                                dismiss()
                                onChallenge(alpha)
                            } label: {
                                Text("Challenge")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.red)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(12)

                    autoUnratedWarning(for: alpha)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.red.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.red.opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                // Alpha locked
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 52, height: 52)
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Court Alpha")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        Text("Beat all regulars to unlock")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(0.7)
            }
        }
    }

    // MARK: - Ladder Rung Card

    private func ladderRungCard(npc: NPC, position: Int) -> some View {
        let isDefeated = ladder?.defeatedNPCIDs.contains(npc.id) ?? false
        let isNextChallenger = ladder?.nextChallengerID == npc.id
        let isLocked = !isDefeated && !isNextChallenger

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Ladder position number
                ZStack {
                    Circle()
                        .fill(rungColor(isDefeated: isDefeated, isNextChallenger: isNextChallenger))
                        .frame(width: 28, height: 28)

                    if isDefeated {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    } else if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(position + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }

                // Portrait
                ZStack {
                    Circle()
                        .fill(npcDifficultyColor(npc).opacity(isDefeated ? 0.1 : 0.2))
                        .frame(width: 44, height: 44)
                    Text(String(npc.name.prefix(1)))
                        .font(.callout.bold())
                        .foregroundStyle(isDefeated ? .secondary : npcDifficultyColor(npc))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(npc.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(isDefeated ? .secondary : .primary)

                    if isDefeated {
                        Text("Gone home")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if isLocked {
                        if let prevName = previousNPCName(before: position) {
                            Text("Beat \(prevName) first")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    } else {
                        Text(npc.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 6) {
                        DifficultyBadge(difficulty: npc.difficulty)
                        Text("SUPR \(String(format: "%.2f", npc.duprRating))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if isNextChallenger, let purse = npcPurses[npc.id] {
                            HStack(spacing: 2) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                                Text("\(purse)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                Spacer()

                if isDefeated {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if isNextChallenger {
                    Button {
                        dismiss()
                        onChallenge(npc)
                    } label: {
                        Text("Challenge")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .padding(12)

            if isNextChallenger {
                autoUnratedWarning(for: npc)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isLocked ? 0.6 : 1.0)
    }

    // MARK: - Auto Unrated Warning

    @ViewBuilder
    private func autoUnratedWarning(for npc: NPC) -> some View {
        let autoUnrated = DUPRCalculator.shouldAutoUnrate(
            playerRating: playerRating,
            opponentRating: npc.duprRating
        )

        if isRated && autoUnrated {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                Text("Rating gap > \(String(format: "%.1f", GameConstants.DUPRRating.maxRatedGap)) — auto-unrated")
                    .font(.caption2)
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Tournament Button

    @ViewBuilder
    private var tournamentButton: some View {
        if courtPerk?.isFullyDominated == true {
            Button {
                dismiss()
                onTournament()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enter Tournament")
                            .font(.subheadline.bold())
                        Text(isDoublesMode ? "Doubles bracket" : "Singles bracket")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.yellow.gradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Doubles Section

    private var doublesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Opponent Pairs")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)

            if npcs.count < 2 {
                Text("Not enough opponents for doubles.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(doublesOpponentPairs, id: \.0.id) { pair in
                    doublesTeamCard(npc1: pair.0, npc2: pair.1, synergy: pair.2)
                }
            }
        }
    }

    private var doublesOpponentPairs: [(NPC, NPC, TeamSynergy)] {
        // Pair available NPCs by best synergy (greedy algorithm)
        var remaining = npcs
        var pairs: [(NPC, NPC, TeamSynergy)] = []

        while remaining.count >= 2 {
            let anchor = remaining.removeFirst()
            var bestIdx = 0
            var bestSynergy = TeamSynergy.calculate(p1: anchor.personality, p2: remaining[0].personality)

            for (idx, candidate) in remaining.enumerated().dropFirst() {
                let syn = TeamSynergy.calculate(p1: anchor.personality, p2: candidate.personality)
                if syn.multiplier > bestSynergy.multiplier {
                    bestSynergy = syn
                    bestIdx = idx
                }
            }

            let partner = remaining.remove(at: bestIdx)
            pairs.append((anchor, partner, bestSynergy))
        }

        return pairs
    }

    private func doublesTeamCard(npc1: NPC, npc2: NPC, synergy: TeamSynergy) -> some View {
        let avgDUPR = (npc1.duprRating + npc2.duprRating) / 2.0
        let playerSynergy = bestPlayerSynergy(with: [npc1, npc2])

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Team portraits
                HStack(spacing: -8) {
                    ZStack {
                        Circle()
                            .fill(npcDifficultyColor(npc1).opacity(0.2))
                            .frame(width: 38, height: 38)
                        Text(String(npc1.name.prefix(1)))
                            .font(.caption.bold())
                            .foregroundStyle(npcDifficultyColor(npc1))
                    }
                    ZStack {
                        Circle()
                            .fill(npcDifficultyColor(npc2).opacity(0.2))
                            .frame(width: 38, height: 38)
                        Text(String(npc2.name.prefix(1)))
                            .font(.caption.bold())
                            .foregroundStyle(npcDifficultyColor(npc2))
                    }
                    .overlay(
                        Circle()
                            .stroke(.background, lineWidth: 2)
                            .frame(width: 38, height: 38)
                    )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(npc1.name) & \(npc2.name)")
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(synergy.description)
                            .font(.caption)
                            .foregroundStyle(synergyColor(synergy))
                        Text("Avg SUPR \(String(format: "%.2f", avgDUPR))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    dismiss()
                    onDoublesChallenge(npc1, npc2)
                } label: {
                    Text("Challenge")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(12)

            // Player synergy preview
            if let bestPartnerName = playerSynergy?.0 {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("Best partner: \(bestPartnerName)")
                        .font(.caption2)
                    if let syn = playerSynergy?.1 {
                        Text("(\(syn.description))")
                            .font(.caption2)
                            .foregroundStyle(synergyColor(syn))
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Find best potential partner for the player from NPCs not in the opponent pair.
    private func bestPlayerSynergy(with opponents: [NPC]) -> (String, TeamSynergy)? {
        let opponentIDs = Set(opponents.map(\.id))
        let availablePartners = npcs.filter { !opponentIDs.contains($0.id) }

        var best: (String, TeamSynergy)?
        for npc in availablePartners {
            let syn = TeamSynergy.calculate(p1: playerPersonality, p2: npc.personality)
            if best == nil || syn.multiplier > (best?.1.multiplier ?? 0) {
                best = (npc.name, syn)
            }
        }
        return best
    }

    private func synergyColor(_ synergy: TeamSynergy) -> Color {
        if synergy.multiplier >= 1.06 { return .green }
        if synergy.multiplier >= 1.03 { return .mint }
        if synergy.multiplier >= 0.97 { return .secondary }
        return .orange
    }

    // MARK: - Hustler Section

    @ViewBuilder
    private var hustlerSection: some View {
        let activeHustlers = hustlers.filter { hustler in
            // Hide hustlers the player has beaten (sore loser mechanic)
            let wins = player.npcLossRecord[hustler.id] ?? 0
            return wins == 0
        }

        if !activeHustlers.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash.fill")
                        .foregroundStyle(.purple)
                    Text("Mysterious Challengers")
                        .font(.headline)
                }
                .padding(.horizontal)

                ForEach(activeHustlers) { hustler in
                    hustlerCard(hustler: hustler)
                }
            }
        }

        // Show "left the court" for beaten hustlers
        let beatenHustlers = hustlers.filter { (player.npcLossRecord[$0.id] ?? 0) > 0 }
        if !beatenHustlers.isEmpty {
            ForEach(beatenHustlers) { hustler in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 44, height: 44)
                        Image(systemName: "figure.walk.departure")
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hustler.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .strikethrough()
                        Text("Left the court...")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(0.6)
            }
        }
    }

    private func hustlerCard(hustler: NPC) -> some View {
        HStack(spacing: 12) {
            // Mysterious portrait
            ZStack {
                Circle()
                    .fill(.purple.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: "questionmark")
                    .font(.title3.bold())
                    .foregroundStyle(.purple)
            }
            .overlay(
                Circle()
                    .stroke(.purple.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 48, height: 48)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(hustler.name)
                    .font(.subheadline.bold())
                Text(hustler.title)
                    .font(.caption)
                    .foregroundStyle(.purple)
                HStack(spacing: 6) {
                    Text("SUPR ???")
                        .font(.caption2.bold())
                        .foregroundStyle(.purple)
                    Text("Wager: \(hustler.baseWagerAmount) coins")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    if let purse = npcPurses[hustler.id] {
                        HStack(spacing: 2) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text("\(purse)")
                                .font(.caption2.bold())
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            Spacer()

            Button {
                dismiss()
                onChallenge(hustler)
            } label: {
                Text("Challenge")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.purple)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.purple.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Helpers

    private func rungColor(isDefeated: Bool, isNextChallenger: Bool) -> Color {
        if isDefeated { return .green }
        if isNextChallenger { return .blue }
        return Color(.systemGray4)
    }

    private func previousNPCName(before position: Int) -> String? {
        guard position > 0, position - 1 < npcs.count else { return nil }
        return npcs[position - 1].name
    }

    private var difficultyColor: Color {
        npcDifficultyColor(for: court.primaryDifficulty)
    }

    private func npcDifficultyColor(_ npc: NPC) -> Color {
        npcDifficultyColor(for: npc.difficulty)
    }

    private func npcDifficultyColor(for difficulty: NPCDifficulty) -> Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .purple
        case .expert: return .orange
        case .master: return .red
        }
    }
}
