import UIKit

protocol ImageLoading: Sendable {
    func image(for url: URL) async throws -> UIImage
}

enum ImageLoadingError: Error, Equatable {
    case invalidData
}

/// Two-level cache for weather icons:
/// 1. `NSCache` of decoded images, so scrolling or re-rendering never decodes twice.
/// 2. `URLCache` on disk (configured on the session in `URLSession.images`), so icons
///    survive relaunches.
///
/// Concurrent requests for the same URL share one download. That matters more than it
/// sounds: the summary and detail screens show the same icon at the same time.
actor CachedImageLoader: ImageLoading {
    private let client: any HTTPClient
    private let memoryCache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    init(client: any HTTPClient, memoryLimit: Int = 100) {
        self.client = client
        memoryCache.countLimit = memoryLimit
    }

    func image(for url: URL) async throws -> UIImage {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }
        if let existing = inFlight[url] {
            return try await existing.value
        }

        let task = Task<UIImage, Error> { [client] in
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
            let (data, _) = try await client.data(for: request)
            guard let image = UIImage(data: data) else {
                throw ImageLoadingError.invalidData
            }
            return image
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }

        // Failures aren't cached, so a flaky connection gets another shot next time.
        let image = try await task.value
        memoryCache.setObject(image, forKey: url as NSURL)
        return image
    }
}
