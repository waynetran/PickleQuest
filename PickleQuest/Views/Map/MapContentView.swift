import SwiftUI
import MapKit

struct MapContentView: View {
    let mapVM: MapViewModel
    let matchVM: MatchViewModel
    @Environment(AppState.self) private var appState

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var undiscoveredCourt: Court?
    @State private var isDoublesMode = false
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var showTrainingView = false
    @State private var playerAnimationState: CharacterAnimationState = .idleBack
    @State private var walkResetTask: Task<Void, Never>?
    @State private var discoveredCourtName: String?
    @State private var showChallenges = false

    var body: some View {
        @Bindable var mapState = mapVM

        MapReader { proxy in
        ZStack {
            mapLayer

            // Fog of war overlay
            if appState.fogOfWarEnabled, let region = visibleRegion {
                FogOfWarOverlay(
                    revealedCells: appState.revealedFogCells,
                    proxy: proxy,
                    region: region
                )
            }

            // Dev mode movement controls
            if appState.isDevMode {
                VStack {
                    Spacer()
                    HStack {
                        DevMovementPad(mapVM: mapVM, appState: appState) { direction in
                            // Set walk animation matching direction
                            switch direction {
                            case .north: playerAnimationState = .walkAway
                            case .south: playerAnimationState = .walkToward
                            case .east: playerAnimationState = .walkRight
                            case .west: playerAnimationState = .walkLeft
                            }
                            // Reset to idle after a short delay
                            walkResetTask?.cancel()
                            walkResetTask = Task {
                                try? await Task.sleep(for: .milliseconds(600))
                                if !Task.isCancelled {
                                    playerAnimationState = .idleBack
                                }
                            }
                        }
                            .padding(.leading, 16)
                        Spacer()
                    }
                    .padding(.bottom, 72) // above the bottom bar
                }
            }

            // Daily challenge icon (top right)
            if let challengeState = mapVM.dailyChallengeState, !challengeState.challenges.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showChallenges = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "star.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.yellow)
                                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)

                                // Progress badge
                                Text("\(challengeState.completedCount)/\(challengeState.challenges.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(challengeState.allCompleted ? .green : .red)
                                    .clipShape(Capsule())
                                    .offset(x: 4, y: -4)
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    }
                    Spacer()
                }
            }

            // Court discovery notification
            if let courtName = discoveredCourtName {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.green)
                        Text("Discovered \(courtName)!")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.black.opacity(0.8))
                    .clipShape(Capsule())
                    .padding(.bottom, 80)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.4), value: discoveredCourtName)
            }

            // Bottom overlay: court count + energy
            VStack {
                Spacer()
                bottomBar
            }
        }
        } // MapReader
        .task {
            await setupMap()
        }
        .onChange(of: appState.locationOverride) { _, newOverride in
            if let coord = newOverride {
                // Only recenter camera when not in sticky mode (sticky mode = user is panning)
                if !mapVM.isStickyMode {
                    let currentSpan = mapVM.lastCameraRegion?.span
                        ?? MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    cameraPosition = .region(MKCoordinateRegion(
                        center: coord,
                        span: currentSpan
                    ))
                }
                Task { await mapVM.generateCourtsIfNeeded(around: coord) }
                runDiscoveryCheck()
            }
        }
        .sheet(isPresented: $mapState.showCourtDetail) {
            if let court = mapVM.selectedCourt {
                CourtDetailSheet(
                    court: court,
                    npcs: mapVM.npcsAtSelectedCourt,
                    hustlers: mapVM.hustlersAtSelectedCourt,
                    playerRating: appState.player.duprRating,
                    ladder: mapVM.currentLadder,
                    doublesLadder: nil, // Phase 6: doubles ladder
                    courtPerk: mapVM.currentCourtPerk,
                    alphaNPC: mapVM.alphaNPC,
                    doublesAlphaNPC: nil, // Phase 6: doubles alpha
                    playerPersonality: appState.player.personality,
                    coach: mapVM.coachAtSelectedCourt,
                    player: appState.player,
                    isRated: Bindable(matchVM).isRated,
                    isDoublesMode: $isDoublesMode,
                    onChallenge: { npc in
                        // Hustlers and wager-eligible NPCs go through the wager sheet
                        matchVM.pendingWagerNPC = npc
                        matchVM.showWagerSheet = true
                    },
                    onDoublesChallenge: { opp1, opp2 in
                        matchVM.selectedNPC = opp1
                        matchVM.opponentPartner = opp2
                        matchVM.isDoublesMode = true
                        matchVM.matchState = .selectingPartner
                    },
                    onTournament: {
                        // Phase 5: tournament flow
                    },
                    onCoachTraining: {
                        showTrainingView = true
                    }
                )
            }
        }
        .sheet(isPresented: Bindable(matchVM).showWagerSheet) {
            if let npc = matchVM.pendingWagerNPC {
                WagerSelectionSheet(
                    npc: npc,
                    playerCoins: appState.player.wallet.coins,
                    playerSUPR: appState.player.duprRating,
                    consecutiveWins: appState.player.npcLossRecord[npc.id] ?? 0,
                    onAccept: { wagerAmount in
                        let courtNameForMatch = mapVM.selectedCourt?.name ?? ""
                        Task {
                            await matchVM.startMatch(
                                player: appState.player,
                                opponent: npc,
                                courtName: courtNameForMatch,
                                wagerAmount: wagerAmount
                            )
                        }
                        matchVM.pendingWagerNPC = nil
                    },
                    onCancel: {
                        matchVM.pendingWagerNPC = nil
                    }
                )
            }
        }
        .onChange(of: mapVM.locationManager.currentLocation?.coordinate) { _, _ in
            // Continuous discovery check as real GPS updates
            if appState.locationOverride == nil {
                runDiscoveryCheck()
            }
        }
        .confirmationDialog(
            "Undiscovered Court",
            isPresented: Binding(
                get: { undiscoveredCourt != nil },
                set: { if !$0 { undiscoveredCourt = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let court = undiscoveredCourt {
                Button("Directions in Apple Maps") {
                    openInAppleMaps(court: court)
                    undiscoveredCourt = nil
                }
                if canOpenGoogleMaps {
                    Button("Directions in Google Maps") {
                        openInGoogleMaps(court: court)
                        undiscoveredCourt = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    undiscoveredCourt = nil
                }
            }
        } message: {
            Text("Walk within 200m to discover this court and challenge its players.")
        }
        .sheet(isPresented: $showTrainingView) {
            if let coach = mapVM.coachAtSelectedCourt {
                TrainingDrillView(coach: coach)
                    .environment(appState)
            }
        }
        .sheet(isPresented: $showChallenges) {
            if let challengeState = mapVM.dailyChallengeState {
                NavigationStack {
                    DailyChallengeListView(state: challengeState) {
                        if challengeState.allCompleted && !challengeState.bonusClaimed {
                            appState.player.wallet.coins += GameConstants.DailyChallenge.completionBonusCoins
                            mapVM.dailyChallengeState?.bonusClaimed = true
                            appState.player.dailyChallengeState = mapVM.dailyChallengeState
                        }
                    }
                    .navigationTitle("Daily Challenges")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showChallenges = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Map Layer

    private var mapLayer: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
            // Player location (dev override, real GPS, or fallback)
            if let playerCoord = appState.locationOverride ?? mapVM.locationManager.currentLocation?.coordinate {
                Annotation(appState.player.name, coordinate: playerCoord) {
                    MapPlayerAnnotation(
                        appearance: appState.player.appearance,
                        animationState: playerAnimationState
                    )
                }
            } else {
                UserAnnotation()
            }

            // Court annotations — all courts always visible; undiscovered show "?"
            ForEach(mapVM.courts) { court in
                let discovered = appState.player.discoveredCourtIDs.contains(court.id)
                Annotation(
                    discovered ? court.name : "???",
                    coordinate: court.coordinate
                ) {
                    CourtAnnotationView(
                        court: court,
                        isDiscovered: discovered
                    ) {
                        if discovered {
                            Task { await mapVM.selectCourt(court) }
                        }
                    }
                    .disabled(!discovered)
                }
                .annotationTitles(.hidden)
            }

            // Coach sprites at courts (full-size, tapping opens court detail)
            ForEach(mapVM.courts) { court in
                let discovered = appState.player.discoveredCourtIDs.contains(court.id)
                if discovered && mapVM.courtIDsWithCoaches.contains(court.id) {
                    Annotation("", coordinate: court.coachCoordinate) {
                        AnimatedSpriteView(
                            appearance: mapVM.coachAppearances[court.id] ?? .defaultOpponent,
                            size: 160,
                            animationState: .idleFront
                        )
                        .onTapGesture {
                            Task { await mapVM.selectCourt(court) }
                        }
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .mapControls {
            MapCompass()
        }
        .onMapCameraChange(frequency: .continuous) { context in
            visibleRegion = context.region
            mapVM.lastCameraRegion = context.region
            mapVM.updateStickyLocation(
                center: context.camera.centerCoordinate,
                appState: appState
            )
        }
    }

    // MARK: - Setup

    private func setupMap() async {
        let hasRestoredCamera = mapVM.lastCameraRegion != nil

        // Restore camera position from previous session, or set initial position
        if let savedRegion = mapVM.lastCameraRegion {
            cameraPosition = .region(savedRegion)
        } else if let override = appState.locationOverride {
            cameraPosition = .region(MKCoordinateRegion(
                center: override,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        } else {
            cameraPosition = .userLocation(fallback: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )))
        }

        mapVM.requestLocationPermission()
        mapVM.startLocationUpdates()

        // Load daily challenges
        await mapVM.loadDailyChallenges(playerState: appState.player.dailyChallengeState)

        // Reset coaching daily sessions
        appState.player.coachingRecord.resetDailySessions()

        if let override = appState.locationOverride {
            await mapVM.generateCourtsIfNeeded(around: override)
            runDiscoveryCheck()
        } else {
            // Wait for real GPS
            for _ in 0..<100 { // up to 10 seconds
                if mapVM.locationManager.currentLocation != nil { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            if let loc = mapVM.locationManager.currentLocation {
                // Only set camera from GPS on first launch — don't clobber restored position
                if !hasRestoredCamera {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: loc.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                }
                await mapVM.generateCourtsIfNeeded(around: loc.coordinate)
                runDiscoveryCheck()
            }
        }
    }

    private func runDiscoveryCheck() {
        guard let loc = mapVM.effectiveLocation(devOverride: appState.locationOverride) else { return }
        appState.revealFog(around: loc.coordinate)

        let newIDs = mapVM.checkDiscovery(
            playerLocation: loc,
            discoveredIDs: appState.player.discoveredCourtIDs,
            isDevMode: appState.isDevMode
        )
        for id in newIDs {
            appState.player.discoveredCourtIDs.insert(id)
            appState.player.dailyChallengeState?.incrementProgress(for: .visitCourts)
            // Show discovery notification and auto-open court details
            if let court = mapVM.courts.first(where: { $0.id == id }) {
                discoveredCourtName = court.name
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    if discoveredCourtName == court.name {
                        discoveredCourtName = nil
                    }
                }
                // Auto-open the newly discovered court
                Task { await mapVM.selectCourt(court) }
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            // Discovery progress
            let discovered = appState.player.discoveredCourtIDs.count
            let total = mapVM.courts.count
            Label("\(discovered)/\(total) courts", systemImage: "map.fill")
                .font(.caption.bold())

            Spacer()

            // SUPR
            if appState.player.duprProfile.hasRating {
                Label(
                    String(format: "%.2f", appState.player.duprRating),
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                .font(.caption.bold())
                .foregroundStyle(.green)
            }

            // Energy
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(energyColor)
                Text("\(Int(appState.player.currentEnergy))%")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(energyColor)
            }

            // Paddle warning
            if !appState.player.hasPaddleEquipped {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Directions

    private var canOpenGoogleMaps: Bool {
        UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!)
    }

    private func openInAppleMaps(court: Court) {
        let placemark = MKPlacemark(coordinate: court.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "Undiscovered Court"
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    private func openInGoogleMaps(court: Court) {
        let urlString = "comgooglemaps://?daddr=\(court.latitude),\(court.longitude)&directionsmode=walking"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private var energyColor: Color {
        let energy = appState.player.currentEnergy
        if energy >= 80 { return .green }
        if energy >= 50 { return .yellow }
        return .red
    }
}

// MARK: - Player Dot

struct PlayerAnnotationDot: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.2))
                .frame(width: 28, height: 28)
            Circle()
                .fill(.blue)
                .frame(width: 14, height: 14)
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: 14, height: 14)
        }
    }
}

// MARK: - Dev Movement D-Pad

struct DevMovementPad: View {
    let mapVM: MapViewModel
    let appState: AppState
    var onMove: ((MapViewModel.MoveDirection) -> Void)?

    var body: some View {
        VStack(spacing: 4) {
            // North
            directionButton(.north, icon: "chevron.up")

            HStack(spacing: 4) {
                // West
                directionButton(.west, icon: "chevron.left")

                // Sticky mode toggle (center)
                Button {
                    mapVM.isStickyMode.toggle()
                } label: {
                    Image(systemName: mapVM.isStickyMode ? "scope" : "pin.slash")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(mapVM.isStickyMode ? Color.orange : Color(.systemGray5))
                        .foregroundStyle(mapVM.isStickyMode ? .white : .primary)
                        .clipShape(Circle())
                }

                // East
                directionButton(.east, icon: "chevron.right")
            }

            // South
            directionButton(.south, icon: "chevron.down")
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func directionButton(_ direction: MapViewModel.MoveDirection, icon: String) -> some View {
        Button {
            mapVM.movePlayer(direction: direction, appState: appState)
            onMove?(direction)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 36, height: 36)
                .background(Color(.systemGray5))
                .clipShape(Circle())
        }
    }
}
