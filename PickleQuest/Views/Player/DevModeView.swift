import SwiftUI
import CoreLocation

struct DevModeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var latitudeText: String = ""
    @State private var longitudeText: String = ""

    var body: some View {
        NavigationStack {
            List {
                devModeToggleSection
                if appState.isDevMode {
                    fogOfWarSection
                    statsSection
                    ratingSection
                    progressionSection
                    economySection
                    energySection
                    coachingSection
                    dailyChallengeSection
                    locationSection
                    resetSection
                }
            }
            .navigationTitle("Developer Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if let coord = appState.locationOverride {
                    latitudeText = String(format: "%.6f", coord.latitude)
                    longitudeText = String(format: "%.6f", coord.longitude)
                }
            }
        }
    }

    // MARK: - Sections

    private var devModeToggleSection: some View {
        Section {
            Toggle("Developer Mode", isOn: Binding(
                get: { appState.isDevMode },
                set: { enabled in
                    if enabled {
                        appState.enableDevMode()
                    } else {
                        appState.disableDevMode()
                    }
                }
            ))
        } footer: {
            Text("Override player stats, rating, and location for testing. A snapshot is saved when enabled so you can reset later.")
        }
    }

    private var fogOfWarSection: some View {
        Section("Fog of War") {
            Toggle("Fog of War", isOn: Binding(
                get: { appState.fogOfWarEnabled },
                set: { appState.fogOfWarEnabled = $0 }
            ))

            HStack {
                Text("Revealed cells")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(appState.revealedFogCells.count)")
                    .font(.subheadline.monospacedDigit())
            }

            Button("Clear Fog (Reveal All)", role: .destructive) {
                appState.fogOfWarEnabled = false
            }
            .font(.subheadline)
        }
    }

    private var statsSection: some View {
        Section("Base Stats") {
            ForEach(StatCategory.allCases, id: \.self) { category in
                ForEach(category.stats, id: \.self) { stat in
                    statSlider(stat)
                }
            }
        }
    }

    private func statSlider(_ stat: StatType) -> some View {
        @Bindable var state = appState
        let value = Binding<Double>(
            get: { Double(appState.player.stats.stat(stat)) },
            set: { appState.player.stats.setStat(stat, value: Int($0)) }
        )
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(stat.displayName)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(value.wrappedValue))")
                    .font(.subheadline.bold().monospacedDigit())
            }
            Slider(
                value: value,
                in: Double(GameConstants.Stats.minValue)...Double(GameConstants.Stats.maxValue),
                step: 1
            )
        }
    }

    private var ratingSection: some View {
        Section("Rating & Reputation") {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("SUPR Rating")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.2f", appState.player.duprProfile.rating))
                        .font(.subheadline.bold().monospacedDigit())
                }
                Slider(
                    value: Binding(
                        get: { appState.player.duprProfile.rating },
                        set: { appState.player.duprProfile.rating = $0 }
                    ),
                    in: GameConstants.DUPRRating.minRating...GameConstants.DUPRRating.maxRating,
                    step: 0.01
                )
            }

            Stepper(
                "Rated Matches: \(appState.player.duprProfile.ratedMatchCount)",
                value: Binding(
                    get: { appState.player.duprProfile.ratedMatchCount },
                    set: { appState.player.duprProfile.ratedMatchCount = max(0, $0) }
                ),
                in: 0...999
            )
            .font(.subheadline)

            Stepper(
                "Reputation: \(appState.player.repProfile.reputation)",
                value: Binding(
                    get: { appState.player.repProfile.reputation },
                    set: { appState.player.repProfile.reputation = $0 }
                ),
                in: -100...5000
            )
            .font(.subheadline)

            HStack {
                Text("Title")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(appState.player.repProfile.title)
                    .font(.subheadline)
                    .foregroundStyle(.purple)
            }
        }
    }

    private var progressionSection: some View {
        Section("Progression") {
            Stepper(
                "Level: \(appState.player.progression.level)",
                value: Binding(
                    get: { appState.player.progression.level },
                    set: { appState.player.progression.level = $0 }
                ),
                in: 1...GameConstants.Stats.maxLevel
            )
            .font(.subheadline)

            Stepper(
                "Stat Points: \(appState.player.progression.availableStatPoints)",
                value: Binding(
                    get: { appState.player.progression.availableStatPoints },
                    set: { appState.player.progression.availableStatPoints = max(0, $0) }
                ),
                in: 0...150
            )
            .font(.subheadline)
        }
    }

    private var economySection: some View {
        Section("Economy") {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Coins")
                        .font(.subheadline)
                    Spacer()
                    Text("\(appState.player.wallet.coins)")
                        .font(.subheadline.bold().monospacedDigit())
                }
                Slider(
                    value: Binding(
                        get: { Double(appState.player.wallet.coins) },
                        set: { appState.player.wallet.coins = Int($0) }
                    ),
                    in: 0...50000,
                    step: 100
                )
            }
        }
    }

    private var energySection: some View {
        Section("Energy") {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Persistent Energy")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(appState.player.energy))%")
                        .font(.subheadline.bold().monospacedDigit())
                }
                Slider(
                    value: Binding(
                        get: { appState.player.energy },
                        set: {
                            appState.player.energy = $0
                            appState.player.lastMatchDate = Date()
                        }
                    ),
                    in: GameConstants.PersistentEnergy.minEnergy...GameConstants.PersistentEnergy.maxEnergy,
                    step: 1
                )
            }
        }
    }

    private var coachingSection: some View {
        Section("Coaching") {
            let totalBoosts = appState.player.coachingRecord.statBoosts.values.reduce(0, +)
            Text("Total coaching boosts: \(totalBoosts)")
                .font(.subheadline)

            ForEach(StatType.allCases, id: \.self) { stat in
                let boost = appState.player.coachingRecord.currentBoost(for: stat)
                if boost > 0 {
                    HStack {
                        Text(stat.displayName)
                            .font(.caption)
                        Spacer()
                        Text("+\(boost)")
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                    }
                }
            }

            Button("Reset Coaching Record", role: .destructive) {
                appState.player.coachingRecord = .empty
            }
            .font(.subheadline)
        }
    }

    private var dailyChallengeSection: some View {
        Section("Daily Challenges") {
            if let state = appState.player.dailyChallengeState {
                Text("Challenges: \(state.completedCount)/\(state.challenges.count)")
                    .font(.subheadline)
                Text("Bonus claimed: \(state.bonusClaimed ? "Yes" : "No")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No challenges loaded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Complete All Challenges") {
                if var state = appState.player.dailyChallengeState {
                    for i in state.challenges.indices {
                        state.challenges[i].currentCount = state.challenges[i].targetCount
                    }
                    appState.player.dailyChallengeState = state
                }
            }
            .font(.subheadline)

            Button("Reset Daily Challenges", role: .destructive) {
                appState.player.dailyChallengeState = nil
            }
            .font(.subheadline)
        }
    }

    private var locationSection: some View {
        Section("Location Override") {
            HStack {
                Text("Latitude")
                    .font(.subheadline)
                Spacer()
                TextField("37.7749", text: $latitudeText)
                    .font(.subheadline.monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(width: 140)
            }

            HStack {
                Text("Longitude")
                    .font(.subheadline)
                Spacer()
                TextField("-122.4194", text: $longitudeText)
                    .font(.subheadline.monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numbersAndPunctuation)
                    .frame(width: 140)
            }

            HStack {
                Button("Set Location") {
                    if let lat = Double(latitudeText),
                       let lng = Double(longitudeText),
                       (-90...90).contains(lat),
                       (-180...180).contains(lng) {
                        appState.locationOverride = CLLocationCoordinate2D(
                            latitude: lat,
                            longitude: lng
                        )
                    }
                }
                .font(.subheadline)

                Spacer()

                if appState.locationOverride != nil {
                    Button("Clear", role: .destructive) {
                        appState.locationOverride = nil
                        latitudeText = ""
                        longitudeText = ""
                    }
                    .font(.subheadline)
                }
            }

            if let coord = appState.locationOverride {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.blue)
                    Text(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var resetSection: some View {
        Section {
            Button("Reset to True Values", role: .destructive) {
                appState.resetToTrueValues()
                latitudeText = ""
                longitudeText = ""
            }
            .disabled(appState.devModeSnapshot == nil)
        } footer: {
            if appState.devModeSnapshot != nil {
                Text("Restores all player values to the snapshot taken when dev mode was enabled.")
            }
        }
    }
}
