import SwiftUI

struct MatchSimulationView: View {
    let viewModel: MatchViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Score header
            if let score = viewModel.currentScore {
                BroadcastScoreOverlay(
                    playerName: viewModel.isDoublesMode ? "Your Team" : "You",
                    opponentName: viewModel.selectedNPC?.name ?? "Opponent",
                    playerScore: score.playerPoints,
                    opponentScore: score.opponentPoints,
                    playerGames: score.playerGames,
                    opponentGames: score.opponentGames,
                    servingSide: viewModel.currentServingSide,
                    courtName: viewModel.courtName,
                    isDoubles: viewModel.isDoublesMode,
                    doublesScoreDisplay: viewModel.doublesScoreDisplay
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

// MARK: - Broadcast Score Overlay (PPA/PBTV style)

struct BroadcastScoreOverlay: View {
    let playerName: String
    let opponentName: String
    let playerScore: Int
    let opponentScore: Int
    let playerGames: Int
    let opponentGames: Int
    let servingSide: MatchSide
    let courtName: String
    var isDoubles: Bool = false
    var doublesScoreDisplay: String? = nil

    private var tournamentName: String {
        TournamentNameGenerator.generate(from: courtName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tournament header (fills full width)
            Text(tournamentName.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.85))

            // Player rows
            VStack(spacing: 0) {
                playerRow(
                    name: playerName,
                    score: playerScore,
                    games: playerGames,
                    isServing: servingSide == .player
                )
                Divider().background(Color.gray.opacity(0.3))
                playerRow(
                    name: opponentName,
                    score: opponentScore,
                    games: opponentGames,
                    isServing: servingSide == .opponent
                )
            }
            .background(Color.black.opacity(0.85))

            // Event info footer
            HStack(spacing: 6) {
                Text(isDoubles ? "DOUBLES" : "SINGLES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                if let dsd = doublesScoreDisplay {
                    Text("\u{2022}")
                        .foregroundStyle(.white.opacity(0.5))
                    Text(dsd)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.6))
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .frame(width: 240)
    }

    private func playerRow(name: String, score: Int, games: Int, isServing: Bool) -> some View {
        HStack(spacing: 0) {
            // Server indicator
            Circle()
                .fill(isServing ? Color.green : Color.clear)
                .frame(width: 7, height: 7)
                .padding(.leading, 8)

            // Player name
            Text(name.uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.leading, 8)

            Spacer()

            // Points score
            Text("\(score)")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 28)
                .contentTransition(.numericText())

            // Games score
            Text("\(games)")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(.green)
                .frame(width: 28)
                .background(Color.white.opacity(0.08))
                .contentTransition(.numericText())
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Tournament Name Generator

enum TournamentNameGenerator {
    private static let suffixes = [
        "Classic", "Open", "Invitational", "Masters",
        "Championship", "Showdown", "Cup", "Grand Prix"
    ]

    private static let prefixes = [
        "The", "The Annual", "The Legendary", "The Grand"
    ]

    static func generate(from courtName: String) -> String {
        guard !courtName.isEmpty else {
            return "The PickleQuest Open"
        }

        // Use a deterministic hash so the same court always gets the same name
        let hash = abs(courtName.hashValue)
        let prefix = prefixes[hash % prefixes.count]
        let suffix = suffixes[(hash / prefixes.count) % suffixes.count]

        // Clean up the court name — remove common suffixes like "Park", "Center", "Courts"
        let cleanName = courtName
            .replacingOccurrences(of: " Courts", with: "")
            .replacingOccurrences(of: " Court", with: "")
            .replacingOccurrences(of: " Recreation Center", with: "")
            .replacingOccurrences(of: " Rec Center", with: "")

        return "\(prefix) \(cleanName) \(suffix)"
    }
}

// MARK: - Event Row

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
        case .timeoutCalled: return .cyan
        case .consumableUsed: return .green
        case .hookCallAttempt(_, let success, _): return success ? .yellow : .red
        case .sideOut: return .cyan
        case .resigned: return .red
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
