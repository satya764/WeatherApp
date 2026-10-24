import XCTest
@testable import WeatherApp

final class UserDefaultsLastSearchStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "LastSearchStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func test_emptyByDefault() {
        XCTAssertNil(UserDefaultsLastSearchStore(defaults: defaults).load())
    }

    func test_saveThenLoad_roundTrips() {
        let query = CityQuery(city: "Austin", stateCode: "TX")
        UserDefaultsLastSearchStore(defaults: defaults).save(query)

        // New instance, same defaults: simulates a relaunch.
        XCTAssertEqual(UserDefaultsLastSearchStore(defaults: defaults).load(), query)
    }

    func test_corruptPayload_isDiscarded() {
        defaults.set(Data("not json".utf8), forKey: "lastSearch.v1")
        let store = UserDefaultsLastSearchStore(defaults: defaults)

        XCTAssertNil(store.load())
        XCTAssertNil(defaults.data(forKey: "lastSearch.v1"), "bad data should be removed, not re-read every launch")
    }

    func test_payloadThatFailsValidation_isDiscarded() throws {
        let invalid = CityQuery(city: "12345", stateCode: nil)
        defaults.set(try JSONEncoder().encode(invalid), forKey: "lastSearch.v1")

        XCTAssertNil(UserDefaultsLastSearchStore(defaults: defaults).load())
    }

    func test_clear() {
        let store = UserDefaultsLastSearchStore(defaults: defaults)
        store.save(CityQuery(city: "Austin"))
        store.clear()
        XCTAssertNil(store.load())
    }
}

final class AppConfigurationTests: XCTestCase {
    func test_readsKeyFromInfoPlist() {
        let config = AppConfiguration.load(infoDictionary: ["OpenWeatherAPIKey": "abc123"], environment: [:])
        XCTAssertEqual(config.openWeatherAPIKey, "abc123")
    }

    func test_environmentWinsOverInfoPlist() {
        let config = AppConfiguration.load(
            infoDictionary: ["OpenWeatherAPIKey": "plist"],
            environment: ["OPENWEATHER_API_KEY": "env"]
        )
        XCTAssertEqual(config.openWeatherAPIKey, "env")
    }

    func test_ignoresEmptyAndUnexpandedValues() {
        XCTAssertNil(AppConfiguration.load(infoDictionary: ["OpenWeatherAPIKey": "  "], environment: [:]).openWeatherAPIKey)
        XCTAssertNil(AppConfiguration.load(infoDictionary: ["OpenWeatherAPIKey": "$(OPENWEATHER_API_KEY)"], environment: [:]).openWeatherAPIKey)
        XCTAssertNil(AppConfiguration.load(infoDictionary: nil, environment: [:]).openWeatherAPIKey)
    }

    func test_fallsBackToPlistWhenEnvironmentValueIsBlank() {
        let config = AppConfiguration.load(
            infoDictionary: ["OpenWeatherAPIKey": "plist"],
            environment: ["OPENWEATHER_API_KEY": ""]
        )
        XCTAssertEqual(config.openWeatherAPIKey, "plist")
    }
}

final class CachedImageLoaderTests: XCTestCase {
    private let url = URL(string: "https://openweathermap.org/img/wn/10d@2x.png")!

    func test_concurrentRequestsForSameURL_shareOneDownload() async throws {
        let png = TestImages.png()
        let client = MockHTTPClient { request in
            try await Task.sleep(nanoseconds: 50_000_000)
            return (png, .ok(for: request))
        }
        let loader = CachedImageLoader(client: client)

        async let first = loader.image(for: url)
        async let second = loader.image(for: url)
        _ = try await (first, second)

        XCTAssertEqual(client.requests.count, 1)
    }

    func test_secondRequest_isServedFromMemory() async throws {
        let png = TestImages.png()
        let client = MockHTTPClient { request in (png, .ok(for: request)) }
        let loader = CachedImageLoader(client: client)

        _ = try await loader.image(for: url)
        _ = try await loader.image(for: url)

        XCTAssertEqual(client.requests.count, 1)
    }

    func test_undecodableData_throws() async {
        let client = MockHTTPClient { request in (Data("not an image".utf8), .ok(for: request)) }
        let loader = CachedImageLoader(client: client)

        do {
            _ = try await loader.image(for: url)
            XCTFail("expected to throw")
        } catch {
            XCTAssertEqual(error as? ImageLoadingError, .invalidData)
        }
    }

    func test_failuresAreNotCached() async throws {
        let png = TestImages.png()
        let attempts = Counter()
        let client = MockHTTPClient { request in
            if attempts.increment() == 1 { throw NetworkError.transport(.timedOut) }
            return (png, .ok(for: request))
        }
        let loader = CachedImageLoader(client: client)

        _ = try? await loader.image(for: url)
        _ = try await loader.image(for: url)

        XCTAssertEqual(client.requests.count, 2)
    }

    func test_requestsPreferCachedData() async throws {
        let png = TestImages.png()
        let client = MockHTTPClient { request in (png, .ok(for: request)) }
        _ = try await CachedImageLoader(client: client).image(for: url)
        XCTAssertEqual(client.requests.first?.cachePolicy, .returnCacheDataElseLoad)
    }
}

/// Thread-safe counter for @Sendable closures.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() -> Int {
        lock.withLock {
            value += 1
            return value
        }
    }
}
