import SwiftUI

struct TournamentBracketView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer

    @State private var viewModel: TournamentViewModel?

    let court: Court
    let matchType: MatchType

    var body: some View {
        Group {
            if let viewModel {
                tournamentContent(viewModel: viewModel)
            } else {
                ProgressView("Loading tournament...")
            }
        }
        .task {
            if viewModel == nil {
                let vm = TournamentViewModel(
                    tournamentService: MockTournamentService(),
                    matchService: container.matchService,
                    inventoryService: container.inventoryService,
                    npcService: container.npcService
                )
                viewModel = vm
                await vm.generateTournament(
                    court: court,
                    matchType: matchType,
                    player: appState.player
                )
            }
        }
    }

    // MARK: - Main Content Router

    @ViewBuilder
    private func tournamentContent(viewModel: TournamentViewModel) -> some View {
        switch viewModel.state {
        case .idle:
            ProgressView("Generating bracket...")

        case .bracketPreview:
            bracketPreviewView(viewModel: viewModel)

        case .roundInProgress:
            roundInProgressView(viewModel: viewModel)

        case .playerMatch:
            playerMatchView(viewModel: viewModel)

        case .roundResults:
            roundResultsView(viewModel: viewModel)

        case .finished:
            finishedView(viewModel: viewModel)
        }
    }

    // MARK: - Bracket Preview

    private func bracketPreviewView(viewModel: TournamentViewModel) -> some View {
        VStack(spacing: 0) {
            tournamentHeader(viewModel: viewModel)

            ScrollView(.horizontal, showsIndicators: false) {
                bracketDiagram(viewModel: viewModel)
                    .padding()
            }

            Spacer()

            Button {
                viewModel.startTournament(player: appState.player)
            } label: {
                Text("Start Tournament")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }

    // MARK: - Round In Progress

    private func roundInProgressView(viewModel: TournamentViewModel) -> some View {
        VStack(spacing: 0) {
            tournamentHeader(viewModel: viewModel)

            ScrollView(.horizontal, showsIndicators: false) {
                bracketDiagram(viewModel: viewModel)
                    .padding()
            }

            if viewModel.isSimulatingNPCMatches {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Matches in progress...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }

            Spacer()
        }
    }

    // MARK: - Player Match

    @ViewBuilder
    private func playerMatchView(viewModel: TournamentViewModel) -> some View {
        if let matchVM = viewModel.matchViewModel {
            playerMatchContent(viewModel: viewModel, matchVM: matchVM)
        } else {
            ProgressView("Setting up match...")
        }
    }

    private func playerMatchContent(viewModel: TournamentViewModel, matchVM: MatchViewModel) -> some View {
        VStack(spacing: 16) {
            // Header
            Text("Your Tournament Match")
                .font(.title2.bold())
                .padding(.top)

            if let tournament = viewModel.tournament {
                let currentRound = viewModel.currentRound
                if currentRound < tournament.bracket.rounds.count {
                    let roundMatches = tournament.bracket.rounds[currentRound]
                    if let playerMatch = roundMatches.first(where: { $0.isPlayerMatch }) {
                        matchupBanner(
                            seed1: playerMatch.seed1,
                            seed2: playerMatch.seed2
                        )
                    }
                }
            }

            // Match event log
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(matchVM.eventLog) { entry in
                            Text(entry.narration)
                                .font(.caption)
                                .foregroundStyle(narrationColor(for: entry.event))
                                .id(entry.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: matchVM.eventLog.count) { _, _ in
                    if let last = matchVM.eventLog.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Score display
            if let score = matchVM.currentScore {
                HStack {
                    Text("You")
                        .font(.headline)
                    Spacer()
                    Text("\(score.playerPoints) - \(score.opponentPoints)")
                        .font(.title.monospacedDigit().bold())
                    Spacer()
                    Text(matchVM.selectedNPC?.name ?? "Opponent")
                        .font(.headline)
                }
                .padding(.horizontal, 24)
            }

            // Actions
            if matchVM.matchState == .simulating {
                HStack(spacing: 16) {
                    Button("Skip") {
                        Task { await matchVM.skipMatch() }
                    }
                    .buttonStyle(.bordered)

                    Button("Resign") {
                        Task { await matchVM.resignMatch() }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding(.bottom)
            }

            // When match finishes, show a continue button
            if matchVM.matchState == .finished {
                VStack(spacing: 8) {
                    if let result = matchVM.matchResult {
                        Text(result.didPlayerWin ? "Victory!" : "Defeat")
                            .font(.title.bold())
                            .foregroundStyle(result.didPlayerWin ? .green : .red)

                        Text("Score: \(result.formattedScore)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button("Continue Tournament") {
                        Task {
                            // This was already reported to the engine in runPlayerMatch
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
                }
            }
        }
        .task {
            await viewModel.runPlayerMatch(player: appState.player)
        }
    }

    // MARK: - Round Results

    private func roundResultsView(viewModel: TournamentViewModel) -> some View {
        VStack(spacing: 0) {
            tournamentHeader(viewModel: viewModel)

            ScrollView(.horizontal, showsIndicators: false) {
                bracketDiagram(viewModel: viewModel)
                    .padding()
            }

            Spacer()

            Button {
                viewModel.advanceToNextRound()
            } label: {
                Text("Next Round")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }

    // MARK: - Finished

    private func finishedView(viewModel: TournamentViewModel) -> some View {
        VStack(spacing: 20) {
            // Celebration / defeat header
            if viewModel.playerWon {
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow)

                    Text("Tournament Champion!")
                        .font(.largeTitle.bold())

                    if let champion = viewModel.champion {
                        Text(champion.displayName)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.gray)

                    Text("Tournament Over")
                        .font(.largeTitle.bold())

                    if let champion = viewModel.champion {
                        Text("\(champion.displayName) wins!")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Final bracket
            ScrollView(.horizontal, showsIndicators: false) {
                bracketDiagram(viewModel: viewModel)
                    .padding(.horizontal)
            }

            // Loot
            if !viewModel.tournamentLoot.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rewards")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(viewModel.tournamentLoot) { item in
                        HStack {
                            Circle()
                                .fill(item.rarity.color)
                                .frame(width: 10, height: 10)
                            Text(item.name)
                                .font(.subheadline)
                            Spacer()
                            Text(item.rarity.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }

            Spacer()

            Button {
                viewModel.reset()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }

    // MARK: - Tournament Header

    private func tournamentHeader(viewModel: TournamentViewModel) -> some View {
        VStack(spacing: 4) {
            if let tournament = viewModel.tournament {
                Text(tournament.name)
                    .font(.title2.bold())

                Text(viewModel.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(tournament.matchType == .doubles ? "Doubles" : "Singles")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(tournament.matchType == .doubles ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                    )
            }
        }
        .padding()
    }

    // MARK: - Bracket Diagram

    private func bracketDiagram(viewModel: TournamentViewModel) -> some View {
        HStack(alignment: .center, spacing: 40) {
            if let tournament = viewModel.tournament {
                ForEach(Array(tournament.bracket.rounds.enumerated()), id: \.offset) { roundIndex, round in
                    VStack(spacing: 0) {
                        // Round header
                        Text(roundLabel(roundIndex: roundIndex, totalRounds: tournament.bracket.rounds.count))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 12)

                        // Matches in this round
                        VStack(spacing: roundIndex == 0 ? 24 : 0) {
                            ForEach(round) { match in
                                matchCard(
                                    match: match,
                                    roundIndex: roundIndex,
                                    currentRound: tournament.bracket.currentRound,
                                    viewModel: viewModel
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func roundLabel(roundIndex: Int, totalRounds: Int) -> String {
        switch roundIndex {
        case totalRounds - 1:
            return "FINAL"
        case totalRounds - 2:
            return "SEMIFINAL"
        default:
            return "ROUND \(roundIndex + 1)"
        }
    }

    // MARK: - Match Card

    private func matchCard(
        match: TournamentMatch,
        roundIndex: Int,
        currentRound: Int,
        viewModel: TournamentViewModel
    ) -> some View {
        let isActive = roundIndex == currentRound && match.winner == nil
        let isPlayerMatch = match.isPlayerMatch

        return VStack(spacing: 0) {
            seedRow(
                seed: match.seed1,
                isWinner: match.winner?.id == match.seed1.id,
                isEliminated: match.winner != nil && match.winner?.id != match.seed1.id
            )

            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)

            seedRow(
                seed: match.seed2,
                isWinner: match.winner?.id == match.seed2.id,
                isEliminated: match.winner != nil && match.winner?.id != match.seed2.id
            )

            // Score display
            if let scoreString = match.scoreString {
                Text(scoreString)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(cardBackground(isActive: isActive, isPlayerMatch: isPlayerMatch))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardBorder(isActive: isActive, isPlayerMatch: isPlayerMatch), lineWidth: isActive ? 2 : 1)
        )
    }

    private func seedRow(
        seed: TournamentSeed,
        isWinner: Bool,
        isEliminated: Bool
    ) -> some View {
        HStack(spacing: 8) {
            // Seed number
            Text("#\(seed.seedNumber)")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .frame(width: 24)

            // Player indicator
            if seed.isPlayer {
                Image(systemName: "person.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }

            // Name
            VStack(alignment: .leading, spacing: 1) {
                Text(seed.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(isEliminated ? .secondary : .primary)
                    .lineLimit(1)

                Text(String(format: "%.1f DUPR", seed.averageDUPR))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Winner checkmark
            if isWinner {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .opacity(isEliminated ? 0.5 : 1.0)
    }

    private func cardBackground(isActive: Bool, isPlayerMatch: Bool) -> Color {
        if isActive && isPlayerMatch {
            return Color.blue.opacity(0.08)
        }
        if isActive {
            return Color.yellow.opacity(0.08)
        }
        return Color(.systemBackground)
    }

    private func cardBorder(isActive: Bool, isPlayerMatch: Bool) -> Color {
        if isActive && isPlayerMatch {
            return .blue
        }
        if isActive {
            return .yellow
        }
        return .secondary.opacity(0.3)
    }

    // MARK: - Matchup Banner

    private func matchupBanner(seed1: TournamentSeed, seed2: TournamentSeed) -> some View {
        HStack(spacing: 16) {
            VStack {
                Text(seed1.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(String(format: "%.1f", seed1.averageDUPR))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("VS")
                .font(.title3.bold())
                .foregroundStyle(.orange)

            VStack {
                Text(seed2.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(String(format: "%.1f", seed2.averageDUPR))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .padding(.horizontal)
    }

    // MARK: - Narration Color

    private func narrationColor(for event: MatchEvent) -> Color {
        switch event {
        case .matchStart, .gameStart:
            return .blue
        case .pointPlayed(let point):
            return point.winnerSide == .player ? .green : .red
        case .streakAlert(let side, _):
            return side == .player ? .green : .orange
        case .fatigueWarning:
            return .yellow
        case .matchEnd(let result):
            return result.didPlayerWin ? .green : .red
        case .resigned:
            return .red
        default:
            return .primary
        }
    }
}
