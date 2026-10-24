import Foundation

enum NetworkError: Error, Equatable {
    case invalidRequest
    case invalidResponse
    case httpStatus(Int)
    case transport(URLError.Code)
}

/// Thin seam over URLSession so services can be tested without the network.
/// Contract: only 2xx responses are returned; everything else throws `NetworkError`.
/// Cancellation always surfaces as `CancellationError`.
protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            // Normalize so callers only ever have to check for one kind of cancellation.
            throw CancellationError()
        } catch let error as URLError {
            throw NetworkError.transport(error.code)
        }

        let (data, response) = result
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.httpStatus(http.statusCode)
        }
        return (data, http)
    }
}

extension URLSession {
    /// Weather data goes stale fast, so no HTTP caching for API calls.
    static let weatherAPI: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 15
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    /// Condition icons never change for a given code, so they get a disk cache.
    /// `CachedImageLoader` keeps decoded images in memory on top of this.
    static let images: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 50 * 1024 * 1024, directory: nil)
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 15
        return URLSession(configuration: configuration)
    }()
}
