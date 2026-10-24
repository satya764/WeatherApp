import XCTest

/// Runs against stubbed dependencies (see `UITestingSupport` in the app target), so
/// no network or real location is involved and results are deterministic.
final class WeatherAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_searchShowsWeather_andOpensDetails() throws {
        let app = launch()

        search("Dallas, TX", in: app)

        let header = app.descendants(matching: .any)["weather.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertTrue(header.label.contains("Dallas, Texas"), header.label)
        XCTAssertTrue(app.descendants(matching: .any)["metric.humidity"].exists)

        app.buttons["weather.detailsButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["detail.pressure"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Dallas, Texas"].exists)
    }

    @MainActor
    func test_unknownCity_showsError() throws {
        let app = launch()

        search("Nowhere", in: app)

        XCTAssertTrue(app.staticTexts["City Not Found"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test_invalidInput_showsValidationMessage() throws {
        let app = launch()

        search("12345", in: app)

        XCTAssertTrue(app.staticTexts["Check Your Search"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test_locationButton_whenDenied_offersSettings() throws {
        let app = launch()

        app.buttons["search.locationButton"].tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.buttons["Open Settings"].exists)
        alert.buttons["Not Now"].tap()
        XCTAssertFalse(alert.exists)
    }

    @MainActor
    func test_launch_restoresLastSearch() throws {
        let app = launch(environment: ["UITEST_LAST_SEARCH": "Austin, TX"])

        let header = app.descendants(matching: .any)["weather.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertTrue(header.label.contains("Austin, Texas"), header.label)
    }

    @MainActor
    func test_launch_withLocationAllowed_showsCurrentLocation() throws {
        let app = launch(environment: ["UITEST_LOCATION": "authorized"])

        let header = app.descendants(matching: .any)["weather.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertTrue(header.label.contains("Cupertino"), header.label)
    }

    @MainActor
    func test_idleState_onFirstLaunchWithoutLocation() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Search for a City"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test_rotation_keepsContentOnScreen() throws {
        let app = launch(environment: ["UITEST_LAST_SEARCH": "Austin, TX"])
        let header = app.descendants(matching: .any)["weather.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))

        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["weather.detailsButton"].exists)
        XCTAssertTrue(app.buttons["search.locationButton"].isHittable)
    }

    // MARK: - Helpers

    @MainActor
    private func launch(environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment = environment
        app.launch()
        return app
    }

    @MainActor
    private func search(_ text: String, in app: XCUIApplication) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text + "\n")
    }
}
