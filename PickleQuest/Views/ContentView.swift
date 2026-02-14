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
                InventoryStubView()
            }
        }
    }
}

struct InventoryStubView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Inventory")
                    .font(.title2.bold())
                Text("Coming in Milestone 2")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Inventory")
        }
    }
}
