import SwiftUI
import MapKit

struct MapContentView: View {
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.009)

    let mapVM: MapViewModel
    let matchVM: MatchViewModel
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer

    @State private var cameraPosition: MapCameraPosition

    init(mapVM: MapViewModel, matchVM: MatchViewModel) {
        self.mapVM = mapVM
        self.matchVM = matchVM
        if let savedRegion = mapVM.lastCameraRegion {
            // Returning from a match — restore exact camera position
            _cameraPosition = State(initialValue: .region(savedRegion))
            _hasCenteredOnPlayer = State(initialValue: true)
        } else {
            // Fresh launch — .userLocation smoothly animates to GPS when available.
            // Never use .automatic — it's reactive to annotations and causes zoom jumps.
            _cameraPosition = State(initialValue: .userLocation(fallback: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MapContentView.defaultSpan
            ))))
        }
    }
    @State private var hasCenteredOnPlayer = false
    @State private var undiscoveredCourt: Court?
    @State private var isDoublesMode = false
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var showTrainingView = false
    @State private var playerAnimationState: CharacterAnimationState = .idleBack
    @State private var walkResetTask: Task<Void, Never>?
    @State private var discoveredCourtName: String?
    @State private var showChallenges = false
    @State private var gearDropToastMessage: String?

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
                            case .north: playerAnimationState = .runBack
                            case .south: playerAnimationState = .runFront
                            case .east: playerAnimationState = .runSide
                            case .west: playerAnimationState = .runSide
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

            // Trail banner
            if let trail = appState.player.gearDropState?.activeTrail, !trail.isExpired {
                VStack {
                    TrailBannerView(
                        trail: trail,
                        collectedIDs: appState.player.gearDropState?.collectedDropIDs ?? []
                    )
                    .padding(.top, 8)
                    Spacer()
                }
            }

            // Gear drop toast
            if let toast = gearDropToastMessage ?? mapVM.gearDropToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image("GearDropBackpack")
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text(toast)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.black.opacity(0.8))
                    .clipShape(Capsule())
                    .padding(.bottom, 120)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.4), value: gearDropToastMessage)
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

            // Recenter button (bottom right, above bottom bar)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        recenterMap()
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.blue)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
                }
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
                        ?? MapContentView.defaultSpan
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
                    npcPurses: mapVM.npcPursesAtSelectedCourt,
                    playerRating: appState.player.duprRating,
                    ladder: mapVM.currentLadder,
                    doublesLadder: nil, // Phase 6: doubles ladder
                    courtPerk: mapVM.currentCourtPerk,
                    alphaNPC: mapVM.alphaNPC,
                    doublesAlphaNPC: nil, // Phase 6: doubles alpha
                    playerPersonality: appState.player.playerType,
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
                    npcPurse: mapVM.npcPursesAtSelectedCourt[npc.id] ?? 0,
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
        .onChange(of: mapVM.locationManager.currentLocation?.coordinate) { _, newCoord in
            guard appState.locationOverride == nil else { return }
            // First GPS fix after permission granted — center camera + generate courts
            if !hasCenteredOnPlayer, let coord = newCoord {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coord,
                    span: MapContentView.defaultSpan
                ))
                hasCenteredOnPlayer = true
                Task { await mapVM.generateCourtsIfNeeded(around: coord) }
            }
            runDiscoveryCheck()
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
        .sheet(isPresented: Bindable(mapVM).showGearDropReveal) {
            if let drop = mapVM.selectedGearDrop {
                GearDropRevealSheet(
                    drop: drop,
                    equipment: mapVM.gearDropLoot,
                    coins: mapVM.gearDropCoins,
                    lootDecisions: Bindable(mapVM).gearDropLootDecisions,
                    onDismiss: {
                        processGearDropLoot()
                        mapVM.showGearDropReveal = false
                        mapVM.selectedGearDrop = nil
                    }
                )
            }
        }
        .sheet(isPresented: Bindable(mapVM).showContestedSheet) {
            if let drop = mapVM.selectedContestedDrop {
                ContestedDropSheet(
                    drop: drop,
                    onChallenge: {
                        mapVM.showContestedSheet = false
                        mapVM.pendingContestedDrop = drop
                        matchVM.contestedDropRarity = drop.rarity
                        matchVM.contestedDropItemCount = 3
                        Task {
                            let difficulty = drop.guardianDifficulty ?? .advanced
                            let npcs = await container.npcService.getNPCs(forDifficulty: difficulty)
                            guard let guardian = npcs.randomElement() else {
                                showGearDropToast("No guardian found... lucky you!")
                                return
                            }
                            await matchVM.startMatch(
                                player: appState.player,
                                opponent: guardian,
                                courtName: "Contested Drop"
                            )
                        }
                    },
                    onCancel: {
                        mapVM.showContestedSheet = false
                        mapVM.selectedContestedDrop = nil
                    }
                )
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
        .onChange(of: matchVM.matchState) { _, newState in
            // When a contested match returns to idle, clear the pending drop reference.
            // The actual collection happens in MatchHubView.processResult() on win.
            if newState == .idle, mapVM.pendingContestedDrop != nil {
                mapVM.pendingContestedDrop = nil
                mapVM.selectedContestedDrop = nil
            }
        }
    }

    // MARK: - Map Layer

    private var mapLayer: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
            // Player location (dev override, real GPS, or fallback)
            if let playerCoord = appState.locationOverride ?? mapVM.locationManager.currentLocation?.coordinate {
                // Discovery/interaction radius circle
                MapCircle(center: playerCoord, radius: MapViewModel.discoveryRadius)
                    .foregroundStyle(.blue.opacity(0.08))
                    .stroke(.blue.opacity(0.3), lineWidth: 1.5)

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

            // Gear drop annotations — only show within visibility radius for performance
            ForEach(nearbyGearDrops) { drop in
                let playerLoc = mapVM.effectiveLocation(devOverride: appState.locationOverride)
                let inRange = playerLoc.map { mapVM.isDropInRange(drop, playerLocation: $0) } ?? false
                Annotation("", coordinate: drop.coordinate) {
                    GearDropAnnotationView(drop: drop, isInRange: inRange) {
                        let loc = mapVM.effectiveLocation(devOverride: appState.locationOverride)
                        handleGearDropTap(drop, playerLocation: loc)
                    }
                }
                .annotationTitles(.hidden)
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

    // MARK: - Nearby Gear Drops

    private var nearbyGearDrops: [GearDrop] {
        guard let playerLoc = mapVM.effectiveLocation(devOverride: appState.locationOverride) else {
            return []
        }
        let visibilityRadius = GameConstants.GearDrop.annotationVisibilityRadius
        return mapVM.activeGearDrops.filter { drop in
            let dropLoc = CLLocation(latitude: drop.latitude, longitude: drop.longitude)
            return playerLoc.distance(from: dropLoc) <= visibilityRadius
        }
    }

    // MARK: - Setup

    private func setupMap() async {
        let hasRestoredCamera = mapVM.lastCameraRegion != nil

        // Dev mode override: set camera to override location once.
        if !hasCenteredOnPlayer, let override = appState.locationOverride {
            cameraPosition = .region(MKCoordinateRegion(
                center: override,
                span: MapContentView.defaultSpan
            ))
            hasCenteredOnPlayer = true
        }

        mapVM.requestLocationPermission()
        mapVM.startLocationUpdates()

        // Load daily challenges
        await mapVM.loadDailyChallenges(playerState: appState.player.dailyChallengeState)

        // Reset coaching daily sessions
        appState.player.coachingRecord.resetDailySessions()

        // Reset gear drop daily counters
        appState.player.gearDropState?.resetDailyIfNeeded()

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
                if !hasCenteredOnPlayer {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: loc.coordinate,
                        span: MapContentView.defaultSpan
                    ))
                    hasCenteredOnPlayer = true
                }
                await mapVM.generateCourtsIfNeeded(around: loc.coordinate)
                runDiscoveryCheck()
            }
        }
    }

    private func recenterMap() {
        if let coord = appState.locationOverride ?? mapVM.locationManager.currentLocation?.coordinate {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: Self.defaultSpan
            ))
        }
    }

    private func runDiscoveryCheck() {
        guard let loc = mapVM.effectiveLocation(devOverride: appState.locationOverride) else { return }

        // Capture fog cells before reveal for stash detection
        let previousCells = appState.revealedFogCells
        appState.revealFog(around: loc.coordinate)
        let newCells = appState.revealedFogCells.subtracting(previousCells)

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

        // Refresh gear drops
        Task {
            // Initialize gear drop state if needed
            if appState.player.gearDropState == nil {
                appState.player.gearDropState = GearDropState()
            }

            // Check fog stashes for newly revealed cells
            if !newCells.isEmpty {
                await mapVM.checkFogStashes(
                    newlyRevealed: newCells,
                    allRevealed: appState.revealedFogCells
                )
                if mapVM.gearDropToast != nil {
                    showGearDropToast(mapVM.gearDropToast!)
                    mapVM.gearDropToast = nil
                }
            }

            // Refresh all gear drops
            let discoveredCourts = mapVM.courts.filter {
                appState.player.discoveredCourtIDs.contains($0.id)
            }
            var state = appState.player.gearDropState ?? GearDropState()
            await mapVM.refreshGearDrops(
                around: loc.coordinate,
                state: &state,
                discoveredCourts: discoveredCourts
            )
            appState.player.gearDropState = state

            // Auto-pickup any drops within range
            autoPickupNearbyDrops(playerLocation: loc)
        }
    }

    private func autoPickupNearbyDrops(playerLocation: CLLocation) {
        for drop in mapVM.activeGearDrops {
            guard mapVM.isDropInRange(drop, playerLocation: playerLocation) else { continue }

            // Skip contested drops — they require an NPC fight
            if drop.type == .contested {
                continue
            }

            // Skip locked court caches — need to win a match first
            if drop.type == .courtCache && !drop.isUnlocked {
                continue
            }

            // Skip if a reveal sheet is already showing
            guard !mapVM.showGearDropReveal else { break }

            Task {
                await mapVM.collectGearDrop(drop, playerLevel: appState.player.progression.level)
            }
            // Only auto-open one at a time to avoid sheet stacking
            break
        }
    }

    private func handleGearDropTap(_ drop: GearDrop, playerLocation: CLLocation?) {
        guard let playerLocation else { return }

        guard mapVM.isDropInRange(drop, playerLocation: playerLocation) else {
            showGearDropToast("Dink closer to grab this loot!")
            return
        }

        if drop.type == .courtCache && !drop.isUnlocked {
            showGearDropToast("Win a match here first — no free lunch at the kitchen!")
            return
        }

        if drop.type == .contested {
            mapVM.selectedContestedDrop = drop
            mapVM.showContestedSheet = true
            return
        }

        Task {
            await mapVM.collectGearDrop(drop, playerLevel: appState.player.progression.level)
        }
    }

    private func showGearDropToast(_ message: String) {
        gearDropToastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if gearDropToastMessage == message {
                gearDropToastMessage = nil
            }
        }
    }

    private func processGearDropLoot() {
        // Default any undecided items to "keep"
        for item in mapVM.gearDropLoot {
            if mapVM.gearDropLootDecisions[item.id] == nil {
                mapVM.gearDropLootDecisions[item.id] = .keep
            }
        }

        // Add coins
        appState.player.wallet.coins += mapVM.gearDropCoins

        // Mark drop as collected
        if let drop = mapVM.selectedGearDrop {
            appState.player.gearDropState?.collectedDropIDs.insert(drop.id)

            // Court cache cooldown
            if drop.type == .courtCache, let courtID = drop.courtID {
                appState.player.gearDropState?.courtCacheCooldowns[courtID] =
                    Date().addingTimeInterval(GameConstants.GearDrop.courtCacheCooldown)
            }

            // Field drop counter
            if drop.type == .field {
                appState.player.gearDropState?.fieldDropsCollectedToday += 1
            }

            // Contested counter
            if drop.type == .contested {
                appState.player.gearDropState?.contestedDropsClaimed += 1
            }
        }

        // Persist equipment to inventory and handle equip decisions
        let loot = mapVM.gearDropLoot
        let decisions = mapVM.gearDropLootDecisions
        Task {
            let keptLoot = loot.filter { decisions[$0.id] != nil }
            if !keptLoot.isEmpty {
                await container.inventoryService.addEquipmentBatch(keptLoot)
            }

            // Equip items marked for equip
            for item in loot {
                if decisions[item.id] == .equip {
                    appState.player.equippedItems[item.slot] = item.id
                }
            }

            // Auto-save
            let currentInventory = await container.inventoryService.getInventory()
            let currentConsumables = await container.inventoryService.getConsumables()
            await appState.saveCurrentPlayer(
                using: container.persistenceService,
                inventory: currentInventory,
                consumables: currentConsumables
            )
        }

        showGearDropToast("Nice pickup! Kitchen-approved gear acquired.")
    }

    // MARK: - Bottom Bar

    private var hasActiveTrail: Bool {
        guard let trail = appState.player.gearDropState?.activeTrail else { return false }
        return !trail.isExpired
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            // Trail activation button
            if !hasActiveTrail {
                Button {
                    guard let coord = appState.locationOverride
                        ?? mapVM.locationManager.currentLocation?.coordinate else { return }
                    Task {
                        let route = await mapVM.startTrailRoute(
                            around: coord,
                            playerLevel: appState.player.progression.level
                        )
                        appState.player.gearDropState?.activeTrail = route
                        // Auto-save trail state
                        let inv = await container.inventoryService.getInventory()
                        let cons = await container.inventoryService.getConsumables()
                        await appState.saveCurrentPlayer(
                            using: container.persistenceService,
                            inventory: inv,
                            consumables: cons
                        )
                        showGearDropToast("Trail activated — time for a dink-and-dash!")
                    }
                } label: {
                    Label("Start Trail", systemImage: "figure.walk")
                        .font(.caption.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.green.opacity(0.85))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

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
        }
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
