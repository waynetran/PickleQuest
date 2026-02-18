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
                body: "Your first match is a warmup. Don't worry about controls yet — just get a feel for the court.",
                icon: "hand.wave.fill",
                accentColor: .green
            ),
            TutorialTip(
                title: "Scoring",
                body: "Pickleball to 11, win by 2. Side-out scoring means you only score when you're serving.",
                icon: "number.circle.fill",
                accentColor: .blue
            ),
            TutorialTip(
                title: "Movement + Serve",
                body: "Use the joystick (left side) to move your player. Swipe up on the right side to serve.",
                icon: "arrow.up.and.down.and.arrow.left.and.right",
                accentColor: .cyan
            ),
            TutorialTip(
                title: "Shot Modes",
                body: "7 buttons: Power (hard), Touch (precise), Lob (high arc), Slice (low), Topspin (kick), Angled (cross-court), Focus (accuracy).",
                icon: "slider.horizontal.3",
                accentColor: .orange
            ),
            TutorialTip(
                title: "Stamina",
                body: "The bar above your player is sprint stamina. Power shots drain it fast. Rest between points to recover.",
                icon: "bolt.fill",
                accentColor: .yellow
            ),
            TutorialTip(
                title: "Let's Play!",
                body: "Coach Pickles is waiting on the other side. He'll go easy on you — this time.",
                icon: "figure.pickleball",
                accentColor: .red
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
