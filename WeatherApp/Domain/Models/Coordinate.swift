import Foundation

/// Lat/lon pair used across the app. Deliberately not `CLLocationCoordinate2D`
/// so the domain and networking layers don't need to import CoreLocation.
struct Coordinate: Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    /// Fails for NaN/infinite values or anything outside the valid lat/lon range.
    /// Both the API and CoreLocation have handed back garbage before (e.g. 0,0 or NaN
    /// on a bad fix), so we never trust raw doubles.
    init?(latitude: Double, longitude: Double) {
        guard latitude.isFinite, longitude.isFinite,
              (-90.0...90.0).contains(latitude),
              (-180.0...180.0).contains(longitude) else {
            return nil
        }
        self.latitude = latitude
        self.longitude = longitude
    }
}
