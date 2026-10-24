import XCTest
@testable import WeatherApp

@MainActor
final class WeatherDisplayFormatterTests: XCTestCase {
    private let us = Locale(identifier: "en_US")
    private let metric = Locale(identifier: "en_DE")

    func test_temperature_usesLocaleUnits() {
        XCTAssertEqual(WeatherDisplayFormatter(locale: us).formatTemperature(25), "77°")
        XCTAssertEqual(WeatherDisplayFormatter(locale: metric).formatTemperature(25), "25°")
    }

    func test_temperature_neverShowsNegativeZero() {
        XCTAssertEqual(WeatherDisplayFormatter(locale: metric).formatTemperature(-0.3), "0°")
    }

    func test_displayModel_usUnits() {
        let model = WeatherDisplayFormatter(locale: us).makeDisplayModel(for: .fixture())

        XCTAssertEqual(model.locationTitle, "Dallas, Texas")
        XCTAssertEqual(model.temperature, "77°")
        XCTAssertEqual(model.conditionText, "Moderate rain")
        XCTAssertEqual(model.highLow, "H: 86°  L: 68°")
        XCTAssertEqual(model.iconURL?.absoluteString, "https://openweathermap.org/img/wn/10d@2x.png")

        let wind = value(.wind, in: model)
        XCTAssertTrue(wind?.contains("10") == true, wind ?? "nil")
        XCTAssertTrue(wind?.contains("mph") == true, wind ?? "nil")
        XCTAssertTrue(wind?.hasSuffix("NW") == true, wind ?? "nil")
        XCTAssertEqual(value(.humidity, in: model), "64%")
        XCTAssertTrue(value(.visibility, in: model)?.contains("mi") == true)
        XCTAssertTrue(value(.pressure, in: model)?.contains("inHg") == true)
    }

    func test_displayModel_metricUnits() {
        let model = WeatherDisplayFormatter(locale: metric).makeDisplayModel(for: .fixture())

        XCTAssertEqual(model.temperature, "25°")
        let wind = value(.wind, in: model)
        XCTAssertTrue(wind?.contains("16") == true, wind ?? "nil")
        XCTAssertTrue(wind?.contains("km/h") == true, wind ?? "nil")
        XCTAssertTrue(value(.visibility, in: model)?.contains("km") == true)
        XCTAssertTrue(value(.pressure, in: model)?.contains("hPa") == true)
    }

    func test_missingFields_areLeftOut() {
        let weather = Weather.fixture(feelsLike: nil, min: nil, humidity: nil, windSpeed: nil, sunrise: nil)
        let model = WeatherDisplayFormatter(locale: us).makeDisplayModel(for: weather)
        let kinds = Set(model.metrics.map(\.kind))

        XCTAssertNil(model.highLow, "need both high and low to show either")
        XCTAssertFalse(kinds.contains(.feelsLike))
        XCTAssertFalse(kinds.contains(.humidity))
        XCTAssertFalse(kinds.contains(.wind))
        XCTAssertFalse(kinds.contains(.sunrise))
        XCTAssertTrue(kinds.contains(.sunset))
    }

    func test_precipitation_onlyShownWhenPresent() {
        let formatter = WeatherDisplayFormatter(locale: metric)
        XCTAssertNil(value(.precipitation, in: formatter.makeDisplayModel(for: .fixture(precipitation: nil))))
        XCTAssertNotNil(value(.precipitation, in: formatter.makeDisplayModel(for: .fixture(precipitation: 3.2))))
    }

    func test_sunTimes_useTheCitysTimeZone() {
        let formatter = WeatherDisplayFormatter(locale: us)
        // Sunrise at 00:00 UTC. In a UTC+1 city that's 1:00.
        let utc = formatter.makeDisplayModel(for: .fixture(timezoneOffset: 0))
        let plusOne = formatter.makeDisplayModel(for: .fixture(timezoneOffset: 3600))

        XCTAssertTrue(value(.sunrise, in: utc)?.hasPrefix("12:00") == true, value(.sunrise, in: utc) ?? "nil")
        XCTAssertTrue(value(.sunrise, in: plusOne)?.hasPrefix("1:00") == true, value(.sunrise, in: plusOne) ?? "nil")
    }

    func test_locationTitle() {
        let formatter = WeatherDisplayFormatter(locale: us)
        XCTAssertEqual(formatter.locationTitle(for: Place(name: "Austin", state: "Texas", countryCode: "US")), "Austin, Texas")
        XCTAssertEqual(formatter.locationTitle(for: Place(name: "Austin", state: nil, countryCode: "US")), "Austin")
        XCTAssertEqual(formatter.locationTitle(for: Place(name: "Zocca", state: nil, countryCode: "IT")), "Zocca, IT")
        XCTAssertEqual(formatter.locationTitle(for: Place(name: "  ", state: nil, countryCode: nil)), "Current Location")
    }

    func test_compassDirection() {
        let cases: [(Int, String)] = [
            (0, "N"), (22, "N"), (23, "NE"), (90, "E"), (180, "S"),
            (225, "SW"), (315, "NW"), (359, "N"), (360, "N"), (-90, "W"), (720, "N")
        ]
        for (degrees, expected) in cases {
            XCTAssertEqual(WeatherDisplayFormatter.compassDirection(for: degrees), expected, "\(degrees)°")
        }
    }

    func test_accessibilitySummary_readsAsSentences() {
        let model = WeatherDisplayFormatter(locale: us).makeDisplayModel(for: .fixture())
        XCTAssertEqual(model.accessibilitySummary, "Dallas, Texas. 77°, Moderate rain. High 86°, low 68°")
    }

    func test_primaryMetrics_areTheSummarySubset() {
        let model = WeatherDisplayFormatter(locale: us).makeDisplayModel(for: .fixture(precipitation: 1))
        XCTAssertEqual(model.primaryMetrics.map(\.kind), [.feelsLike, .humidity, .wind, .precipitation])
    }

    private func value(_ kind: WeatherDisplayModel.Metric.Kind, in model: WeatherDisplayModel) -> String? {
        model.metrics.first { $0.kind == kind }?.value
    }
}

final class WeatherDetailViewModelTests: XCTestCase {
    @MainActor
    func test_groupsMetricsIntoSections() {
        let display = WeatherDisplayFormatter(locale: Locale(identifier: "en_US")).makeDisplayModel(for: .fixture(precipitation: 1))
        let sut = WeatherDetailViewModel(display: display)

        XCTAssertEqual(sut.title, "Dallas, Texas")
        XCTAssertEqual(sut.sections.map(\.id), ["conditions", "wind", "sun"])
        XCTAssertEqual(sut.sections[0].metrics.map(\.kind), [.feelsLike, .humidity, .precipitation, .cloudiness, .visibility])
        XCTAssertEqual(sut.sections[1].metrics.map(\.kind), [.wind, .pressure])
        XCTAssertEqual(sut.sections[2].metrics.map(\.kind), [.sunrise, .sunset])
    }

    @MainActor
    func test_dropsEmptySections() {
        let weather = Weather.fixture(windSpeed: nil, sunrise: nil, sunset: nil)
            .withoutPressure()
        let display = WeatherDisplayFormatter(locale: Locale(identifier: "en_US")).makeDisplayModel(for: weather)
        let sut = WeatherDetailViewModel(display: display)

        XCTAssertEqual(sut.sections.map(\.id), ["conditions"])
    }
}

private extension Weather {
    func withoutPressure() -> Weather {
        Weather(
            place: place, coordinate: coordinate, condition: condition,
            temperature: temperature, feelsLike: feelsLike,
            minTemperature: minTemperature, maxTemperature: maxTemperature,
            humidity: humidity, pressure: nil, windSpeed: windSpeed, windDirection: windDirection,
            cloudiness: cloudiness, visibility: visibility, precipitationLastHour: precipitationLastHour,
            sunrise: sunrise, sunset: sunset, timezoneOffset: timezoneOffset, observedAt: observedAt
        )
    }
}

final class UserFacingErrorTests: XCTestCase {
    func test_recoveryActions() {
        XCTAssertEqual(UserFacingError(.noConnection).recovery, .retry)
        XCTAssertEqual(UserFacingError(.timeout).recovery, .retry)
        XCTAssertEqual(UserFacingError(.server(statusCode: 500)).recovery, .retry)
        XCTAssertEqual(UserFacingError(.locationPermissionDenied).recovery, .openSettings)
        XCTAssertEqual(UserFacingError(.cityNotFound).recovery, .noAction)
        XCTAssertEqual(UserFacingError(.invalidQuery(.invalidCharacters)).recovery, .noAction)
        XCTAssertEqual(UserFacingError(.missingAPIKey).recovery, .noAction)
    }

    func test_unknownStateMessage_namesTheInput() {
        XCTAssertTrue(UserFacingError(.invalidQuery(.unknownState("ON"))).message.contains("ON"))
    }

    func test_everyErrorHasCopy() {
        let all: [WeatherError] = [
            .invalidQuery(.empty), .invalidQuery(.tooLong), .invalidQuery(.invalidCharacters),
            .invalidQuery(.tooManyComponents), .invalidQuery(.unknownState("X")),
            .cityNotFound, .locationPermissionDenied, .locationUnavailable, .missingAPIKey,
            .unauthorized, .rateLimited, .server(statusCode: 502), .noConnection, .timeout, .decoding, .unknown
        ]
        for error in all {
            let copy = UserFacingError(error)
            XCTAssertFalse(copy.title.isEmpty, "\(error)")
            XCTAssertFalse(copy.message.isEmpty, "\(error)")
        }
    }

    func test_weatherErrorFromLocationError() {
        XCTAssertEqual(WeatherError(LocationError.notAuthorized), .locationPermissionDenied)
        XCTAssertEqual(WeatherError(LocationError.timedOut), .locationUnavailable)
        XCTAssertEqual(WeatherError(URLError(.badURL)), .unknown)
    }
}
