import Foundation

/// Everything that can go wrong getting weather, in terms the UI cares about.
/// Lower layers (HTTP, CoreLocation, decoding) get translated into this so view
/// models never have to know about status codes or URLError.
enum WeatherError: Error, Equatable {
    case invalidQuery(CityQueryError)
    case cityNotFound
    case locationPermissionDenied
    case locationUnavailable
    case missingAPIKey
    case unauthorized
    case rateLimited
    case server(statusCode: Int)
    case noConnection
    case timeout
    case decoding
    case unknown
}

extension WeatherError {
    /// Best-effort mapping for errors that didn't come from our own layers.
    init(_ error: Error) {
        switch error {
        case let error as WeatherError:
            self = error
        case let error as LocationError:
            self = error == .notAuthorized ? .locationPermissionDenied : .locationUnavailable
        default:
            self = .unknown
        }
    }
}
