import Foundation

/// Wire format for /data/2.5/weather.
///
/// Nearly everything is optional. The API leaves fields out depending on the station
/// (no `rain` when it's dry, no `visibility` sometimes, no `sys.sunrise` in polar
/// regions), and one missing field shouldn't fail the whole screen. Only coordinates
/// and temperature are treated as required, in `toDomain`.
///
/// Numeric fields documented as integers are decoded as Double and converted
/// defensively; the API has returned `1013.5` for pressure on some stations.
struct WeatherResponseDTO: Decodable {
    struct Coord: Decodable {
        let lat: Double
        let lon: Double
    }

    struct Condition: Decodable {
        let id: Int?
        let main: String?
        let description: String?
        let icon: String?
    }

    struct Main: Decodable {
        let temp: Double
        let feelsLike: Double?
        let tempMin: Double?
        let tempMax: Double?
        let pressure: Double?
        let humidity: Double?

        enum CodingKeys: String, CodingKey {
            case temp, pressure, humidity
            case feelsLike = "feels_like"
            case tempMin = "temp_min"
            case tempMax = "temp_max"
        }
    }

    struct Wind: Decodable {
        let speed: Double?
        let deg: Double?
    }

    struct Clouds: Decodable {
        let all: Double?
    }

    struct Precipitation: Decodable {
        let oneHour: Double?

        enum CodingKeys: String, CodingKey {
            case oneHour = "1h"
        }
    }

    struct Sys: Decodable {
        let country: String?
        let sunrise: TimeInterval?
        let sunset: TimeInterval?
    }

    let coord: Coord?
    let weather: [Condition]?
    let main: Main?
    let visibility: Double?
    let wind: Wind?
    let clouds: Clouds?
    let rain: Precipitation?
    let snow: Precipitation?
    let dt: TimeInterval?
    let sys: Sys?
    let timezone: Int?
    let name: String?
}

extension WeatherResponseDTO {
    /// - Parameter placeOverride: the geocoder's place when we have it. It's more
    ///   reliable than `name` here, which is sometimes a neighborhood or station.
    func toDomain(placeOverride: Place? = nil) throws -> Weather {
        guard let coord,
              let coordinate = Coordinate(latitude: coord.lat, longitude: coord.lon),
              let main,
              main.temp.isFinite else {
            throw WeatherError.decoding
        }

        let place = placeOverride ?? Place(
            name: name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            state: nil,
            countryCode: sys?.country
        )

        let condition = weather?.first.map { dto in
            Weather.Condition(
                id: dto.id,
                summary: dto.main ?? "",
                detail: dto.description ?? dto.main ?? "",
                iconURL: dto.icon.flatMap(OpenWeatherAPI.iconURL(for:))
            )
        }

        return Weather(
            place: place,
            coordinate: coordinate,
            condition: condition,
            temperature: main.temp,
            feelsLike: main.feelsLike.finite,
            minTemperature: main.tempMin.finite,
            maxTemperature: main.tempMax.finite,
            humidity: main.humidity.roundedInt.map { min(max($0, 0), 100) },
            pressure: main.pressure.roundedInt,
            windSpeed: wind?.speed.finite.map { max($0, 0) },
            windDirection: wind?.deg.roundedInt,
            cloudiness: clouds?.all.roundedInt.map { min(max($0, 0), 100) },
            visibility: visibility.roundedInt,
            // Rain and snow are separate keys; for "how much fell" either one counts.
            precipitationLastHour: rain?.oneHour.finite ?? snow?.oneHour.finite,
            sunrise: sys?.sunrise.map(Date.init(timeIntervalSince1970:)),
            sunset: sys?.sunset.map(Date.init(timeIntervalSince1970:)),
            timezoneOffset: timezone ?? 0,
            observedAt: dt.map(Date.init(timeIntervalSince1970:)) ?? Date()
        )
    }
}

private extension Optional where Wrapped == Double {
    var finite: Double? {
        guard let value = self, value.isFinite else { return nil }
        return value
    }

    /// `Int(_:)` traps on huge or non-finite values; `Int(exactly:)` doesn't.
    var roundedInt: Int? {
        guard let value = finite else { return nil }
        return Int(exactly: value.rounded())
    }
}
