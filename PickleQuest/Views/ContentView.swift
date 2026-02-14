import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        @Bindable var state = appState
        TabView(selection: $state.selectedTab) {
            Tab("Match", systemImage: AppTab.match.iconName, value: .match) {
                MatchHubView()
            }

            Tab("Profile", systemImage: AppTab.profile.iconName, value: .profile) {
                PlayerProfileView()
            }

            Tab("Inventory", systemImage: AppTab.inventory.iconName, value: .inventory) {
                InventoryView()
            }

            Tab("Store", systemImage: AppTab.store.iconName, value: .store) {
                StoreView()
            }
        }
    }
}
