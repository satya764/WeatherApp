#if DEBUG
import UIKit

/// Deterministic dependencies for UI tests: no network, no real location prompt.
/// Debug builds only, so none of this ships.
///
/// Driven from WeatherAppUITests with:
/// - launch argument `-ui-testing`
/// - `UITEST_LAST_SEARCH` = a saved search to restore on launch, e.g. "Austin, TX"
/// - `UITEST_LOCATION` = "authorized" | "denied" (default "denied")
enum UITestingSupport {
    static let launchArgument = "-ui-testing"
    static let lastSearchKey = "UITEST_LAST_SEARCH"
    static let locationKey = "UITEST_LOCATION"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    @MainActor
    static func makeDependencies(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppDependencies {
        let store = InMemoryLastSearchStore()
        if let saved = environment[lastSearchKey], case .success(let query) = CityQuery.parse(saved) {
            store.save(query)
        }

        let authorization: LocationAuthorization = environment[locationKey] == "authorized" ? .authorized : .denied

        return AppDependencies(
            weatherService: StubWeatherService(),
            locationProvider: StubLocationProvider(authorization: authorization),
            lastSearchStore: store,
            imageLoader: StubImageLoader(),
            // Pinned so assertions on text don't depend on the simulator's region.
            formatter: WeatherDisplayFormatter(locale: Locale(identifier: "en_US"))
        )
    }
}

struct StubWeatherService: WeatherProviding {
    /// Typing this city returns "not found", so the error path can be tested.
    static let unknownCity = "Nowhere"

    func weather(for query: CityQuery) async throws -> Weather {
        // Long enough for the loading state to render, short enough to keep tests quick.
        try await Task.sleep(nanoseconds: 150_000_000)
        if query.city.caseInsensitiveCompare(Self.unknownCity) == .orderedSame {
            throw WeatherError.cityNotFound
        }
        return .stub(name: query.city.capitalized, state: query.stateCode.flatMap(USState.name(for:)))
    }

    func weather(at coordinate: Coordinate) async throws -> Weather {
        try await Task.sleep(nanoseconds: 150_000_000)
        return .stub(name: "Cupertino", state: "California")
    }
}

@MainActor
final class StubLocationProvider: LocationProviding {
    private(set) var authorization: LocationAuthorization

    init(authorization: LocationAuthorization) {
        self.authorization = authorization
    }

    func requestAuthorization() async -> LocationAuthorization {
        authorization
    }

    func currentCoordinate() async throws -> Coordinate {
        guard authorization == .authorized else { throw LocationError.notAuthorized }
        guard let coordinate = Coordinate(latitude: 37.3230, longitude: -122.0322) else {
            throw LocationError.unavailable
        }
        return coordinate
    }
}

struct StubImageLoader: ImageLoading {
    func image(for url: URL) async throws -> UIImage {
        guard let image = UIImage(systemName: "cloud.sun.fill") else {
            throw ImageLoadingError.invalidData
        }
        return image
    }
}

extension Weather {
    static func stub(name: String, state: String?) -> Weather {
        let now = Date()
        return Weather(
            place: Place(name: name, state: state, countryCode: "US"),
            // Known-valid literal, debug-only stub.
            coordinate: Coordinate(latitude: 30.2672, longitude: -97.7431)!,
            condition: Weather.Condition(
                id: 800,
                summary: "Clear",
                detail: "clear sky",
                iconURL: OpenWeatherAPI.iconURL(for: "01d")
            ),
            temperature: 25,
            feelsLike: 26,
            minTemperature: 21,
            maxTemperature: 28,
            humidity: 40,
            pressure: 1015,
            windSpeed: 4.5,
            windDirection: 180,
            cloudiness: 0,
            visibility: 10_000,
            precipitationLastHour: nil,
            sunrise: now.addingTimeInterval(-6 * 3600),
            sunset: now.addingTimeInterval(6 * 3600),
            timezoneOffset: -5 * 3600,
            observedAt: now
        )
    }
}
#endif
