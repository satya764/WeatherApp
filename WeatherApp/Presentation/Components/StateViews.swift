import SwiftUI

struct IdleStateView: View {
    var body: some View {
        ContentUnavailableView(
            "Search for a City",
            systemImage: "magnifyingglass",
            description: Text("Enter a US city like “Austin, TX”, or tap the location button to use where you are.")
        )
        .accessibilityIdentifier("state.idle")
    }
}

struct LoadingStateView: View {
    var body: some View {
        ProgressView("Loading weather…")
            .accessibilityIdentifier("state.loading")
    }
}

struct ErrorStateView: View {
    let error: UserFacingError
    let onRetry: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(error.title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.message)
        } actions: {
            switch error.recovery {
            case .retry:
                Button("Try Again", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("error.retry")
            case .openSettings:
                Button("Open Settings", action: onOpenSettings)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("error.openSettings")
            case .noAction:
                EmptyView()
            }
        }
        .accessibilityIdentifier("state.error")
    }
}
