import SwiftUI
import MapKit

struct MapContentView: View {
    let mapVM: MapViewModel
    let matchVM: MatchViewModel
    @Environment(AppState.self) private var appState

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

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
                            Task { await mapVM.selectCourt(court) }
                        }
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
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
                cameraPosition = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))
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
                    isRated: Bindable(matchVM).isRated,
                    onChallenge: { npc in
                        mapVM.pendingChallenge = npc
                        mapVM.showCourtDetail = false
                    }
                )
            }
        }
        .onChange(of: mapVM.showCourtDetail) { _, isPresented in
            if !isPresented, let npc = mapVM.pendingChallenge {
                mapVM.pendingChallenge = nil
                Task {
                    await matchVM.startMatch(player: appState.player, opponent: npc)
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
