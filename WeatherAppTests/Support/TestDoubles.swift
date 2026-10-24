import Foundation
import UIKit
@testable import WeatherApp

// MARK: - HTTP

final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    private let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { recorded.append(request) }
        return try await handler(request)
    }
}

extension HTTPURLResponse {
    static func ok(for request: URLRequest) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url ?? URL(fileURLWithPath: "/"), statusCode: 200, httpVersion: nil, headerFields: nil)!
    }
}

// MARK: - Weather service

final class MockWeatherService: WeatherProviding, @unchecked Sendable {
    typealias CityHandler = @Sendable (CityQuery) async throws -> Weather
    typealias CoordinateHandler = @Sendable (Coordinate) async throws -> Weather

    private let lock = NSLock()
    private var recordedCities: [CityQuery] = []
    private var recordedCoordinates: [Coordinate] = []

    // Set before the code under test runs; not mutated concurrently.
    var cityHandler: CityHandler = { query in .fixture(name: query.city) }
    var coordinateHandler: CoordinateHandler = { _ in .fixture(name: "Here", state: nil) }

    var cityRequests: [CityQuery] { lock.withLock { recordedCities } }
    var coordinateRequests: [Coordinate] { lock.withLock { recordedCoordinates } }

    func weather(for query: CityQuery) async throws -> Weather {
        lock.withLock { recordedCities.append(query) }
        return try await cityHandler(query)
    }

    func weather(at coordinate: Coordinate) async throws -> Weather {
        lock.withLock { recordedCoordinates.append(coordinate) }
        return try await coordinateHandler(coordinate)
    }
}

// MARK: - Location

@MainActor
final class MockLocationProvider: LocationProviding {
    var authorization: LocationAuthorization
    var authorizationAfterRequest: LocationAuthorization
    var coordinateResult: Result<Coordinate, Error>
    /// Runs while the "system prompt" is up, so tests can act in that window.
    var onRequestAuthorization: (() -> Void)?
    private(set) var requestCount = 0

    init(
        authorization: LocationAuthorization = .denied,
        authorizationAfterRequest: LocationAuthorization = .denied,
        coordinateResult: Result<Coordinate, Error> = .success(.dallas)
    ) {
        self.authorization = authorization
        self.authorizationAfterRequest = authorizationAfterRequest
        self.coordinateResult = coordinateResult
    }

    func requestAuthorization() async -> LocationAuthorization {
        requestCount += 1
        onRequestAuthorization?()
        authorization = authorizationAfterRequest
        return authorization
    }

    func currentCoordinate() async throws -> Coordinate {
        try coordinateResult.get()
    }
}

// MARK: - Fixtures

extension Coordinate {
    static let dallas = Coordinate(latitude: 32.7767, longitude: -96.7970)!
}

extension Weather {
    static func fixture(
        name: String = "Dallas",
        state: String? = "Texas",
        country: String? = "US",
        temperature: Double = 25,
        feelsLike: Double? = 26,
        min: Double? = 20,
        max: Double? = 30,
        humidity: Int? = 64,
        pressure: Int? = 1015,
        windSpeed: Double? = 4.47,
        windDirection: Int? = 315,
        cloudiness: Int? = 40,
        visibility: Int? = 10_000,
        precipitation: Double? = nil,
        sunrise: Date? = Date(timeIntervalSince1970: 0),
        sunset: Date? = Date(timeIntervalSince1970: 43_200),
        timezoneOffset: Int = 0,
        iconCode: String = "10d"
    ) -> Weather {
        Weather(
            place: Place(name: name, state: state, countryCode: country),
            coordinate: .dallas,
            condition: Weather.Condition(id: 501, summary: "Rain", detail: "moderate rain", iconURL: OpenWeatherAPI.iconURL(for: iconCode)),
            temperature: temperature,
            feelsLike: feelsLike,
            minTemperature: min,
            maxTemperature: max,
            humidity: humidity,
            pressure: pressure,
            windSpeed: windSpeed,
            windDirection: windDirection,
            cloudiness: cloudiness,
            visibility: visibility,
            precipitationLastHour: precipitation,
            sunrise: sunrise,
            sunset: sunset,
            timezoneOffset: timezoneOffset,
            observedAt: Date(timeIntervalSince1970: 1_661_870_592)
        )
    }
}

enum TestImages {
    static func png() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }
}

extension WeatherSearchViewModel.State {
    var displayModel: WeatherDisplayModel? {
        if case .loaded(let model) = self { return model }
        return nil
    }

    var error: UserFacingError? {
        if case .failed(let error) = self { return error }
        return nil
    }
}
