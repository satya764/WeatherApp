import SwiftUI
import UIKit

@MainActor
final class WeatherCoordinator: Coordinator {
    var childCoordinators: [any Coordinator] = []

    private let navigationController: UINavigationController
    private let dependencies: AppDependencies
    private let urlOpener: any URLOpening

    init(
        navigationController: UINavigationController,
        dependencies: AppDependencies,
        urlOpener: (any URLOpening)? = nil
    ) {
        self.navigationController = navigationController
        self.dependencies = dependencies
        self.urlOpener = urlOpener ?? (UIApplication.shared as any URLOpening)
    }

    func start() {
        let viewModel = WeatherSearchViewModel(
            weatherService: dependencies.weatherService,
            locationProvider: dependencies.locationProvider,
            lastSearchStore: dependencies.lastSearchStore,
            formatter: dependencies.formatter
        )
        viewModel.onShowDetails = { [weak self] model in
            self?.showDetails(for: model)
        }
        viewModel.onLocationAccessDenied = { [weak self] in
            self?.presentLocationAccessAlert()
        }
        viewModel.onOpenSettings = { [weak self] in
            self?.openAppSettings()
        }

        let viewController = WeatherSearchViewController(viewModel: viewModel, imageLoader: dependencies.imageLoader)
        navigationController.setViewControllers([viewController], animated: false)
    }

    // MARK: - Routes

    // Details is a leaf screen with no navigation of its own, so it doesn't get a child
    // coordinator. If it grows flows (e.g. hourly forecast), it'd get split out.
    private func showDetails(for model: WeatherDisplayModel) {
        let viewModel = WeatherDetailViewModel(display: model)
        let detailView = WeatherDetailView(viewModel: viewModel, imageLoader: dependencies.imageLoader)
        let host = UIHostingController(rootView: detailView)
        host.title = viewModel.title
        host.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(host, animated: true)
    }

    private func presentLocationAccessAlert() {
        let alert = UIAlertController(
            title: String(localized: "Location Access Is Off"),
            message: String(localized: "To see the weather where you are, allow location access for this app in Settings."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "Not Now"), style: .cancel))
        alert.addAction(UIAlertAction(title: String(localized: "Open Settings"), style: .default) { [weak self] _ in
            self?.openAppSettings()
        })
        topMostViewController().present(alert, animated: true)
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        urlOpener.openExternalURL(url)
    }

    /// The search controller may be presented over the nav stack; presenting from
    /// anything below it would fail silently with "already presenting".
    private func topMostViewController() -> UIViewController {
        var top: UIViewController = navigationController
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
