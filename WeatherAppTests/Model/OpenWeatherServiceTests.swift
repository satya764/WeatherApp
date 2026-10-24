import XCTest
@testable import WeatherApp

final class OpenWeatherServiceTests: XCTestCase {
    private func makeSUT(
        apiKey: String? = "KEY",
        handler: @escaping MockHTTPClient.Handler
    ) -> (OpenWeatherService, MockHTTPClient) {
        let client = MockHTTPClient(handler: handler)
        let service = OpenWeatherService(client: client, apiKey: apiKey, languageCode: "en")
        return (service, client)
    }

    /// Routes by path so one handler can answer both the geocoder and weather calls.
    private static func route(geocoding: Data, weather: Data = JSONFixtures.currentWeather) -> MockHTTPClient.Handler {
        { request in
            let body = request.url?.path == "/geo/1.0/direct" ? geocoding : weather
            return (body, .ok(for: request))
        }
    }

    func test_citySearch_geocodesThenFetchesWeatherAtThatCoordinate() async throws {
        let (sut, client) = makeSUT(handler: Self.route(geocoding: JSONFixtures.geocodingDallas))

        let weather = try await sut.weather(for: CityQuery(city: "Dallas", stateCode: "TX"))

        XCTAssertEqual(client.requests.map { $0.url?.path }, ["/geo/1.0/direct", "/data/2.5/weather"])
        let weatherURL = try XCTUnwrap(client.requests.last?.url)
        let items = URLComponents(url: weatherURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first { $0.name == "lat" }?.value, "32.7762719")
        // Geocoder's place name wins over the weather response's "Zocca".
        XCTAssertEqual(weather.place, Place(name: "Dallas", state: "Texas", countryCode: "US"))
    }

    func test_citySearch_skipsNonUSMatches() async throws {
        let (sut, _) = makeSUT(handler: Self.route(geocoding: JSONFixtures.geocodingNonUSFirst))
        let weather = try await sut.weather(for: CityQuery(city: "Paris", stateCode: "TX"))
        XCTAssertEqual(weather.place.state, "Texas")
    }

    func test_citySearch_noMatches_isCityNotFound() async {
        let (sut, client) = makeSUT(handler: Self.route(geocoding: JSONFixtures.geocodingEmpty))
        await assertThrows(WeatherError.cityNotFound) {
            _ = try await sut.weather(for: CityQuery(city: "Atlantis"))
        }
        XCTAssertEqual(client.requests.count, 1, "no weather call when the city isn't found")
    }

    func test_missingAPIKey_failsWithoutNetwork() async {
        for key in [nil, ""] as [String?] {
            let (sut, client) = makeSUT(apiKey: key, handler: Self.route(geocoding: JSONFixtures.geocodingDallas))
            await assertThrows(WeatherError.missingAPIKey) {
                _ = try await sut.weather(at: .dallas)
            }
            XCTAssertTrue(client.requests.isEmpty)
        }
    }

    func test_httpStatusMapping() async {
        let cases: [(Int, WeatherError)] = [
            (401, .unauthorized),
            (400, .cityNotFound),
            (404, .cityNotFound),
            (429, .rateLimited),
            (503, .server(statusCode: 503)),
            (418, .unknown)
        ]
        for (status, expected) in cases {
            let (sut, _) = makeSUT { _ in throw NetworkError.httpStatus(status) }
            await assertThrows(expected, "status \(status)") {
                _ = try await sut.weather(at: .dallas)
            }
        }
    }

    func test_transportErrorMapping() async {
        let cases: [(URLError.Code, WeatherError)] = [
            (.notConnectedToInternet, .noConnection),
            (.networkConnectionLost, .noConnection),
            (.timedOut, .timeout),
            (.badServerResponse, .unknown)
        ]
        for (code, expected) in cases {
            let (sut, _) = makeSUT { _ in throw NetworkError.transport(code) }
            await assertThrows(expected, "code \(code.rawValue)") {
                _ = try await sut.weather(at: .dallas)
            }
        }
    }

    func test_malformedJSON_isDecodingError() async {
        let (sut, _) = makeSUT { request in (Data("{ nope".utf8), .ok(for: request)) }
        await assertThrows(WeatherError.decoding) {
            _ = try await sut.weather(at: .dallas)
        }
    }

    func test_cancellation_isNotTurnedIntoAnError() async {
        let (sut, _) = makeSUT { _ in throw CancellationError() }
        do {
            _ = try await sut.weather(at: .dallas)
            XCTFail("expected to throw")
        } catch {
            XCTAssertTrue(error is CancellationError, "got \(error)")
        }
    }

    // MARK: - Helpers

    private func assertThrows(
        _ expected: WeatherError,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("expected \(expected) \(message)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? WeatherError, expected, message, file: file, line: line)
        }
    }
}
