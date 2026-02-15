import SwiftUI

struct TutorialPostMatchView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer
    @State private var currentCard: Int = 0

    private let cards: [(icon: String, title: String, body: String)] = [
        (
            "bag.fill",
            "You Earned Loot!",
            "Check your Inventory tab to see your equipment. Equip items to boost your stats and gain the edge in matches."
        ),
        (
            "map.fill",
            "Explore Your City",
            "Courts and challengers are scattered around your area. Visit real-world locations to discover new opponents and unlock courts."
        ),
        (
            "trophy.fill",
            "Rise Through the Ranks",
            "Beat court ladders, enter tournaments, and climb the SUPR rating leaderboard. Your pickleball journey starts now!"
        ),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Card content
            let card = cards[currentCard]
            VStack(spacing: 16) {
                Image(systemName: card.icon)
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)

                Text(card.title)
                    .font(.title.bold())

                Text(card.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)

            Spacer()

            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<cards.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentCard ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            // Button
            if currentCard < cards.count - 1 {
                Button("Next") {
                    withAnimation { currentCard += 1 }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button("Let's Go!") {
                    Task { await finishTutorial() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()
                .frame(height: 40)
        }
        .animation(.easeInOut, value: currentCard)
    }

    private func finishTutorial() async {
        appState.tutorialCompleted = true

        // Save with tutorial completed
        let inventory = await container.inventoryService.getInventory()
        let consumables = await container.inventoryService.getConsumables()
        await appState.saveCurrentPlayer(
            using: container.persistenceService,
            inventory: inventory,
            consumables: consumables
        )

        appState.appPhase = .playing
    }
}
