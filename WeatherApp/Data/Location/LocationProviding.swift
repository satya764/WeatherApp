import Foundation

enum LocationAuthorization: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    /// Parental controls / MDM. The user can't change it, but the UI treats it like denied.
    case restricted
}

enum LocationError: Error, Equatable {
    case notAuthorized
    case unavailable
    case timedOut
}

/// Async wrapper around the device location. Main-actor bound because
/// CLLocationManager wants to live on the thread that created it.
@MainActor
protocol LocationProviding: AnyObject {
    var authorization: LocationAuthorization { get }

    /// Shows the system prompt if the user hasn't decided yet; otherwise returns right away.
    func requestAuthorization() async -> LocationAuthorization

    func currentCoordinate() async throws -> Coordinate
}
