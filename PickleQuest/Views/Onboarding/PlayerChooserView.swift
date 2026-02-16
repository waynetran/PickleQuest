import SwiftUI

struct PlayerChooserView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer
    @State private var savedPlayers: [SavedPlayerSummary] = []
    @State private var isLoading = true
    @State private var deletingPlayerID: UUID?
    @State private var loadError: String?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(savedPlayers) { summary in
                        Button {
                            Task { await loadAndContinue(id: summary.id) }
                        } label: {
                            PlayerSlotCard(summary: summary)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                deletingPlayerID = summary.id
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    // New character card
                    newCharacterCard
                }
                .padding()
            }
            .navigationTitle("Choose Player")
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .alert("Delete Player?", isPresented: Binding(
                get: { deletingPlayerID != nil },
                set: { if !$0 { deletingPlayerID = nil } }
            )) {
                Button("Cancel", role: .cancel) { deletingPlayerID = nil }
                Button("Delete", role: .destructive) {
                    if let id = deletingPlayerID {
                        Task { await deletePlayer(id: id) }
                    }
                }
            } message: {
                Text("This cannot be undone.")
            }
            .alert("Failed to Load", isPresented: Binding(
                get: { loadError != nil },
                set: { if !$0 { loadError = nil } }
            )) {
                Button("OK", role: .cancel) { loadError = nil }
            } message: {
                Text(loadError ?? "Unknown error")
            }
            .task {
                await refreshList()
            }
        }
    }

    private var newCharacterCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)

            Text("New Character")
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(minHeight: 140)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
        )
        .onTapGesture {
            appState.appPhase = .characterCreation
        }
    }

    private func refreshList() async {
        isLoading = true
        savedPlayers = (try? await container.persistenceService.listSavedPlayers()) ?? []
        isLoading = false
    }

    @MainActor
    private func loadAndContinue(id: UUID) async {
        do {
            let bundle = try await container.persistenceService.loadPlayer(id: id)
            appState.loadFromBundle(bundle)

            // Reset mock services with loaded data
            if let mockInventory = container.inventoryService as? MockInventoryService {
                await mockInventory.reset(inventory: bundle.inventory, consumables: bundle.consumables)
            }

            if bundle.tutorialCompleted {
                appState.appPhase = .playing
            } else {
                appState.appPhase = .tutorialMatch
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func deletePlayer(id: UUID) async {
        try? await container.persistenceService.deletePlayer(id: id)
        deletingPlayerID = nil
        await refreshList()

        // If no players left, go to creation
        if savedPlayers.isEmpty {
            appState.appPhase = .characterCreation
        }
    }
}
