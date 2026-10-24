import SwiftUI

struct WeatherDetailView: View {
    let viewModel: WeatherDetailViewModel
    let imageLoader: any ImageLoading

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 56

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    WeatherIconView(url: viewModel.display.iconURL, loader: imageLoader)
                        .frame(width: iconSize, height: iconSize)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.display.temperature)
                            .font(.largeTitle.weight(.light))
                            .monospacedDigit()
                        Text(viewModel.display.conditionText)
                            .foregroundStyle(.secondary)
                        if let highLow = viewModel.display.highLow {
                            Text(highLow)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(viewModel.display.accessibilitySummary)
            }

            ForEach(viewModel.sections) { section in
                Section(section.title) {
                    ForEach(section.metrics) { metric in
                        LabeledContent {
                            Text(metric.value)
                                .monospacedDigit()
                        } label: {
                            Label(metric.title, systemImage: metric.systemImage)
                        }
                        .accessibilityIdentifier("detail.\(metric.kind.rawValue)")
                    }
                }
            }

            Section {
                Text(viewModel.display.updatedText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("detail.list")
    }
}
