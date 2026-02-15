import Foundation
import CoreLocation

struct FogCell: Hashable, Codable, Sendable {
    let row: Int
    let col: Int
}

enum FogOfWar {
    /// Each grid cell is ~20m x 20m
    static let cellSizeMeters: Double = 20.0
    /// Reveal radius around the player in meters
    static let revealRadiusMeters: Double = 20.0
    /// Degrees latitude per cell (~20m)
    static let degreesPerCell: Double = 20.0 / 111_000.0

    /// Convert a coordinate to its grid cell
    static func cell(for coordinate: CLLocationCoordinate2D) -> FogCell {
        FogCell(
            row: Int(floor(coordinate.latitude / degreesPerCell)),
            col: Int(floor(coordinate.longitude / degreesPerCell))
        )
    }

    /// Get the center coordinate of a grid cell
    static func coordinate(for cell: FogCell) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (Double(cell.row) + 0.5) * degreesPerCell,
            longitude: (Double(cell.col) + 0.5) * degreesPerCell
        )
    }

    /// Compute which cells should be revealed around a coordinate
    static func cellsToReveal(around coordinate: CLLocationCoordinate2D) -> Set<FogCell> {
        let centerCell = cell(for: coordinate)
        let cellRadius = Int(ceil(revealRadiusMeters / cellSizeMeters))
        var cells = Set<FogCell>()

        let centerLat = coordinate.latitude
        let centerLng = coordinate.longitude

        for dRow in -cellRadius...cellRadius {
            for dCol in -cellRadius...cellRadius {
                let candidate = FogCell(row: centerCell.row + dRow, col: centerCell.col + dCol)
                let candidateCoord = Self.coordinate(for: candidate)
                let distMeters = Self.distanceMeters(
                    lat1: centerLat, lng1: centerLng,
                    lat2: candidateCoord.latitude, lng2: candidateCoord.longitude
                )
                if distMeters <= revealRadiusMeters {
                    cells.insert(candidate)
                }
            }
        }
        return cells
    }

    /// Fast approximate distance in meters between two coordinates
    private static func distanceMeters(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let dLat = (lat2 - lat1) * 111_000.0
        let dLng = (lng2 - lng1) * 111_000.0 * cos(lat1 * .pi / 180)
        return (dLat * dLat + dLng * dLng).squareRoot()
    }
}
