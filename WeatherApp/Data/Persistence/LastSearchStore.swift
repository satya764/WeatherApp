import Foundation

protocol LastSearchStoring: AnyObject {
    func load() -> CityQuery?
    func save(_ query: CityQuery)
    func clear()
}

/// Keeps the last successful city search so we can show it on next launch.
/// UserDefaults is plenty for one small value; no need for Core Data/SwiftData here.
final class UserDefaultsLastSearchStore: LastSearchStoring {
    private let defaults: UserDefaults
    private let key: String

    /// The key is versioned so a future format change can just move to v2.
    init(defaults: UserDefaults = .standard, key: String = "lastSearch.v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> CityQuery? {
        guard let data = defaults.data(forKey: key) else { return nil }

        // Re-run validation on whatever we read back. If the payload is corrupt or was
        // written by an older build with looser rules, drop it instead of failing on
        // every launch.
        guard let decoded = try? JSONDecoder().decode(CityQuery.self, from: data),
              case .success(let validated) = CityQuery.parse(decoded.displayName) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return validated
    }

    func save(_ query: CityQuery) {
        guard let data = try? JSONEncoder().encode(query) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

/// Used by UI tests and previews.
final class InMemoryLastSearchStore: LastSearchStoring {
    private(set) var query: CityQuery?

    init(query: CityQuery? = nil) {
        self.query = query
    }

    func load() -> CityQuery? { query }
    func save(_ query: CityQuery) { self.query = query }
    func clear() { query = nil }
}
