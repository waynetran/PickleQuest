import SwiftUI
import SwiftData

@main
struct PickleQuestApp: App {
    @State private var appState = AppState()
    @StateObject private var container: DependencyContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let schema = Schema([SavedPlayer.self])
        let config = ModelConfiguration(schema: schema)
        let modelContainer: ModelContainer
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        _container = StateObject(wrappedValue: DependencyContainer(modelContainer: modelContainer))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environmentObject(container)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background, appState.appPhase == .playing {
                        Task {
                            let inventory = await container.inventoryService.getInventory()
                            let consumables = await container.inventoryService.getConsumables()
                            await appState.saveCurrentPlayer(
                                using: container.persistenceService,
                                inventory: inventory,
                                consumables: consumables
                            )
                        }
                    }
                }
        }
    }
}
