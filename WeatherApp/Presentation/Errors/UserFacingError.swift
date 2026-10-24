import Foundation

/// What the user actually sees when something fails: a short title, a message that
/// says what to do next, and which button (if any) makes sense.
struct UserFacingError: Equatable {
    enum Recovery: Equatable {
        case retry
        case openSettings
        case noAction
    }

    let title: String
    let message: String
    let recovery: Recovery

    init(title: String, message: String, recovery: Recovery) {
        self.title = title
        self.message = message
        self.recovery = recovery
    }

    init(_ error: WeatherError) {
        switch error {
        case .invalidQuery(let reason):
            self.init(title: String(localized: "Check Your Search"), message: Self.message(for: reason), recovery: .noAction)
        case .cityNotFound:
            self.init(
                title: String(localized: "City Not Found"),
                message: String(localized: "We couldn't find that city in the US. Check the spelling or add a state, like “Portland, OR”."),
                recovery: .noAction
            )
        case .locationPermissionDenied:
            self.init(
                title: String(localized: "Location Access Is Off"),
                message: String(localized: "Turn on location access in Settings, or search for a city instead."),
                recovery: .openSettings
            )
        case .locationUnavailable:
            self.init(
                title: String(localized: "Couldn't Find Your Location"),
                message: String(localized: "Make sure Location Services are on and try again, or search for a city."),
                recovery: .retry
            )
        case .missingAPIKey:
            // Only a developer can hit this. Keep it specific so setup problems are obvious.
            self.init(
                title: String(localized: "Weather Service Not Set Up"),
                message: String(localized: "Add an OpenWeather API key to Config/Secrets.xcconfig and rebuild."),
                recovery: .noAction
            )
        case .unauthorized:
            self.init(
                title: String(localized: "Weather Service Unavailable"),
                message: String(localized: "The API key was rejected. New OpenWeather keys can take a couple of hours to activate."),
                recovery: .retry
            )
        case .rateLimited:
            self.init(
                title: String(localized: "Too Many Requests"),
                message: String(localized: "Wait a minute and try again."),
                recovery: .retry
            )
        case .server:
            self.init(
                title: String(localized: "Weather Service Unavailable"),
                message: String(localized: "The weather service is having trouble right now. Try again shortly."),
                recovery: .retry
            )
        case .noConnection:
            self.init(
                title: String(localized: "You're Offline"),
                message: String(localized: "Check your internet connection and try again."),
                recovery: .retry
            )
        case .timeout:
            self.init(
                title: String(localized: "Request Timed Out"),
                message: String(localized: "The connection is slow right now. Try again."),
                recovery: .retry
            )
        case .decoding, .unknown:
            self.init(
                title: String(localized: "Something Went Wrong"),
                message: String(localized: "We couldn't load the weather. Try again."),
                recovery: .retry
            )
        }
    }

    private static func message(for reason: CityQueryError) -> String {
        switch reason {
        case .empty:
            return String(localized: "Enter a city name.")
        case .tooLong:
            return String(localized: "That search is too long. Try just the city and state.")
        case .invalidCharacters:
            return String(localized: "City names can only contain letters, spaces, periods, apostrophes and hyphens.")
        case .tooManyComponents:
            return String(localized: "Search with just a city, or a city and state, like “Austin, TX”.")
        case .unknownState(let state):
            return String(localized: "“\(state)” isn't a US state. Try something like “Austin, TX”.")
        }
    }
}
