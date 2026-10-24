import Foundation

/// Build-time configuration. The API key comes from Config/Secrets.xcconfig through
/// Info.plist, so it never gets committed. An `OPENWEATHER_API_KEY` environment
/// variable on the scheme also works and wins if both are set.
struct AppConfiguration: Equatable {
    static let infoPlistKey = "OpenWeatherAPIKey"
    static let environmentKey = "OPENWEATHER_API_KEY"

    let openWeatherAPIKey: String?

    static func load(
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppConfiguration {
        let candidates = [environment[environmentKey], infoDictionary?[infoPlistKey] as? String]
        let key = candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { isUsable($0) }
        return AppConfiguration(openWeatherAPIKey: key)
    }

    /// Empty values and unexpanded build settings ("$(OPENWEATHER_API_KEY)") don't count.
    static func isUsable(_ value: String) -> Bool {
        !value.isEmpty && !value.hasPrefix("$(")
    }
}
