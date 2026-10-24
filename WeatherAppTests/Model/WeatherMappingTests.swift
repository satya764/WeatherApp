import XCTest
@testable import WeatherApp

final class WeatherMappingTests: XCTestCase {
    private func decode(_ data: Data) throws -> WeatherResponseDTO {
        try JSONDecoder().decode(WeatherResponseDTO.self, from: data)
    }

    func test_fullPayload_mapsEveryField() throws {
        let weather = try decode(JSONFixtures.currentWeather).toDomain()

        XCTAssertEqual(weather.place, Place(name: "Zocca", state: nil, countryCode: "IT"))
        XCTAssertEqual(weather.coordinate, Coordinate(latitude: 44.34, longitude: 10.99))
        XCTAssertEqual(weather.condition?.summary, "Rain")
        XCTAssertEqual(weather.condition?.detail, "moderate rain")
        XCTAssertEqual(weather.condition?.iconURL?.absoluteString, "https://openweathermap.org/img/wn/10d@2x.png")
        XCTAssertEqual(weather.temperature, 25.33, accuracy: 0.001)
        XCTAssertEqual(weather.feelsLike ?? 0, 25.59, accuracy: 0.001)
        XCTAssertEqual(weather.minTemperature ?? 0, 24.41, accuracy: 0.001)
        XCTAssertEqual(weather.maxTemperature ?? 0, 26.9, accuracy: 0.001)
        XCTAssertEqual(weather.humidity, 64)
        XCTAssertEqual(weather.pressure, 1015)
        XCTAssertEqual(weather.windSpeed ?? 0, 0.62, accuracy: 0.001)
        XCTAssertEqual(weather.windDirection, 349)
        XCTAssertEqual(weather.cloudiness, 100)
        XCTAssertEqual(weather.visibility, 10_000)
        XCTAssertEqual(weather.precipitationLastHour ?? 0, 3.16, accuracy: 0.001)
        XCTAssertEqual(weather.sunrise, Date(timeIntervalSince1970: 1_661_834_187))
        XCTAssertEqual(weather.sunset, Date(timeIntervalSince1970: 1_661_882_248))
        XCTAssertEqual(weather.timezoneOffset, 7200)
        XCTAssertEqual(weather.observedAt, Date(timeIntervalSince1970: 1_661_870_592))
    }

    func test_sparsePayload_stillMaps() throws {
        let weather = try decode(JSONFixtures.sparseWeather).toDomain()

        XCTAssertEqual(weather.place.name, "")
        XCTAssertNil(weather.condition)
        XCTAssertEqual(weather.temperature, 18.2, accuracy: 0.001)
        XCTAssertEqual(weather.pressure, 1014, "decimal pressure should round, not fail decoding")
        XCTAssertNil(weather.humidity)
        XCTAssertNil(weather.visibility)
        XCTAssertNil(weather.precipitationLastHour)
        XCTAssertNil(weather.sunrise)
        XCTAssertEqual(weather.timezoneOffset, 0)
    }

    func test_placeOverride_winsOverResponseName() throws {
        let override = Place(name: "Dallas", state: "Texas", countryCode: "US")
        let weather = try decode(JSONFixtures.currentWeather).toDomain(placeOverride: override)
        XCTAssertEqual(weather.place, override)
    }

    func test_missingTemperature_isDecodingError() {
        // `main.temp` is required inside `main`, so this fails at decode time.
        XCTAssertThrowsError(try decode(JSONFixtures.weatherMissingTemperature))
    }

    func test_invalidCoordinate_throwsDecodingError() throws {
        let dto = try decode(JSONFixtures.weatherInvalidCoordinate)
        XCTAssertThrowsError(try dto.toDomain()) { error in
            XCTAssertEqual(error as? WeatherError, .decoding)
        }
    }

    func test_geocodingDecode() throws {
        let results = try JSONDecoder().decode([GeocodingResultDTO].self, from: JSONFixtures.geocodingDallas)
        XCTAssertEqual(results.first?.name, "Dallas")
        XCTAssertEqual(results.first?.state, "Texas")
        XCTAssertEqual(results.first?.country, "US")
    }
}

final class OpenWeatherAPITests: XCTestCase {
    func test_geocodingRequest_hasQueryAndKey() throws {
        let endpoint = OpenWeatherAPI.directGeocoding(for: CityQuery(city: "New York", stateCode: "NY"))
        let request = try RequestBuilder(baseURL: OpenWeatherAPI.baseURL, apiKey: "KEY").makeRequest(for: endpoint)
        let url = try XCTUnwrap(request.url)
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)

        XCTAssertEqual(url.host, "api.openweathermap.org")
        XCTAssertEqual(url.path, "/geo/1.0/direct")
        XCTAssertEqual(items.first { $0.name == "q" }?.value, "New York,NY,US")
        XCTAssertEqual(items.first { $0.name == "appid" }?.value, "KEY")
        XCTAssertTrue(url.absoluteString.contains("New%20York"), "spaces must be percent-encoded")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func test_weatherRequest_usesCoordinatesMetricAndLanguage() throws {
        let endpoint = OpenWeatherAPI.currentWeather(at: .dallas, languageCode: "es")
        let request = try RequestBuilder(baseURL: OpenWeatherAPI.baseURL, apiKey: "KEY").makeRequest(for: endpoint)
        let url = try XCTUnwrap(request.url)
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)

        XCTAssertEqual(url.path, "/data/2.5/weather")
        XCTAssertEqual(items.first { $0.name == "lat" }?.value, "32.7767")
        XCTAssertEqual(items.first { $0.name == "lon" }?.value, "-96.797")
        XCTAssertEqual(items.first { $0.name == "units" }?.value, "metric")
        XCTAssertEqual(items.first { $0.name == "lang" }?.value, "es")
    }

    func test_iconURL_validatesCode() {
        XCTAssertEqual(OpenWeatherAPI.iconURL(for: "01n")?.absoluteString, "https://openweathermap.org/img/wn/01n@2x.png")
        XCTAssertNil(OpenWeatherAPI.iconURL(for: ""))
        XCTAssertNil(OpenWeatherAPI.iconURL(for: "1d"))
        XCTAssertNil(OpenWeatherAPI.iconURL(for: "01x"))
        XCTAssertNil(OpenWeatherAPI.iconURL(for: "../../evil"))
    }
}
