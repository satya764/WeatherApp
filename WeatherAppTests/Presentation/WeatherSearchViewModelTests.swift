import XCTest
@testable import WeatherApp

@MainActor
final class WeatherSearchViewModelTests: XCTestCase {
    private struct Harness {
        let sut: WeatherSearchViewModel
        let service: MockWeatherService
        let location: MockLocationProvider
        let store: InMemoryLastSearchStore
    }

    private func makeSUT(
        saved: CityQuery? = nil,
        location: MockLocationProvider? = nil
    ) -> Harness {
        let location = location ?? MockLocationProvider()
        let service = MockWeatherService()
        let store = InMemoryLastSearchStore(query: saved)
        let sut = WeatherSearchViewModel(
            weatherService: service,
            locationProvider: location,
            lastSearchStore: store,
            formatter: WeatherDisplayFormatter(locale: Locale(identifier: "en_US"))
        )
        return Harness(sut: sut, service: service, location: location, store: store)
    }

    // MARK: - Launch

    func test_start_withSavedCity_loadsIt() async {
        let h = makeSUT(saved: CityQuery(city: "Austin", stateCode: "TX"))

        await h.sut.start()

        XCTAssertEqual(h.service.cityRequests, [CityQuery(city: "Austin", stateCode: "TX")])
        XCTAssertEqual(h.sut.state.displayModel?.locationTitle, "Austin, Texas")
    }

    func test_start_withNothingSavedAndLocationAllowed_usesLocation() async {
        let h = makeSUT(location: MockLocationProvider(authorization: .authorized))

        await h.sut.start()

        XCTAssertEqual(h.service.coordinateRequests, [.dallas])
        XCTAssertEqual(h.sut.state.displayModel?.locationTitle, "Here")
    }

    func test_start_withSavedCityAndLocationAllowed_prefersSavedCity() async {
        let h = makeSUT(saved: CityQuery(city: "Austin"), location: MockLocationProvider(authorization: .authorized))

        await h.sut.start()

        XCTAssertEqual(h.service.cityRequests.count, 1)
        XCTAssertTrue(h.service.coordinateRequests.isEmpty)
    }

    func test_start_firstLaunch_asksForPermission_andUsesLocationWhenGranted() async {
        let location = MockLocationProvider(authorization: .notDetermined, authorizationAfterRequest: .authorized)
        let h = makeSUT(location: location)

        await h.sut.start()

        XCTAssertEqual(location.requestCount, 1)
        XCTAssertEqual(h.sut.locationAuthorization, .authorized)
        XCTAssertEqual(h.service.coordinateRequests.count, 1)
        XCTAssertNotNil(h.sut.state.displayModel)
    }

    func test_start_firstLaunch_permissionDenied_staysIdle() async {
        let location = MockLocationProvider(authorization: .notDetermined, authorizationAfterRequest: .denied)
        let h = makeSUT(location: location)

        await h.sut.start()

        XCTAssertEqual(h.sut.state, .idle)
        XCTAssertEqual(h.sut.locationAuthorization, .denied)
        XCTAssertTrue(h.service.coordinateRequests.isEmpty)
    }

    func test_start_permissionGranted_switchesFromSavedCityToLocation() async {
        let location = MockLocationProvider(authorization: .notDetermined, authorizationAfterRequest: .authorized)
        let h = makeSUT(saved: CityQuery(city: "Austin"), location: location)

        await h.sut.start()

        XCTAssertEqual(h.sut.state.displayModel?.locationTitle, "Here")
    }

    func test_start_doesNotOverrideASearchMadeWhileThePromptWasUp() async {
        let location = MockLocationProvider(authorization: .notDetermined, authorizationAfterRequest: .authorized)
        let h = makeSUT(location: location)
        location.onRequestAuthorization = { [sut = h.sut] in
            _ = sut.search("Boston, MA")
        }

        await h.sut.start()

        XCTAssertTrue(h.service.coordinateRequests.isEmpty)
        XCTAssertEqual(h.service.cityRequests, [CityQuery(city: "Boston", stateCode: "MA")])
        XCTAssertNotNil(h.sut.state.displayModel)
    }

    func test_start_onlyRunsOnce() async {
        let h = makeSUT(saved: CityQuery(city: "Austin"))
        await h.sut.start()
        await h.sut.start()
        XCTAssertEqual(h.service.cityRequests.count, 1)
    }

    // MARK: - Search

    func test_search_success_showsWeatherAndSavesQuery() async {
        let h = makeSUT()

        await h.sut.search("Dallas, TX")?.value

        XCTAssertEqual(h.sut.state.displayModel?.temperature, "77°")
        XCTAssertEqual(h.store.query, CityQuery(city: "Dallas", stateCode: "TX"))
    }

    func test_search_failure_showsErrorAndDoesNotSave() async {
        let h = makeSUT()
        h.service.cityHandler = { _ in throw WeatherError.cityNotFound }

        await h.sut.search("Atlantis")?.value

        XCTAssertEqual(h.sut.state.error?.title, UserFacingError(.cityNotFound).title)
        XCTAssertNil(h.store.query, "a failed search must not become the launch city")
    }

    func test_search_invalidInput_showsValidationErrorWithoutNetwork() {
        let h = makeSUT()

        let task = h.sut.search("12345")

        XCTAssertNil(task)
        XCTAssertEqual(h.sut.state.error, UserFacingError(.invalidQuery(.invalidCharacters)))
        XCTAssertTrue(h.service.cityRequests.isEmpty)
    }

    func test_search_emptyInput_isIgnored() {
        let h = makeSUT()
        XCTAssertNil(h.sut.search("   "))
        XCTAssertEqual(h.sut.state, .idle)
    }

    func test_search_setsLoadingImmediately() {
        let h = makeSUT()
        h.sut.search("Dallas")
        XCTAssertEqual(h.sut.state, .loading)
    }

    func test_newerSearchWins_evenIfOlderOneFinishesLater() async {
        let h = makeSUT()
        h.service.cityHandler = { query in
            if query.city == "Slow" {
                // `try?` swallows the cancellation, so this call still returns a value.
                // The view model has to drop it on its own.
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            return .fixture(name: query.city, state: nil)
        }

        let slow = h.sut.search("Slow")
        let fast = h.sut.search("Fast")
        await fast?.value
        await slow?.value

        XCTAssertEqual(h.sut.state.displayModel?.locationTitle, "Fast")
        XCTAssertEqual(h.store.query, CityQuery(city: "Fast"))
    }

    func test_invalidSearch_cancelsInFlightLoad() async {
        let h = makeSUT()
        h.service.cityHandler = { query in
            try? await Task.sleep(nanoseconds: 100_000_000)
            return .fixture(name: query.city)
        }

        let inFlight = h.sut.search("Dallas")
        h.sut.search("Dallas, ZZ")
        await inFlight?.value

        XCTAssertEqual(h.sut.state.error, UserFacingError(.invalidQuery(.unknownState("ZZ"))))
    }

    // MARK: - Retry

    func test_retry_repeatsLastRequest() async {
        let h = makeSUT()
        h.service.cityHandler = { _ in throw WeatherError.noConnection }
        await h.sut.search("Dallas")?.value
        XCTAssertEqual(h.sut.state.error?.recovery, .retry)

        h.service.cityHandler = { query in .fixture(name: query.city) }
        await h.sut.retry()?.value

        XCTAssertEqual(h.service.cityRequests.map(\.city), ["Dallas", "Dallas"])
        XCTAssertNotNil(h.sut.state.displayModel)
    }

    func test_retry_withNothingToRetry_isNoOp() {
        XCTAssertNil(makeSUT().sut.retry())
    }

    // MARK: - Current location

    func test_useCurrentLocation_authorized_loads() async {
        let h = makeSUT(location: MockLocationProvider(authorization: .authorized))
        await h.sut.useCurrentLocation()?.value
        XCTAssertEqual(h.service.coordinateRequests, [.dallas])
    }

    func test_useCurrentLocation_denied_asksCoordinatorToExplain() {
        let h = makeSUT(location: MockLocationProvider(authorization: .denied))
        var prompted = false
        h.sut.onLocationAccessDenied = { prompted = true }

        XCTAssertNil(h.sut.useCurrentLocation())
        XCTAssertTrue(prompted)
        XCTAssertTrue(h.service.coordinateRequests.isEmpty)
    }

    func test_useCurrentLocation_notDetermined_requestsThenLoads() async {
        let location = MockLocationProvider(authorization: .notDetermined, authorizationAfterRequest: .authorized)
        let h = makeSUT(location: location)

        await h.sut.useCurrentLocation()?.value

        XCTAssertEqual(location.requestCount, 1)
        XCTAssertEqual(h.service.coordinateRequests.count, 1)
    }

    func test_locationFailure_mapsToFriendlyError() async {
        let location = MockLocationProvider(authorization: .authorized, coordinateResult: .failure(LocationError.timedOut))
        let h = makeSUT(location: location)

        await h.sut.useCurrentLocation()?.value

        XCTAssertEqual(h.sut.state.error, UserFacingError(.locationUnavailable))
    }

    func test_refreshAuthorization_reloadsAfterUserEnablesLocationInSettings() async {
        let location = MockLocationProvider(authorization: .authorized, coordinateResult: .failure(LocationError.notAuthorized))
        let h = makeSUT(location: location)
        await h.sut.useCurrentLocation()?.value
        XCTAssertEqual(h.sut.state.error?.recovery, .openSettings)

        // Simulate: user flips permission off then on from Settings and comes back.
        location.authorization = .denied
        _ = h.sut.refreshLocationAuthorization()
        location.authorization = .authorized
        location.coordinateResult = .success(.dallas)
        await h.sut.refreshLocationAuthorization()?.value

        XCTAssertNotNil(h.sut.state.displayModel)
    }

    func test_refreshAuthorization_withoutChange_doesNothing() {
        let h = makeSUT(location: MockLocationProvider(authorization: .denied))
        XCTAssertNil(h.sut.refreshLocationAuthorization())
    }

    // MARK: - Navigation hooks

    func test_showDetails_passesCurrentModel() async {
        let h = makeSUT()
        var shown: WeatherDisplayModel?
        h.sut.onShowDetails = { shown = $0 }

        await h.sut.search("Dallas, TX")?.value
        h.sut.showDetails()

        XCTAssertEqual(shown?.locationTitle, "Dallas, Texas")
    }

    func test_showDetails_withoutLoadedWeather_doesNothing() {
        let h = makeSUT()
        var called = false
        h.sut.onShowDetails = { _ in called = true }
        h.sut.showDetails()
        XCTAssertFalse(called)
    }

    func test_openSettings_forwardsToCoordinator() {
        let h = makeSUT()
        var opened = false
        h.sut.onOpenSettings = { opened = true }
        h.sut.openSettings()
        XCTAssertTrue(opened)
    }
}
