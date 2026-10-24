import Foundation
import os

protocol WeatherProviding: Sendable {
    func weather(for query: CityQuery) async throws -> Weather
    func weather(at coordinate: Coordinate) async throws -> Weather
}

/// Talks to OpenWeather and hands back domain models. Every error leaving this type
/// is a `WeatherError` or `CancellationError`.
struct OpenWeatherService: WeatherProviding {
    private let client: any HTTPClient
    private let apiKey: String?
    private let baseURL: URL
    private let languageCode: String

    private static let logger = Logger(subsystem: "WeatherApp", category: "OpenWeatherService")

    init(
        client: any HTTPClient,
        apiKey: String?,
        baseURL: URL = OpenWeatherAPI.baseURL,
        languageCode: String = OpenWeatherService.defaultLanguageCode
    ) {
        self.client = client
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.languageCode = languageCode
    }

    /// OpenWeather localizes condition text with `lang`. Unknown codes fall back to English on their side.
    static var defaultLanguageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    func weather(for query: CityQuery) async throws -> Weather {
        let matches: [GeocodingResultDTO] = try await send(OpenWeatherAPI.directGeocoding(for: query))

        // We already pass ",US" but the geocoder is fuzzy. Don't show Paris, FR for "Paris, TX".
        let usMatch = matches.first { ($0.country ?? "US").uppercased() == "US" }

        guard let match = usMatch, let coordinate = Coordinate(latitude: match.lat, longitude: match.lon) else {
            throw WeatherError.cityNotFound
        }

        let place = Place(name: match.name, state: match.state, countryCode: match.country)
        return try await fetchWeather(at: coordinate, place: place)
    }

    func weather(at coordinate: Coordinate) async throws -> Weather {
        try await fetchWeather(at: coordinate, place: nil)
    }

    // MARK: - Private

    private func fetchWeather(at coordinate: Coordinate, place: Place?) async throws -> Weather {
        let endpoint = OpenWeatherAPI.currentWeather(at: coordinate, languageCode: languageCode)
        let response: WeatherResponseDTO = try await send(endpoint)
        return try response.toDomain(placeOverride: place)
    }

    private func send<Response: Decodable>(_ endpoint: Endpoint) async throws -> Response {
        guard let apiKey, !apiKey.isEmpty else {
            throw WeatherError.missingAPIKey
        }

        do {
            let request = try RequestBuilder(baseURL: baseURL, apiKey: apiKey).makeRequest(for: endpoint)
            let (data, _) = try await client.data(for: request)
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            let mapped = Self.map(error)
            // Log the path only. The full URL has the API key in it.
            if !(mapped is CancellationError) {
                Self.logger.error("Request to \(endpoint.path, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            }
            throw mapped
        }
    }

    static func map(_ error: Error) -> Error {
        switch error {
        case is CancellationError:
            return error
        case let error as WeatherError:
            return error
        case is DecodingError:
            return WeatherError.decoding
        case let error as NetworkError:
            return mapNetworkError(error)
        default:
            return WeatherError.unknown
        }
    }

    private static func mapNetworkError(_ error: NetworkError) -> WeatherError {
        switch error {
        case .httpStatus(401):
            return .unauthorized
        case .httpStatus(400), .httpStatus(404):
            // The geocoder answers 400 for queries it can't make sense of; same thing as "not found" to a user.
            return .cityNotFound
        case .httpStatus(429):
            return .rateLimited
        case .httpStatus(let code) where code >= 500:
            return .server(statusCode: code)
        case .httpStatus:
            return .unknown
        case .transport(let code):
            switch code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .internationalRoamingOff, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return .noConnection
            case .timedOut:
                return .timeout
            default:
                return .unknown
            }
        case .invalidRequest, .invalidResponse:
            return .unknown
        }
    }
}
