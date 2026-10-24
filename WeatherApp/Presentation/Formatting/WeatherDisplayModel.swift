import Foundation

/// Everything the weather screens show, already formatted. Views only lay this out;
/// they don't format numbers or make decisions.
struct WeatherDisplayModel: Equatable {
    struct Metric: Identifiable, Equatable {
        enum Kind: String, CaseIterable {
            case feelsLike
            case humidity
            case wind
            case precipitation
            case cloudiness
            case pressure
            case visibility
            case sunrise
            case sunset

            /// Shown on the main screen. The rest live on the details screen.
            var isPrimary: Bool {
                switch self {
                case .feelsLike, .humidity, .wind, .precipitation:
                    return true
                case .cloudiness, .pressure, .visibility, .sunrise, .sunset:
                    return false
                }
            }
        }

        let kind: Kind
        let title: String
        let value: String
        let systemImage: String

        var id: Kind { kind }
    }

    let locationTitle: String
    let temperature: String
    let conditionText: String
    let highLow: String?
    let iconURL: URL?
    let metrics: [Metric]
    let updatedText: String
    /// One sentence for VoiceOver, so the header reads naturally instead of as five fragments.
    let accessibilitySummary: String

    var primaryMetrics: [Metric] {
        metrics.filter { $0.kind.isPrimary }
    }
}
