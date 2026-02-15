import SwiftUI
import MapKit

struct FogOfWarOverlay: View {
    let revealedCells: Set<FogCell>
    let proxy: MapProxy
    let region: MKCoordinateRegion

    var body: some View {
        // GeometryReader captures safe area insets so we can correct the coordinate
        // mismatch between proxy.convert (MapReader space) and the Canvas (which
        // extends into the safe area via .ignoresSafeArea()).
        GeometryReader { geometry in
            let insets = geometry.safeAreaInsets

            Canvas(rendersAsynchronously: false) { context, size in
                // proxy.convert returns points in the MapReader's coordinate space.
                // The Canvas extends into the safe area, shifting its origin upward
                // by insets.top and leftward by insets.leading. Offset all proxy
                // points to align with Canvas coordinates.
                let offsetX = insets.leading
                let offsetY = insets.top

                let refCoord = region.center
                let northCoord = CLLocationCoordinate2D(
                    latitude: refCoord.latitude + FogOfWar.degreesPerCell,
                    longitude: refCoord.longitude
                )
                guard let p1 = proxy.convert(refCoord, to: .local),
                      let p2 = proxy.convert(northCoord, to: .local) else { return }

                let pixelsPerCell = abs(p1.y - p2.y)
                guard pixelsPerCell >= 0.5 else { return }

                let circleRadius = pixelsPerCell * 1.2

                let minLat = region.center.latitude - region.span.latitudeDelta / 2
                let maxLat = region.center.latitude + region.span.latitudeDelta / 2
                let minLng = region.center.longitude - region.span.longitudeDelta / 2
                let maxLng = region.center.longitude + region.span.longitudeDelta / 2
                let minRow = Int(floor(minLat / FogOfWar.degreesPerCell)) - 1
                let maxRow = Int(ceil(maxLat / FogOfWar.degreesPerCell)) + 1
                let minCol = Int(floor(minLng / FogOfWar.degreesPerCell)) - 1
                let maxCol = Int(ceil(maxLng / FogOfWar.degreesPerCell)) + 1

                context.drawLayer { layerContext in
                    // Canvas covers full screen — no hardcoded overflow needed
                    layerContext.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .color(Color(white: 0.08, opacity: 0.7))
                    )

                    layerContext.blendMode = .destinationOut
                    for cell in revealedCells {
                        guard cell.row >= minRow && cell.row <= maxRow
                                && cell.col >= minCol && cell.col <= maxCol else { continue }
                        let coord = FogOfWar.coordinate(for: cell)
                        guard let screenPoint = proxy.convert(coord, to: .local) else { continue }
                        let x = screenPoint.x + offsetX
                        let y = screenPoint.y + offsetY
                        layerContext.fill(
                            Path(ellipseIn: CGRect(
                                x: x - circleRadius,
                                y: y - circleRadius,
                                width: circleRadius * 2,
                                height: circleRadius * 2
                            )),
                            with: .color(.white)
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
