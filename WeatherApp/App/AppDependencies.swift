import Foundation

/// Composition root. Everything the app needs is built here, once, and passed down
/// through initializers. Nothing below this reaches for a singleton.
///
/// Given more time I'd split this into small per-feature factories (or `Has...`
/// protocols) as the app grows; with one feature that would just be ceremony.
@MainActor
final class AppDependencies {
    let weatherService: any WeatherProviding
    let locationProvider: any LocationProviding
    let lastSearchStore: any LastSearchStoring
    let imageLoader: any ImageLoading
    let formatter: WeatherDisplayFormatter

    init(
        weatherService: any WeatherProviding,
        locationProvider: any LocationProviding,
        lastSearchStore: any LastSearchStoring,
        imageLoader: any ImageLoading,
        formatter: WeatherDisplayFormatter
    ) {
        self.weatherService = weatherService
        self.locationProvider = locationProvider
        self.lastSearchStore = lastSearchStore
        self.imageLoader = imageLoader
        self.formatter = formatter
    }

    static func live(configuration: AppConfiguration = .load()) -> AppDependencies {
        AppDependencies(
            weatherService: OpenWeatherService(
                client: URLSessionHTTPClient(session: .weatherAPI),
                apiKey: configuration.openWeatherAPIKey
            ),
            locationProvider: CoreLocationProvider(),
            lastSearchStore: UserDefaultsLastSearchStore(),
            imageLoader: CachedImageLoader(client: URLSessionHTTPClient(session: .images)),
            formatter: WeatherDisplayFormatter()
        )
    }

    static func forCurrentProcess() -> AppDependencies {
        #if DEBUG
        if UITestingSupport.isEnabled {
            return UITestingSupport.makeDependencies()
        }
        #endif
        return .live()
    }
}

enum AppEnvironment {
    /// Unit tests are hosted in the app, so the app launches under them. We don't
    /// want that launch asking for location or hitting the network.
    static var isRunningUnitTests: Bool {
        let isHostedTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #if DEBUG
        return isHostedTest && !UITestingSupport.isEnabled
        #else
        return isHostedTest
        #endif
    }
}
