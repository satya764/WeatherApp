import Combine
import Foundation

@MainActor
final class WeatherSearchViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(WeatherDisplayModel)
        case failed(UserFacingError)
    }

    enum Source: Equatable {
        case city(CityQuery)
        case currentLocation
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var locationAuthorization: LocationAuthorization

    // Navigation hooks, wired up by the coordinator. The view model decides *when*
    // something should happen; the coordinator owns *how* (push, alert, open URL).
    var onShowDetails: ((WeatherDisplayModel) -> Void)?
    var onLocationAccessDenied: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private let weatherService: any WeatherProviding
    private let locationProvider: any LocationProviding
    private let lastSearchStore: any LastSearchStoring
    private let formatter: WeatherDisplayFormatter

    private var loadTask: Task<Void, Never>?
    private var lastSource: Source?
    private var hasStarted = false
    private var userHasChosenSource = false

    init(
        weatherService: any WeatherProviding,
        locationProvider: any LocationProviding,
        lastSearchStore: any LastSearchStoring,
        formatter: WeatherDisplayFormatter
    ) {
        self.weatherService = weatherService
        self.locationProvider = locationProvider
        self.lastSearchStore = lastSearchStore
        self.formatter = formatter
        self.locationAuthorization = locationProvider.authorization
    }

    // MARK: - Lifecycle

    /// Launch flow:
    /// 1. If there's a saved city, show it right away.
    /// 2. If we've never asked for location, ask now.
    /// 3. If the user says yes to that prompt, switch to their location. They just
    ///    opted in, so that's what they expect to see.
    ///
    /// On later launches the saved city wins over location, because typing a city is
    /// the stronger signal of what they want. If there's no saved city and location is
    /// already allowed, we use location.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        let savedQuery = lastSearchStore.load()
        if let savedQuery {
            load(.city(savedQuery))
        }

        switch locationProvider.authorization {
        case .notDetermined:
            let status = await locationProvider.requestAuthorization()
            locationAuthorization = status
            // The system prompt can sit there a while. If the user searched or tapped
            // the location button meanwhile, leave their choice alone.
            if status == .authorized, !userHasChosenSource {
                load(.currentLocation)
            }
        case .authorized:
            if savedQuery == nil {
                load(.currentLocation)
            }
        case .denied, .restricted:
            break
        }

        await loadTask?.value
    }

    // MARK: - Intents

    @discardableResult
    func search(_ text: String) -> Task<Void, Never>? {
        switch CityQuery.parse(text) {
        case .success(let query):
            userHasChosenSource = true
            return load(.city(query))
        case .failure(.empty):
            // Tapping search on an empty field doesn't deserve an error.
            return nil
        case .failure(let reason):
            loadTask?.cancel()
            state = .failed(UserFacingError(.invalidQuery(reason)))
            return nil
        }
    }

    @discardableResult
    func useCurrentLocation() -> Task<Void, Never>? {
        let status = locationProvider.authorization
        locationAuthorization = status
        userHasChosenSource = true

        switch status {
        case .authorized:
            return load(.currentLocation)
        case .notDetermined:
            return Task { [weak self] in
                guard let self else { return }
                let newStatus = await self.locationProvider.requestAuthorization()
                self.locationAuthorization = newStatus
                if newStatus == .authorized {
                    await self.load(.currentLocation).value
                }
            }
        case .denied, .restricted:
            onLocationAccessDenied?()
            return nil
        }
    }

    @discardableResult
    func retry() -> Task<Void, Never>? {
        guard let lastSource else { return nil }
        return load(lastSource)
    }

    func showDetails() {
        guard case .loaded(let model) = state else { return }
        onShowDetails?(model)
    }

    func openSettings() {
        onOpenSettings?()
    }

    /// Called when the app comes back to the foreground. If the user just turned
    /// location on in Settings from our error screen, pick it up without making them tap again.
    @discardableResult
    func refreshLocationAuthorization() -> Task<Void, Never>? {
        let previous = locationAuthorization
        let current = locationProvider.authorization
        locationAuthorization = current

        guard previous != .authorized, current == .authorized,
              case .failed(let error) = state, error.recovery == .openSettings else {
            return nil
        }
        return load(.currentLocation)
    }

    // MARK: - Loading

    /// One load at a time. Starting a new one cancels the old one, and the old one is
    /// never allowed to write its result, even if its network call already finished.
    @discardableResult
    private func load(_ source: Source) -> Task<Void, Never> {
        loadTask?.cancel()
        lastSource = source
        state = .loading

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let weather = try await self.fetch(source)
                try Task.checkCancellation()
                self.state = .loaded(self.formatter.makeDisplayModel(for: weather))
                // Only save searches that worked, so a typo never becomes the launch city.
                if case .city(let query) = source {
                    self.lastSearchStore.save(query)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.state = .failed(UserFacingError(WeatherError(error)))
            }
        }
        loadTask = task
        return task
    }

    private func fetch(_ source: Source) async throws -> Weather {
        switch source {
        case .city(let query):
            return try await weatherService.weather(for: query)
        case .currentLocation:
            let coordinate = try await locationProvider.currentCoordinate()
            return try await weatherService.weather(at: coordinate)
        }
    }
}
