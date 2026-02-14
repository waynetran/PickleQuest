import SwiftUI

@main
struct PickleQuestApp: App {
    @State private var appState = AppState()
    @StateObject private var container = DependencyContainer.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environmentObject(container)
        }
    }
}
