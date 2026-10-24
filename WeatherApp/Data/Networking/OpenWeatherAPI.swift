import Foundation

struct Endpoint: Equatable {
    let path: String
    var queryItems: [URLQueryItem] = []
}

/// All OpenWeather URLs live here.
///
/// City search goes through the Geocoding API and then fetches weather by lat/lon.
/// The `q=` city-name form on /data/2.5/weather still works but is deprecated and
/// no longer gets fixes, so we don't build on it.
enum OpenWeatherAPI {
    // Static, known-good literal; safe to force unwrap.
    static let baseURL = URL(string: "https://api.openweathermap.org")!

    static func directGeocoding(for query: CityQuery, limit: Int = 5) -> Endpoint {
        Endpoint(path: "/geo/1.0/direct", queryItems: [
            URLQueryItem(name: "q", value: query.geocodingQuery),
            URLQueryItem(name: "limit", value: String(limit))
        ])
    }

    static func currentWeather(at coordinate: Coordinate, languageCode: String) -> Endpoint {
        Endpoint(path: "/data/2.5/weather", queryItems: [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(coordinate.longitude)),
            // Always metric; we convert per locale on our side.
            URLQueryItem(name: "units", value: "metric"),
            URLQueryItem(name: "lang", value: languageCode)
        ])
    }

    /// Icon codes look like "10d" or "01n". Anything else is rejected instead of being
    /// pasted into a URL.
    static func iconURL(for code: String) -> URL? {
        guard code.range(of: #"^\d{2}[dn]$"#, options: .regularExpression) != nil else {
            return nil
        }
        return URL(string: "https://openweathermap.org/img/wn/\(code)@2x.png")
    }
}

struct RequestBuilder {
    let baseURL: URL
    let apiKey: String
    var timeout: TimeInterval = 15

    func makeRequest(for endpoint: Endpoint) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidRequest
        }
        components.path = endpoint.path
        components.queryItems = endpoint.queryItems + [URLQueryItem(name: "appid", value: apiKey)]

        guard let url = components.url else {
            throw NetworkError.invalidRequest
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
