import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        Group {
            switch appState.appPhase {
            case .loading:
                ProgressView("Loading...")
                    .task { await resolveInitialPhase() }

            case .playerChooser:
                PlayerChooserView()

            case .characterCreation:
                CharacterCreationView()

            case .tutorialMatch:
                TutorialMatchView()

            case .tutorialPostMatch:
                TutorialPostMatchView()

            case .playing:
                ContentView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.appPhase)
    }

    private func resolveInitialPhase() async {
        do {
            let saved = try await container.persistenceService.listSavedPlayers()
            if saved.isEmpty {
                appState.appPhase = .characterCreation
            } else {
                appState.appPhase = .playerChooser
            }
        } catch {
            appState.appPhase = .characterCreation
        }
    }
}
