import Foundation

enum CityQueryError: Error, Equatable, Sendable {
    case empty
    case tooLong
    case invalidCharacters
    case tooManyComponents
    case unknownState(String)
}

/// A validated US city search. Build one with `CityQuery.parse(_:)` so raw user
/// input never goes straight into a request.
struct CityQuery: Hashable, Codable, Sendable {
    let city: String
    /// Two-letter USPS code, uppercased. Optional because "Chicago" alone is a fine search.
    let stateCode: String?

    static let maxLength = 100

    init(city: String, stateCode: String? = nil) {
        self.city = city
        self.stateCode = stateCode
    }

    /// What we show back to the user and what gets persisted, e.g. "Austin, TX".
    var displayName: String {
        guard let stateCode else { return city }
        return "\(city), \(stateCode)"
    }

    /// Value for the geocoder's `q` param: "{city},{state},{country}".
    /// Country is always US because the product is US-only.
    var geocodingQuery: String {
        [city, stateCode, "US"].compactMap { $0 }.joined(separator: ",")
    }

    // MARK: - Parsing

    private static let allowedCityCharacters: CharacterSet = {
        var set = CharacterSet.letters
        // Periods for "St. Louis", apostrophes (both kinds) for "Coeur d'Alene", hyphens for "Winston-Salem".
        set.insert(charactersIn: " .'-\u{2019}")
        return set
    }()

    private static let countrySuffixes: Set<String> = [
        "us", "usa", "u.s.", "u.s.a.", "united states", "united states of america"
    ]

    /// Accepts the formats people actually type:
    /// "Austin", "Austin, TX", "austin, texas", "Austin TX", "Austin, TX, USA".
    static func parse(_ rawInput: String) -> Result<CityQuery, CityQueryError> {
        let collapsed = rawInput
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsed.isEmpty else { return .failure(.empty) }
        guard collapsed.count <= maxLength else { return .failure(.tooLong) }

        var parts = collapsed
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Input like ",,," survives the first guard but has nothing in it.
        guard !parts.isEmpty else { return .failure(.empty) }

        // We only search the US, so a trailing country is noise.
        if parts.count > 1, let last = parts.last, countrySuffixes.contains(last.lowercased()) {
            parts.removeLast()
        }
        guard parts.count <= 2 else { return .failure(.tooManyComponents) }

        var city = parts[0]
        var stateCode: String?

        if parts.count == 2 {
            guard let code = USState.code(for: parts[1]) else {
                return .failure(.unknownState(parts[1]))
            }
            stateCode = code
        } else if let split = splitTrailingStateCode(from: city) {
            city = split.city
            stateCode = split.code
        }

        let scalars = city.unicodeScalars
        guard scalars.allSatisfy({ allowedCityCharacters.contains($0) }),
              scalars.contains(where: { CharacterSet.letters.contains($0) }) else {
            return .failure(.invalidCharacters)
        }

        return .success(CityQuery(city: city, stateCode: stateCode))
    }

    /// Handles "Austin TX" (no comma). Only kicks in when the trailing token is an
    /// uppercase two-letter state code, so a lowercase trailing word like "or" or "in"
    /// never gets read as Oregon/Indiana.
    private static func splitTrailingStateCode(from text: String) -> (city: String, code: String)? {
        guard let spaceIndex = text.lastIndex(of: " ") else { return nil }
        let token = String(text[text.index(after: spaceIndex)...])
        let name = String(text[..<spaceIndex]).trimmingCharacters(in: .whitespaces)
        guard token.count == 2,
              token == token.uppercased(),
              !name.isEmpty,
              let code = USState.code(for: token) else {
            return nil
        }
        return (name, code)
    }
}
