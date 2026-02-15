import SwiftUI
import MapKit

struct FogOfWarOverlay: View {
    let revealedCells: Set<FogCell>
    let proxy: MapProxy
    let region: MKCoordinateRegion

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            // Compute screen scale: how many pixels per grid cell at current zoom
            let refCoord = region.center
            let northCoord = CLLocationCoordinate2D(
                latitude: refCoord.latitude + FogOfWar.degreesPerCell,
                longitude: refCoord.longitude
            )
            guard let p1 = proxy.convert(refCoord, to: .local),
                  let p2 = proxy.convert(northCoord, to: .local) else { return }

            let pixelsPerCell = abs(p1.y - p2.y)
            // Skip rendering if cells are sub-pixel (extremely zoomed out)
            guard pixelsPerCell >= 0.5 else { return }

            // Slightly larger radius for overlap between adjacent cells
            let circleRadius = pixelsPerCell * 1.15

            // Determine visible cell bounds from the region
            let minLat = region.center.latitude - region.span.latitudeDelta / 2
            let maxLat = region.center.latitude + region.span.latitudeDelta / 2
            let minLng = region.center.longitude - region.span.longitudeDelta / 2
            let maxLng = region.center.longitude + region.span.longitudeDelta / 2
            let minRow = Int(floor(minLat / FogOfWar.degreesPerCell)) - 1
            let maxRow = Int(ceil(maxLat / FogOfWar.degreesPerCell)) + 1
            let minCol = Int(floor(minLng / FogOfWar.degreesPerCell)) - 1
            let maxCol = Int(ceil(maxLng / FogOfWar.degreesPerCell)) + 1

            // Build path: full-screen fog with even-odd holes for revealed cells
            var path = Path()
            path.addRect(CGRect(origin: .zero, size: size))

            for cell in revealedCells {
                guard cell.row >= minRow && cell.row <= maxRow
                        && cell.col >= minCol && cell.col <= maxCol else { continue }
                let coord = FogOfWar.coordinate(for: cell)
                guard let screenPoint = proxy.convert(coord, to: .local) else { continue }
                path.addEllipse(in: CGRect(
                    x: screenPoint.x - circleRadius,
                    y: screenPoint.y - circleRadius,
                    width: circleRadius * 2,
                    height: circleRadius * 2
                ))
            }

            context.fill(
                path,
                with: .color(Color(white: 0.12, opacity: 0.65)),
                style: FillStyle(eoFill: true)
            )
        }
        .allowsHitTesting(false)
    }
}
