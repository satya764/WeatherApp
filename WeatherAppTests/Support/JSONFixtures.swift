import Foundation

/// Payloads copied from the OpenWeather docs and trimmed. Kept in Swift instead of
/// bundle resources so there's no test-bundle file lookup to get wrong.
enum JSONFixtures {
    static let currentWeather = Data("""
    {
      "coord": { "lon": 10.99, "lat": 44.34 },
      "weather": [ { "id": 501, "main": "Rain", "description": "moderate rain", "icon": "10d" } ],
      "base": "stations",
      "main": {
        "temp": 25.33, "feels_like": 25.59, "temp_min": 24.41, "temp_max": 26.9,
        "pressure": 1015, "humidity": 64, "sea_level": 1015, "grnd_level": 933
      },
      "visibility": 10000,
      "wind": { "speed": 0.62, "deg": 349, "gust": 1.18 },
      "rain": { "1h": 3.16 },
      "clouds": { "all": 100 },
      "dt": 1661870592,
      "sys": { "type": 2, "id": 2075663, "country": "IT", "sunrise": 1661834187, "sunset": 1661882248 },
      "timezone": 7200,
      "id": 3163858,
      "name": "Zocca",
      "cod": 200
    }
    """.utf8)

    /// What some stations actually send: no rain, no visibility, no sunrise, empty name,
    /// decimal pressure.
    static let sparseWeather = Data("""
    {
      "coord": { "lon": -96.797, "lat": 32.7767 },
      "weather": [],
      "main": { "temp": 18.2, "pressure": 1013.6 },
      "dt": 1661870592,
      "name": ""
    }
    """.utf8)

    static let weatherMissingTemperature = Data("""
    { "coord": { "lon": 10.99, "lat": 44.34 }, "main": { "humidity": 64 }, "name": "Zocca" }
    """.utf8)

    static let weatherInvalidCoordinate = Data("""
    { "coord": { "lon": 400, "lat": 44.34 }, "main": { "temp": 20 }, "name": "Nowhere" }
    """.utf8)

    static let geocodingDallas = Data("""
    [
      { "name": "Dallas", "local_names": { "en": "Dallas" }, "lat": 32.7762719, "lon": -96.7968559, "country": "US", "state": "Texas" }
    ]
    """.utf8)

    static let geocodingNonUSFirst = Data("""
    [
      { "name": "Paris", "lat": 48.8588897, "lon": 2.3200410, "country": "FR", "state": "Ile-de-France" },
      { "name": "Paris", "lat": 33.6617962, "lon": -95.5555130, "country": "US", "state": "Texas" }
    ]
    """.utf8)

    static let geocodingEmpty = Data("[]".utf8)
}
