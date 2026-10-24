import Foundation

/// The details screen is read-only, so this is a value type that groups the
/// already-formatted metrics into sections.
struct WeatherDetailViewModel: Equatable {
    struct Section: Identifiable, Equatable {
        let id: String
        let title: String
        let metrics: [WeatherDisplayModel.Metric]
    }

    let display: WeatherDisplayModel
    let sections: [Section]

    var title: String { display.locationTitle }

    init(display: WeatherDisplayModel) {
        self.display = display

        typealias Kind = WeatherDisplayModel.Metric.Kind
        let groups: [(id: String, title: String, kinds: [Kind])] = [
            ("conditions", String(localized: "Conditions"), [.feelsLike, .humidity, .precipitation, .cloudiness, .visibility]),
            ("wind", String(localized: "Wind & Pressure"), [.wind, .pressure]),
            ("sun", String(localized: "Sun"), [.sunrise, .sunset])
        ]

        // Empty sections are dropped. A station with no sunrise data shouldn't leave a blank "Sun" header.
        sections = groups.compactMap { group in
            let metrics = group.kinds.compactMap { kind in display.metrics.first { $0.kind == kind } }
            return metrics.isEmpty ? nil : Section(id: group.id, title: group.title, metrics: metrics)
        }
    }
}
