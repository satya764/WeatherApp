import UIKit

/// Owns navigation for one flow. View models never push, present or open URLs
/// themselves; they call back and the coordinator decides how.
@MainActor
protocol Coordinator: AnyObject {
    var childCoordinators: [any Coordinator] { get set }
    func start()
}

extension Coordinator {
    func addChild(_ coordinator: any Coordinator) {
        childCoordinators.append(coordinator)
    }

    func removeChild(_ coordinator: any Coordinator) {
        childCoordinators.removeAll { $0 === coordinator }
    }
}

/// Lets coordinators open URLs without talking to `UIApplication.shared` directly, so
/// that path can be swapped out in tests.
@MainActor
protocol URLOpening: AnyObject {
    func openExternalURL(_ url: URL)
}

extension UIApplication: URLOpening {
    func openExternalURL(_ url: URL) {
        open(url, options: [:], completionHandler: nil)
    }
}
