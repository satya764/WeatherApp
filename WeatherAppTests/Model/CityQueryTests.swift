import XCTest
@testable import WeatherApp

final class CityQueryTests: XCTestCase {
    func test_parse_cityOnly() {
        XCTAssertEqual(try CityQuery.parse("Chicago").get(), CityQuery(city: "Chicago"))
    }

    func test_parse_cityAndStateCode() {
        XCTAssertEqual(try CityQuery.parse("Austin, TX").get(), CityQuery(city: "Austin", stateCode: "TX"))
    }

    func test_parse_lowercaseStateCodeAfterComma() {
        XCTAssertEqual(try CityQuery.parse("austin, tx").get(), CityQuery(city: "austin", stateCode: "TX"))
    }

    func test_parse_fullStateName() {
        XCTAssertEqual(try CityQuery.parse("Portland, Oregon").get(), CityQuery(city: "Portland", stateCode: "OR"))
    }

    func test_parse_multiWordStateName() {
        XCTAssertEqual(try CityQuery.parse("Albany, new york").get(), CityQuery(city: "Albany", stateCode: "NY"))
    }

    func test_parse_dropsTrailingCountry() {
        XCTAssertEqual(try CityQuery.parse("Austin, TX, USA").get(), CityQuery(city: "Austin", stateCode: "TX"))
        XCTAssertEqual(try CityQuery.parse("Denver, United States").get(), CityQuery(city: "Denver"))
    }

    func test_parse_stateCodeWithoutComma() {
        XCTAssertEqual(try CityQuery.parse("San Antonio TX").get(), CityQuery(city: "San Antonio", stateCode: "TX"))
    }

    func test_parse_lowercaseTrailingWordIsNotTreatedAsState() {
        // "in" would be Indiana if we were careless.
        XCTAssertEqual(try CityQuery.parse("Lake in").get(), CityQuery(city: "Lake in"))
    }

    func test_parse_collapsesWhitespace() {
        XCTAssertEqual(try CityQuery.parse("  New   York ,  NY \n").get(), CityQuery(city: "New York", stateCode: "NY"))
    }

    func test_parse_allowsCommonPunctuation() {
        XCTAssertNoThrow(try CityQuery.parse("St. Louis, MO").get())
        XCTAssertNoThrow(try CityQuery.parse("Coeur d'Alene, ID").get())
        XCTAssertNoThrow(try CityQuery.parse("Coeur d\u{2019}Alene, ID").get())
        XCTAssertNoThrow(try CityQuery.parse("Winston-Salem, NC").get())
    }

    func test_parse_rejectsEmptyInput() {
        XCTAssertEqual(failure(of: ""), .empty)
        XCTAssertEqual(failure(of: "   \n"), .empty)
        XCTAssertEqual(failure(of: ", ,"), .empty)
    }

    func test_parse_rejectsTooLongInput() {
        XCTAssertEqual(failure(of: String(repeating: "a", count: CityQuery.maxLength + 1)), .tooLong)
    }

    func test_parse_rejectsDigitsAndSymbols() {
        XCTAssertEqual(failure(of: "75201"), .invalidCharacters)
        XCTAssertEqual(failure(of: "Dallas; DROP TABLE"), .invalidCharacters)
        XCTAssertEqual(failure(of: "..."), .invalidCharacters)
    }

    func test_parse_rejectsUnknownState() {
        XCTAssertEqual(failure(of: "Toronto, ON"), .unknownState("ON"))
    }

    func test_parse_rejectsTooManyComponents() {
        XCTAssertEqual(failure(of: "A, B, C, D"), .tooManyComponents)
    }

    func test_geocodingQuery_alwaysIncludesUS() {
        XCTAssertEqual(CityQuery(city: "Austin", stateCode: "TX").geocodingQuery, "Austin,TX,US")
        XCTAssertEqual(CityQuery(city: "Austin").geocodingQuery, "Austin,US")
    }

    func test_displayName() {
        XCTAssertEqual(CityQuery(city: "Austin", stateCode: "TX").displayName, "Austin, TX")
        XCTAssertEqual(CityQuery(city: "Austin").displayName, "Austin")
    }

    func test_displayName_roundTripsThroughParse() throws {
        let query = CityQuery(city: "Coeur d'Alene", stateCode: "ID")
        XCTAssertEqual(try CityQuery.parse(query.displayName).get(), query)
    }

    private func failure(of input: String) -> CityQueryError? {
        if case .failure(let error) = CityQuery.parse(input) { return error }
        return nil
    }
}

final class CoordinateTests: XCTestCase {
    func test_acceptsValidRange() {
        XCTAssertNotNil(Coordinate(latitude: 90, longitude: 180))
        XCTAssertNotNil(Coordinate(latitude: -90, longitude: -180))
    }

    func test_rejectsOutOfRangeAndNonFinite() {
        XCTAssertNil(Coordinate(latitude: 90.1, longitude: 0))
        XCTAssertNil(Coordinate(latitude: 0, longitude: -180.1))
        XCTAssertNil(Coordinate(latitude: .nan, longitude: 0))
        XCTAssertNil(Coordinate(latitude: 0, longitude: .infinity))
    }
}

final class USStateTests: XCTestCase {
    func test_codeLookup() {
        XCTAssertEqual(USState.code(for: "tx"), "TX")
        XCTAssertEqual(USState.code(for: "Texas"), "TX")
        XCTAssertEqual(USState.code(for: " district of columbia "), "DC")
        XCTAssertNil(USState.code(for: "Ontario"))
    }

    func test_coversFiftyStatesPlusDC() {
        XCTAssertEqual(USState.namesByCode.count, 51)
    }
}
