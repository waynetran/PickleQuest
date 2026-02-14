import SwiftUI

struct MatchSimulationView: View {
    let viewModel: MatchViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Score header
            if let score = viewModel.currentScore {
                ScoreHeaderView(
                    playerScore: score.playerPoints,
                    opponentScore: score.opponentPoints,
                    playerGames: score.playerGames,
                    opponentGames: score.opponentGames,
                    opponentName: viewModel.selectedNPC?.name ?? "Opponent"
                )
            }

            // Event feed
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.eventLog) { entry in
                            EventRow(entry: entry)
                                .id(entry.id)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.eventLog.count) { _, _ in
                    if let last = viewModel.eventLog.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.eventLog.count)
    }
}

struct ScoreHeaderView: View {
    let playerScore: Int
    let opponentScore: Int
    let playerGames: Int
    let opponentGames: Int
    let opponentName: String

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                VStack {
                    Text("You")
                        .font(.caption.bold())
                    Text("\(playerScore)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("Games")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(playerGames) - \(opponentGames)")
                        .font(.callout.bold())
                }

                VStack {
                    Text(opponentName)
                        .font(.caption.bold())
                    Text("\(opponentScore)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

struct EventRow: View {
    let entry: MatchEventEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(eventColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            Text(entry.narration)
                .font(.subheadline)
                .foregroundStyle(eventTextColor)
        }
    }

    private var eventColor: Color {
        switch entry.event {
        case .matchStart, .matchEnd: return .yellow
        case .gameStart, .gameEnd: return .blue
        case .pointPlayed(let point):
            return point.winnerSide == .player ? .green : .red
        case .streakAlert: return .orange
        case .fatigueWarning: return .yellow
        case .abilityTriggered: return .purple
        }
    }

    private var eventTextColor: Color {
        switch entry.event {
        case .matchStart, .gameStart: return .secondary
        case .matchEnd: return .primary
        default: return .primary
        }
    }
}
