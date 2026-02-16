import SwiftUI

struct MatchActionButtons: View {
    let viewModel: MatchViewModel
    @State private var showResignConfirm = false
    @State private var showConsumablePicker = false
    @State private var showNoItemsMessage = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Right-side action buttons (top right)
            VStack(spacing: 12) {
                ActionButton(
                    icon: "clock.arrow.circlepath",
                    label: "Timeout",
                    enabled: viewModel.canUseTimeout
                ) {
                    Task { await viewModel.callTimeout() }
                }

                ActionButton(
                    icon: "cup.and.saucer.fill",
                    label: "Item",
                    enabled: viewModel.matchState == .simulating && !viewModel.isSkipping
                ) {
                    if viewModel.playerConsumables.isEmpty {
                        showNoItemsMessage = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            showNoItemsMessage = false
                        }
                    } else if viewModel.canUseConsumable {
                        showConsumablePicker = true
                    }
                }

                ActionButton(
                    icon: "eye.trianglebadge.exclamationmark",
                    label: "Hook",
                    enabled: viewModel.canHookCall
                ) {
                    Task { await viewModel.hookLineCall() }
                }

                ActionButton(
                    icon: "flag.fill",
                    label: "Resign",
                    enabled: true,
                    tint: .red
                ) {
                    showResignConfirm = true
                }
            }
            .padding(.trailing, 12)
            .padding(.top, 12)

            // Skip button at bottom-right
            if !viewModel.isSkipping {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            Task { await viewModel.skipMatch() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 16))
                                Text("Skip")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(.black.opacity(0.6))
                            .clipShape(Capsule())
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 48)
                    }
                }
            }
        }
        .alert("Resign Match?", isPresented: $showResignConfirm) {
            Button("Resign", role: .destructive) {
                Task { await viewModel.resignMatch() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll take the loss. No DUPR change. Frequent resigns may cost reputation.")
        }
        .sheet(isPresented: $showConsumablePicker) {
            ConsumablePickerSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .overlay(alignment: .center) {
            if showNoItemsMessage {
                Text("No items available")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.black.opacity(0.7))
                    .clipShape(Capsule())
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showNoItemsMessage)
            }
        }
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let icon: String
    let label: String
    let enabled: Bool
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(enabled ? tint : .gray)
            .frame(width: 50, height: 50)
            .background(.black.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!enabled)
    }
}

// MARK: - Consumable Picker

private struct ConsumablePickerSheet: View {
    let viewModel: MatchViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if viewModel.playerConsumables.isEmpty {
                    Text("No consumables available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.playerConsumables) { consumable in
                        Button {
                            Task {
                                await viewModel.useConsumable(consumable)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Image(systemName: consumable.iconName)
                                    .foregroundStyle(.green)
                                VStack(alignment: .leading) {
                                    Text(consumable.name)
                                        .font(.headline)
                                    Text(consumable.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(effectDescription(consumable.effect))
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Use Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func effectDescription(_ effect: ConsumableEffect) -> String {
        switch effect {
        case .energyRestore(let amount):
            return "+\(Int(amount))% energy"
        case .statBoost(let stat, let amount, _):
            return "+\(amount) \(stat.rawValue)"
        case .xpMultiplier(let mult, _):
            return "\(mult)x XP"
        }
    }
}
