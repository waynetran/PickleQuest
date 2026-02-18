import SwiftUI

struct TutorialMatchView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel = TutorialViewModel()

    var body: some View {
        ZStack {
            switch viewModel.phase {
            case .intro:
                introOverlay

            case .matchInProgress:
                if let matchVM = viewModel.matchVM {
                    matchView(matchVM: matchVM)
                } else {
                    ProgressView("Starting match...")
                }

            case .matchResult:
                if let matchVM = viewModel.matchVM, let result = matchVM.matchResult {
                    MatchResultView(
                        result: result,
                        opponent: matchVM.selectedNPC,
                        matchVM: matchVM,
                        levelUpRewards: matchVM.levelUpRewards,
                        duprChange: nil,
                        potentialDuprChange: 0,
                        repChange: 0,
                        brokenEquipment: [],
                        energyDrain: 0
                    ) {
                        Task { await processTutorialResult(matchVM: matchVM) }
                    }
                }
            }
        }
    }

    // MARK: - Intro

    private var introOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            if let tip = viewModel.currentTip {
                let accent = tip.accentColor ?? Color.accentColor
                VStack(spacing: 16) {
                    Image(systemName: tip.icon)
                        .font(.system(size: 48))
                        .foregroundStyle(accent)

                    Text(tip.title)
                        .font(.title2.bold())

                    Text(tip.body)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 32)

                // Page indicator dots
                HStack(spacing: 8) {
                    ForEach(0..<viewModel.introTips.count, id: \.self) { index in
                        Circle()
                            .fill(index == viewModel.currentTipIndex ? accent : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }

            Spacer()

            if viewModel.hasMoreTips {
                Button("Next") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.advanceTip()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button("Let's Play!") {
                    Task {
                        await viewModel.startMatch(
                            player: appState.player,
                            matchService: container.matchService,
                            npcService: container.npcService
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()
                .frame(height: 40)
        }
    }

    // MARK: - Match

    @ViewBuilder
    private func matchView(matchVM: MatchViewModel) -> some View {
        Group {
            if matchVM.matchState == .finished {
                Color.clear
                    .onAppear { viewModel.onMatchFinished() }
            } else if matchVM.useSpriteVisualization {
                MatchSpriteView(viewModel: matchVM)
            } else {
                MatchSimulationView(viewModel: matchVM)
            }
        }
    }

    // MARK: - Result Processing

    private func processTutorialResult(matchVM: MatchViewModel) async {
        guard let result = matchVM.matchResult else { return }

        var player = appState.player

        // Simplified processing: XP and coins only
        let xp = result.xpEarned
        let coins = result.coinsEarned
        _ = player.progression.addXP(xp)
        player.wallet.coins += coins

        // Add loot to inventory
        let keptLoot = matchVM.lootDrops.filter { matchVM.lootDecisions[$0.id] != nil }
        if !keptLoot.isEmpty {
            await container.inventoryService.addEquipmentBatch(keptLoot)
        }

        // Equip items marked for equip
        for item in matchVM.lootDrops {
            if matchVM.lootDecisions[item.id] == .equip {
                player.equippedItems[item.slot] = item.id
            }
        }

        appState.player = player
        appState.appPhase = .tutorialPostMatch
    }
}
