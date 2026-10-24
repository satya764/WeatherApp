import Foundation

struct Place: Hashable, Sendable {
    /// Can be empty: the weather endpoint returns "" for some coordinates (open water, etc.).
    let name: String
    let state: String?
    let countryCode: String?
}

/// Current conditions for one place.
///
/// Units are fixed and SI-ish on purpose: °C, m/s, meters, hPa, mm.
/// Converting to whatever the user's locale wants is the presentation layer's job.
struct Weather: Equatable, Sendable {
    struct Condition: Equatable, Sendable {
        let id: Int?
        /// Short group name, e.g. "Rain".
        let summary: String
        /// Longer text, e.g. "moderate rain". Comes back localized via the `lang` param.
        let detail: String
        let iconURL: URL?
    }

    let place: Place
    let coordinate: Coordinate
    let condition: Condition?

    let temperature: Double
    let feelsLike: Double?
    let minTemperature: Double?
    let maxTemperature: Double?

    /// Percent, 0-100.
    let humidity: Int?
    let pressure: Int?
    let windSpeed: Double?
    /// Meteorological degrees (where the wind comes from).
    let windDirection: Int?
    /// Percent, 0-100.
    let cloudiness: Int?
    let visibility: Int?
    let precipitationLastHour: Double?

    let sunrise: Date?
    let sunset: Date?
    /// Seconds from UTC for the searched location, not the device. Sunrise for
    /// Honolulu should read in Honolulu time even if you're in Dallas.
    let timezoneOffset: Int
    let observedAt: Date
}
