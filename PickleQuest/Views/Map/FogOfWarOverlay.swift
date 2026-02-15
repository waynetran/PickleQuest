import SwiftUI
import MapKit

struct FogOfWarOverlay: View {
    let revealedCells: Set<FogCell>
    let proxy: MapProxy
    let region: MKCoordinateRegion

    var body: some View {
        GeometryReader { geometry in
            // Use global coordinates to compute the exact offset between the
            // Canvas coordinate space and the MapProxy coordinate space.
            // This is device/safe-area independent — no assumptions needed.
            let canvasOrigin = geometry.frame(in: .global).origin

            Canvas(rendersAsynchronously: false) { context, size in
                let refCoord = region.center
                let northCoord = CLLocationCoordinate2D(
                    latitude: refCoord.latitude + FogOfWar.degreesPerCell,
                    longitude: refCoord.longitude
                )
                // Convert via .global so we have an absolute reference
                guard let p1 = proxy.convert(refCoord, to: .global),
                      let p2 = proxy.convert(northCoord, to: .global) else { return }

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
                    layerContext.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .color(Color(white: 0.08, opacity: 0.7))
                    )

                    layerContext.blendMode = .destinationOut
                    for cell in revealedCells {
                        guard cell.row >= minRow && cell.row <= maxRow
                                && cell.col >= minCol && cell.col <= maxCol else { continue }
                        let coord = FogOfWar.coordinate(for: cell)
                        guard let globalPoint = proxy.convert(coord, to: .global) else { continue }
                        // Map global screen point → canvas point
                        let x = globalPoint.x - canvasOrigin.x
                        let y = globalPoint.y - canvasOrigin.y
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
