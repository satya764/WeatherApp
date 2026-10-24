import Combine
import SwiftUI
import UIKit

/// UIKit shell for the search screen: navigation bar, `UISearchController` and the
/// location button. The content underneath is SwiftUI (`WeatherContentView`) hosted
/// as a child view controller.
///
/// Split this way because UISearchController in a navigation bar is still nicer to
/// control from UIKit (return key, first responder, large titles), while the state
/// rendering is much less code in SwiftUI.
final class WeatherSearchViewController: UIViewController {
    private let viewModel: WeatherSearchViewModel
    private let imageLoader: any ImageLoading
    private let searchController = UISearchController(searchResultsController: nil)
    private var cancellables = Set<AnyCancellable>()

    private lazy var locationButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "location"),
            style: .plain,
            target: self,
            action: #selector(didTapLocationButton)
        )
        item.accessibilityLabel = String(localized: "Use Current Location")
        item.accessibilityIdentifier = "search.locationButton"
        return item
    }()

    init(viewModel: WeatherSearchViewModel, imageLoader: any ImageLoading) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable, message: "This project doesn't use storyboards or nibs.")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localized: "Weather")
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = locationButton

        configureSearchController()
        embedContentView()
        bindViewModel()
        applyTraitDependentLayout()

        registerForTraitChanges([UITraitVerticalSizeClass.self]) { (controller: WeatherSearchViewController, _: UITraitCollection) in
            controller.applyTraitDependentLayout()
        }

        Task { await viewModel.start() }
    }

    // MARK: - Setup

    private func configureSearchController() {
        let searchBar = searchController.searchBar
        searchBar.delegate = self
        searchBar.placeholder = String(localized: "City, State (e.g. Austin, TX)")
        searchBar.autocapitalizationType = .words
        searchBar.autocorrectionType = .no
        searchBar.spellCheckingType = .no
        searchBar.returnKeyType = .search
        searchBar.enablesReturnKeyAutomatically = true
        searchBar.searchTextField.accessibilityIdentifier = "search.field"

        searchController.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func embedContentView() {
        let host = UIHostingController(rootView: WeatherContentView(viewModel: viewModel, imageLoader: imageLoader))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    private func bindViewModel() {
        viewModel.$locationAuthorization
            .removeDuplicates()
            .sink { [weak self] status in
                self?.updateLocationButton(for: status)
            }
            .store(in: &cancellables)

        // Coming back from Settings is the common way permission changes after launch.
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                _ = self?.viewModel.refreshLocationAuthorization()
            }
            .store(in: &cancellables)
    }

    // MARK: - Layout

    /// iPhone landscape has very little height; a large title would eat a third of it.
    private func applyTraitDependentLayout() {
        navigationItem.largeTitleDisplayMode = traitCollection.verticalSizeClass == .compact ? .never : .always
    }

    private func updateLocationButton(for status: LocationAuthorization) {
        switch status {
        case .authorized:
            locationButton.image = UIImage(systemName: "location.fill")
            locationButton.accessibilityHint = nil
        case .notDetermined:
            locationButton.image = UIImage(systemName: "location")
            locationButton.accessibilityHint = nil
        case .denied, .restricted:
            locationButton.image = UIImage(systemName: "location.slash")
            locationButton.accessibilityHint = String(localized: "Location access is off.")
        }
    }

    // MARK: - Actions

    @objc private func didTapLocationButton() {
        searchController.searchBar.resignFirstResponder()
        viewModel.useCurrentLocation()
    }
}

extension WeatherSearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        viewModel.search(searchBar.text ?? "")
        searchBar.resignFirstResponder()
    }
}
