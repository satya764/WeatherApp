# Weather

iOS take-home: look up current weather for a US city using the OpenWeather API.

UIKit + SwiftUI, MVVM-C, no storyboards, no third-party dependencies. iOS 17+, built with Xcode 16.

## Running it

1. Get a free API key at https://home.openweathermap.org/api_keys
   (new keys can take an hour or two before they start working)
2. `cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig` and paste the key in
3. Open `WeatherApp.xcodeproj`, pick a simulator, run

`Secrets.xcconfig` is git-ignored. Without it the app still builds and tells you the key is missing.
You can also set `OPENWEATHER_API_KEY` as an environment variable on the scheme.

Tests: `⌘U`, or

```
xcodebuild test -project WeatherApp.xcodeproj -scheme WeatherApp \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Neither test target needs an API key or network. UI tests run against stubbed services.

## What it does

- Search a US city: `Austin`, `Austin, TX`, `austin, texas`, `Austin TX`, `Austin, TX, USA` all work
- Shows temperature, condition + icon, high/low, feels like, humidity, wind, precipitation, and a details
  screen with pressure, visibility, cloud cover, sunrise/sunset (in the city's local time)
- Icons are downloaded and cached (memory + disk)
- Last successful search is restored on launch
- Asks for location on first launch; if allowed, shows weather where you are
- Units follow the device locale (°F/mph/mi in the US, metric elsewhere)
- Portrait and landscape, iPhone and iPad, Dynamic Type, VoiceOver, English + Spanish

## Structure

```
WeatherApp/
  App/            AppDelegate, SceneDelegate, AppDependencies (composition root), AppConfiguration
  Coordinators/   AppCoordinator -> WeatherCoordinator (search, details, alerts, Settings)
  Domain/         Weather, CityQuery (+ parsing/validation), Coordinate, WeatherError
  Data/
    Networking/   HTTPClient protocol + URLSession impl, OpenWeather endpoints
    DTOs/         Wire models, mapping to domain
    Services/     OpenWeatherService (geocode -> weather)
    Location/     CoreLocation wrapped in async/await
    Persistence/  Last search store (UserDefaults)
    ImageLoading/ CachedImageLoader (actor, NSCache + URLCache, dedupes in-flight requests)
  Presentation/
    Search/       WeatherSearchViewController (UIKit) hosting WeatherContentView (SwiftUI) + view model
    Detail/       WeatherDetailView (SwiftUI) + view model
    Formatting/   WeatherDisplayFormatter -> WeatherDisplayModel
    Errors/       UserFacingError (titles, messages, which button to show)
  Support/        Stubs for UI tests (DEBUG only)
WeatherAppTests/  Unit tests (model, service, persistence, formatting, view models)
WeatherAppUITests/
```

Flow of a search:

```
UISearchBar -> WeatherSearchViewModel.search(text)
            -> CityQuery.parse            (validation, no network for bad input)
            -> OpenWeatherService         (/geo/1.0/direct, then /data/2.5/weather?lat&lon)
            -> WeatherDisplayFormatter    (locale-aware strings)
            -> @Published state           -> SwiftUI renders
```

### Why UIKit and SwiftUI where they are

The navigation stack, search controller and bar button are UIKit. `UISearchController` in a nav bar is
still easier to control precisely from UIKit (return key, first responder, large title behavior in
landscape). Everything that renders state is SwiftUI because it's a lot less code for the same result.
The coordinator pushes the SwiftUI details screen in a `UIHostingController`.

### Dependency injection

Constructor injection only. `AppDependencies` builds everything once at launch and the coordinator
passes what each screen needs. Every external thing sits behind a protocol (`HTTPClient`,
`WeatherProviding`, `LocationProviding`, `LastSearchStoring`, `ImageLoading`, `URLOpening`), which is
what makes the view model and service tests possible without network or CoreLocation.

## Decisions worth calling out

**Geocoding instead of `q=city`.** The docs say city-name lookup on the weather endpoint is deprecated,
so search goes through the Geocoding API first and then asks for weather by coordinates. It costs one
extra request but the place name from the geocoder is also better (the weather endpoint sometimes
returns a neighborhood or station name). Non-US geocoder matches are filtered out.

**Launch behavior.** Requirements 4 and 5 can conflict, so:
- saved city exists: show it immediately
- never asked for location: ask; if the user says yes, switch to their location (they just opted in)
- later launches: saved city wins over location; with no saved city and permission granted, use location
- if the user searches while the permission prompt is still up, their search is kept

**Only successful searches are saved.** A typo never becomes the city you see on next launch.

**Stale results.** A new search cancels the previous one, and a cancelled load can never write its
result, even if its network call already finished. There's a test for exactly this.

**Units.** The API is always called with `units=metric` and conversion happens in the formatter. The
domain model stays unit-agnostic and switching locale doesn't need a refetch.

**Defensive decoding.** Almost every field in the response is optional because stations really do omit
things (no `rain` when dry, no sunrise near the poles). Only coordinates and temperature are required.
Integer-looking fields are decoded as `Double` and converted with `Int(exactly:)`, since the API has sent
decimals for pressure and `Int(_:)` traps on bad values.

**Errors.** Lower layers map to a single `WeatherError`; the UI maps that to a title, message and an
action (retry, open Settings, or nothing). 401 gets a specific message because "new key not active yet"
is the most common first-run problem with OpenWeather.

## Known shortcuts

Marked in code with "Given more time" comments. The main ones:

- `CoreLocationProvider` doesn't cancel the pending location request when the caller's task is
  cancelled; it relies on a 15s timeout and the caller ignoring late results. I'd wrap it in
  `withTaskCancellationHandler`.
- UK locale is treated as fully metric (°C and km/h). The UK actually uses mph. A units setting would fix
  this properly.
- `AppDependencies` is one container. Fine for one feature; with more I'd split per-feature factories.
- No offline cache of the last weather response. Icons are cached, data isn't.
- Swift 5 language mode. The code is written to be Sendable-correct (actors, `@MainActor` view models,
  value-type models), but I didn't flip the Swift 6 switch and work through every warning.
