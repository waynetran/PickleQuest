import Foundation

@MainActor
@Observable
final class TutorialViewModel {
    enum Phase: Equatable {
        case intro
        case matchInProgress
        case matchResult
    }

    var phase: Phase = .intro
    var currentTipIndex: Int = 0
    var matchVM: MatchViewModel?

    var introTips: [TutorialTip] {
        [
            TutorialTip(
                title: "Welcome to PickleQuest!",
                body: "You're about to play your very first pickleball match. Coach Pickles will go easy on you.",
                icon: "hand.wave.fill"
            ),
            TutorialTip(
                title: "How Matches Work",
                body: "Matches simulate point-by-point. Your stats, equipment, and strategy determine the outcome.",
                icon: "sportscourt.fill"
            ),
            TutorialTip(
                title: "Ready?",
                body: "Let's step onto the court and show Coach Pickles what you're made of!",
                icon: "figure.pickleball"
            ),
        ]
    }

    var currentTip: TutorialTip? {
        guard phase == .intro, currentTipIndex < introTips.count else { return nil }
        return introTips[currentTipIndex]
    }

    var hasMoreTips: Bool {
        phase == .intro && currentTipIndex < introTips.count - 1
    }

    func advanceTip() {
        if hasMoreTips {
            currentTipIndex += 1
        }
    }

    func startMatch(player: Player, matchService: MatchService, npcService: NPCService) async {
        phase = .matchInProgress

        let vm = MatchViewModel(matchService: matchService, npcService: npcService)
        vm.isRated = false
        matchVM = vm

        await vm.startMatch(player: player, opponent: TutorialNPC.opponent, courtName: "Tutorial Court")
    }

    func onMatchFinished() {
        phase = .matchResult
    }
}
