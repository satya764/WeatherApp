import SwiftUI
import UIKit

/// Remote weather icon backed by `ImageLoading`.
///
/// Not using `AsyncImage` on purpose: it has no memory cache, so it refetches and
/// re-decodes every time the view is recreated (size class change, rotation, list reuse).
struct WeatherIconView: View {
    let url: URL?
    let loader: any ImageLoading

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if didFail || url == nil {
                Image(systemName: "cloud.sun")
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .padding(8)
            } else {
                ProgressView()
            }
        }
        // The condition text next to the icon already says what it shows.
        .accessibilityHidden(true)
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        image = nil
        didFail = false
        guard let url else { return }
        do {
            image = try await loader.image(for: url)
        } catch is CancellationError {
            // View went away or the URL changed. Nothing to show.
        } catch {
            didFail = true
        }
    }
}
