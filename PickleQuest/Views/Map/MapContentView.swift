import SwiftUI
import MapKit

struct MapContentView: View {
    let mapVM: MapViewModel
    let matchVM: MatchViewModel
    @Environment(AppState.self) private var appState

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var undiscoveredCourt: Court?

    var body: some View {
        @Bindable var mapState = mapVM

        ZStack {
            Map(position: $cameraPosition) {
                // Player location (dev override or real)
                if let override = appState.locationOverride {
                    Annotation("You", coordinate: override) {
                        PlayerAnnotationDot()
                    }
                } else {
                    UserAnnotation()
                }

                // Court annotations
                ForEach(mapVM.courts) { court in
                    let discovered = appState.isDevMode
                        || appState.player.discoveredCourtIDs.contains(court.id)
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
                            } else {
                                undiscoveredCourt = court
                            }
                        }
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                mapVM.updateStickyLocation(
                    center: context.camera.centerCoordinate,
                    appState: appState
                )
            }

            // Dev mode movement controls
            if appState.isDevMode {
                VStack {
                    Spacer()
                    HStack {
                        DevMovementPad(mapVM: mapVM, appState: appState)
                            .padding(.leading, 16)
                        Spacer()
                    }
                    .padding(.bottom, 72) // above the bottom bar
                }
            }

            // Bottom overlay: court count + energy
            VStack {
                Spacer()
                bottomBar
            }
        }
        .task {
            await setupMap()
        }
        .onChange(of: appState.locationOverride) { _, newOverride in
            if let coord = newOverride {
                // Only recenter camera when not in sticky mode (sticky mode = user is panning)
                if !mapVM.isStickyMode {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
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
                    playerRating: appState.player.duprRating,
                    ladder: mapVM.currentLadder,
                    courtPerk: mapVM.currentCourtPerk,
                    alphaNPC: mapVM.alphaNPC,
                    isRated: Bindable(matchVM).isRated,
                    onChallenge: { npc in
                        mapVM.pendingChallenge = npc
                        mapVM.showCourtDetail = false
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
        .onChange(of: mapVM.showCourtDetail) { _, isPresented in
            if !isPresented, let npc = mapVM.pendingChallenge {
                let courtNameForMatch = mapVM.selectedCourt?.name ?? ""
                mapVM.pendingChallenge = nil
                Task {
                    await matchVM.startMatch(player: appState.player, opponent: npc, courtName: courtNameForMatch)
                }
            }
        }
    }

    // MARK: - Setup

    private func setupMap() async {
        mapVM.requestLocationPermission()
        mapVM.startLocationUpdates()

        if let override = appState.locationOverride {
            cameraPosition = .region(MKCoordinateRegion(
                center: override,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
            await mapVM.generateCourtsIfNeeded(around: override)
            runDiscoveryCheck()
        } else {
            // Wait for real GPS
            for _ in 0..<100 { // up to 10 seconds
                if mapVM.locationManager.currentLocation != nil { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            if let loc = mapVM.locationManager.currentLocation {
                await mapVM.generateCourtsIfNeeded(around: loc.coordinate)
                runDiscoveryCheck()
            }
        }
    }

    private func runDiscoveryCheck() {
        guard let loc = mapVM.effectiveLocation(devOverride: appState.locationOverride) else { return }
        let newIDs = mapVM.checkDiscovery(
            playerLocation: loc,
            discoveredIDs: appState.player.discoveredCourtIDs,
            isDevMode: appState.isDevMode
        )
        for id in newIDs {
            appState.player.discoveredCourtIDs.insert(id)
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
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 36, height: 36)
                .background(Color(.systemGray5))
                .clipShape(Circle())
        }
    }
}
