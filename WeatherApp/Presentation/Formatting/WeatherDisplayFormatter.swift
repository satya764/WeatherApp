import Foundation

/// Turns a `Weather` into display strings for a given locale.
///
/// Owns its formatters because DateFormatter and MeasurementFormatter are expensive to
/// create and this runs on every load. It mutates `cityTimeFormatter.timeZone` per call,
/// which is why it's pinned to the main actor instead of being shared freely.
@MainActor
final class WeatherDisplayFormatter {
    private let usesUSUnits: Bool
    private let temperatureFormatter: MeasurementFormatter
    private let windFormatter: MeasurementFormatter
    private let distanceFormatter: MeasurementFormatter
    private let pressureFormatter: MeasurementFormatter
    private let precipitationFormatter: MeasurementFormatter
    private let percentFormatter: NumberFormatter
    private let cityTimeFormatter: DateFormatter
    private let deviceTimeFormatter: DateFormatter

    init(locale: Locale = .autoupdatingCurrent) {
        // Simplification: only the US gets imperial units. The UK mixes systems (°C but mph);
        // we show it metric. A units setting would be the real fix.
        let usesUSUnits = locale.measurementSystem == .us
        self.usesUSUnits = usesUSUnits

        let temperatureFormatter = WeatherDisplayFormatter.makeMeasurementFormatter(locale: locale, fractionDigits: 0)
        temperatureFormatter.unitOptions = [.providedUnit, .temperatureWithoutUnit]
        temperatureFormatter.unitStyle = .short
        self.temperatureFormatter = temperatureFormatter

        windFormatter = WeatherDisplayFormatter.makeMeasurementFormatter(locale: locale, fractionDigits: 0)
        distanceFormatter = WeatherDisplayFormatter.makeMeasurementFormatter(locale: locale, fractionDigits: 1)
        pressureFormatter = WeatherDisplayFormatter.makeMeasurementFormatter(locale: locale, fractionDigits: usesUSUnits ? 2 : 0)
        precipitationFormatter = WeatherDisplayFormatter.makeMeasurementFormatter(locale: locale, fractionDigits: usesUSUnits ? 2 : 1)

        let percentFormatter = NumberFormatter()
        percentFormatter.locale = locale
        percentFormatter.numberStyle = .percent
        percentFormatter.maximumFractionDigits = 0
        self.percentFormatter = percentFormatter

        cityTimeFormatter = WeatherDisplayFormatter.makeTimeFormatter(locale: locale)
        deviceTimeFormatter = WeatherDisplayFormatter.makeTimeFormatter(locale: locale)
    }

    func makeDisplayModel(for weather: Weather) -> WeatherDisplayModel {
        let title = locationTitle(for: weather.place)
        let temperature = formatTemperature(weather.temperature)
        let condition = conditionText(for: weather.condition)

        var highLow: String?
        var spokenHighLow: String?
        if let high = weather.maxTemperature, let low = weather.minTemperature {
            let highText = formatTemperature(high)
            let lowText = formatTemperature(low)
            highLow = String(localized: "H: \(highText)  L: \(lowText)")
            spokenHighLow = String(localized: "High \(highText), low \(lowText)")
        }

        let summary = [title, "\(temperature), \(condition)", spokenHighLow]
            .compactMap { $0 }
            .joined(separator: ". ")

        return WeatherDisplayModel(
            locationTitle: title,
            temperature: temperature,
            conditionText: condition,
            highLow: highLow,
            iconURL: weather.condition?.iconURL,
            metrics: metrics(for: weather),
            updatedText: String(localized: "Updated \(deviceTimeFormatter.string(from: weather.observedAt))"),
            accessibilitySummary: summary
        )
    }

    // MARK: - Pieces

    func locationTitle(for place: Place) -> String {
        let name = place.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return String(localized: "Current Location")
        }
        if let state = place.state, !state.isEmpty {
            return "\(name), \(state)"
        }
        // Current location can land outside the US (travel, VPN'd simulator); show the country then.
        if let country = place.countryCode, !country.isEmpty, country.uppercased() != "US" {
            return "\(name), \(country)"
        }
        return name
    }

    func formatTemperature(_ celsius: Double) -> String {
        let unit: UnitTemperature = usesUSUnits ? .fahrenheit : .celsius
        let converted = Measurement(value: celsius, unit: UnitTemperature.celsius).converted(to: unit)
        // Round ourselves so -0.3° shows as "0°", not "-0°".
        var rounded = converted.value.rounded()
        if rounded == 0 { rounded = 0 }
        return temperatureFormatter.string(from: Measurement(value: rounded, unit: unit))
    }

    nonisolated static func compassDirection(for degrees: Int) -> String {
        let directions = [
            String(localized: "N", comment: "Compass direction: north"),
            String(localized: "NE", comment: "Compass direction: northeast"),
            String(localized: "E", comment: "Compass direction: east"),
            String(localized: "SE", comment: "Compass direction: southeast"),
            String(localized: "S", comment: "Compass direction: south"),
            String(localized: "SW", comment: "Compass direction: southwest"),
            String(localized: "W", comment: "Compass direction: west"),
            String(localized: "NW", comment: "Compass direction: northwest")
        ]
        let normalized = ((degrees % 360) + 360) % 360
        let index = Int((Double(normalized) / 45).rounded()) % directions.count
        return directions[index]
    }

    // MARK: - Private

    private func conditionText(for condition: Weather.Condition?) -> String {
        guard let condition else {
            return String(localized: "Conditions unavailable")
        }
        let text = condition.detail.isEmpty ? condition.summary : condition.detail
        guard let first = text.first else {
            return String(localized: "Conditions unavailable")
        }
        // The API sends "light rain"; sentence case reads better than Title Case.
        return first.uppercased() + text.dropFirst()
    }

    private func metrics(for weather: Weather) -> [WeatherDisplayModel.Metric] {
        typealias Metric = WeatherDisplayModel.Metric
        var metrics: [Metric] = []

        if let feelsLike = weather.feelsLike {
            metrics.append(Metric(kind: .feelsLike, title: String(localized: "Feels Like"),
                                  value: formatTemperature(feelsLike), systemImage: "thermometer.medium"))
        }
        if let humidity = weather.humidity {
            metrics.append(Metric(kind: .humidity, title: String(localized: "Humidity"),
                                  value: formatPercent(humidity), systemImage: "humidity"))
        }
        if let speed = weather.windSpeed {
            metrics.append(Metric(kind: .wind, title: String(localized: "Wind"),
                                  value: formatWind(speed: speed, degrees: weather.windDirection), systemImage: "wind"))
        }
        if let precipitation = weather.precipitationLastHour {
            metrics.append(Metric(kind: .precipitation, title: String(localized: "Precipitation (1h)"),
                                  value: formatPrecipitation(precipitation), systemImage: "cloud.rain"))
        }
        if let cloudiness = weather.cloudiness {
            metrics.append(Metric(kind: .cloudiness, title: String(localized: "Cloud Cover"),
                                  value: formatPercent(cloudiness), systemImage: "cloud"))
        }
        if let pressure = weather.pressure {
            metrics.append(Metric(kind: .pressure, title: String(localized: "Pressure"),
                                  value: formatPressure(pressure), systemImage: "gauge.medium"))
        }
        if let visibility = weather.visibility {
            metrics.append(Metric(kind: .visibility, title: String(localized: "Visibility"),
                                  value: formatDistance(meters: visibility), systemImage: "eye"))
        }
        if let sunrise = weather.sunrise {
            metrics.append(Metric(kind: .sunrise, title: String(localized: "Sunrise"),
                                  value: formatCityTime(sunrise, offset: weather.timezoneOffset), systemImage: "sunrise"))
        }
        if let sunset = weather.sunset {
            metrics.append(Metric(kind: .sunset, title: String(localized: "Sunset"),
                                  value: formatCityTime(sunset, offset: weather.timezoneOffset), systemImage: "sunset"))
        }
        return metrics
    }

    private func formatPercent(_ value: Int) -> String {
        let clamped = min(max(value, 0), 100)
        return percentFormatter.string(from: NSNumber(value: Double(clamped) / 100)) ?? "\(clamped)%"
    }

    private func formatWind(speed: Double, degrees: Int?) -> String {
        let unit: UnitSpeed = usesUSUnits ? .milesPerHour : .kilometersPerHour
        let measurement = Measurement(value: max(speed, 0), unit: UnitSpeed.metersPerSecond).converted(to: unit)
        let speedText = windFormatter.string(from: measurement)
        guard let degrees else { return speedText }
        return "\(speedText) \(Self.compassDirection(for: degrees))"
    }

    private func formatDistance(meters: Int) -> String {
        let unit: UnitLength = usesUSUnits ? .miles : .kilometers
        let measurement = Measurement(value: Double(max(meters, 0)), unit: UnitLength.meters).converted(to: unit)
        return distanceFormatter.string(from: measurement)
    }

    private func formatPressure(_ hectopascals: Int) -> String {
        let unit: UnitPressure = usesUSUnits ? .inchesOfMercury : .hectopascals
        let measurement = Measurement(value: Double(hectopascals), unit: UnitPressure.hectopascals).converted(to: unit)
        return pressureFormatter.string(from: measurement)
    }

    private func formatPrecipitation(_ millimeters: Double) -> String {
        let unit: UnitLength = usesUSUnits ? .inches : .millimeters
        let measurement = Measurement(value: max(millimeters, 0), unit: UnitLength.millimeters).converted(to: unit)
        return precipitationFormatter.string(from: measurement)
    }

    /// Sunrise/sunset in the searched city's time, not the device's.
    private func formatCityTime(_ date: Date, offset: Int) -> String {
        cityTimeFormatter.timeZone = TimeZone(secondsFromGMT: offset) ?? .current
        return cityTimeFormatter.string(from: date)
    }

    private static func makeMeasurementFormatter(locale: Locale, fractionDigits: Int) -> MeasurementFormatter {
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .medium
        formatter.numberFormatter.locale = locale
        formatter.numberFormatter.minimumFractionDigits = 0
        formatter.numberFormatter.maximumFractionDigits = fractionDigits
        return formatter
    }

    private static func makeTimeFormatter(locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }
}
