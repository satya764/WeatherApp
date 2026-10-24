import SwiftUI
import UIKit

struct MetricTileView: View {
    let metric: WeatherDisplayModel.Metric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(metric.title, systemImage: metric.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(metric.value)
                .font(.title3.weight(.medium))
                .monospacedDigit()
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.title)
        .accessibilityValue(metric.value)
        .accessibilityIdentifier("metric.\(metric.kind.rawValue)")
    }
}
