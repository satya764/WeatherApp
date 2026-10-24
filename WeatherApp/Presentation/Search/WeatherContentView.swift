import SwiftUI

/// SwiftUI body of the search screen. The UIKit controller owns the search bar and
/// navigation; this renders whatever state the view model is in.
struct WeatherContentView: View {
    @ObservedObject var viewModel: WeatherSearchViewModel
    let imageLoader: any ImageLoading

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .idle:
                IdleStateView()
            case .loading:
                LoadingStateView()
            case .loaded(let model):
                ScrollView {
                    WeatherSummaryView(model: model, imageLoader: imageLoader) {
                        viewModel.showDetails()
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            case .failed(let error):
                ErrorStateView(
                    error: error,
                    onRetry: { _ = viewModel.retry() },
                    onOpenSettings: { viewModel.openSettings() }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.state)
    }
}

struct WeatherSummaryView: View {
    let model: WeatherDisplayModel
    let imageLoader: any ImageLoading
    let onShowDetails: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .largeTitle) private var temperatureSize: CGFloat = 72
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 96
    @ScaledMetric(relativeTo: .body) private var tileMinWidth: CGFloat = 150

    /// Two columns on iPad and on iPhone in landscape (compact height). Back to one
    /// column at accessibility text sizes, where side-by-side gets too cramped to read.
    private var usesWideLayout: Bool {
        guard !dynamicTypeSize.isAccessibilitySize else { return false }
        return horizontalSizeClass == .regular || verticalSizeClass == .compact
    }

    var body: some View {
        let layout = usesWideLayout
            ? AnyLayout(HStackLayout(alignment: .center, spacing: 32))
            : AnyLayout(VStackLayout(spacing: 24))

        layout {
            header
                .frame(maxWidth: .infinity)
            VStack(spacing: 16) {
                metricsGrid
                detailsButton
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(maxWidth: 1000)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(model.locationTitle)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            WeatherIconView(url: model.iconURL, loader: imageLoader)
                .frame(width: iconSize, height: iconSize)
            Text(model.temperature)
                .font(.system(size: temperatureSize, weight: .thin, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(model.conditionText)
                .font(.title3)
                .multilineTextAlignment(.center)
            if let highLow = model.highLow {
                Text(highLow)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(model.updatedText)
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.accessibilitySummary)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("weather.header")
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: tileMinWidth), spacing: 12)], spacing: 12) {
            ForEach(model.primaryMetrics) { metric in
                MetricTileView(metric: metric)
            }
        }
    }

    private var detailsButton: some View {
        Button(action: onShowDetails) {
            Label("More Details", systemImage: "list.bullet.rectangle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityIdentifier("weather.detailsButton")
    }
}
