import UIKit

@MainActor
final class AppCoordinator: Coordinator {
    var childCoordinators: [any Coordinator] = []

    private let window: UIWindow
    private let dependencies: AppDependencies

    init(window: UIWindow, dependencies: AppDependencies) {
        self.window = window
        self.dependencies = dependencies
    }

    func start() {
        let navigationController = UINavigationController()
        navigationController.navigationBar.prefersLargeTitles = true

        // Only one flow today. Onboarding or a settings flow would be siblings here.
        let weatherCoordinator = WeatherCoordinator(navigationController: navigationController, dependencies: dependencies)
        addChild(weatherCoordinator)
        weatherCoordinator.start()

        window.rootViewController = navigationController
        window.makeKeyAndVisible()
    }
}
