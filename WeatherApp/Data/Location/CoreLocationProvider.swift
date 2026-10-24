import CoreLocation
import Foundation

@MainActor
final class CoreLocationProvider: NSObject, LocationProviding {
    private let manager: CLLocationManager
    private let timeout: Duration
    private let maximumCachedLocationAge: TimeInterval

    // Several callers can wait on the same prompt or the same fix. We only ever have
    // one system request in flight and fan the result out.
    private var authorizationWaiters: [CheckedContinuation<LocationAuthorization, Never>] = []
    private var locationWaiters: [CheckedContinuation<Coordinate, Error>] = []
    private var timeoutTask: Task<Void, Never>?

    init(
        manager: CLLocationManager = CLLocationManager(),
        timeout: Duration = .seconds(15),
        maximumCachedLocationAge: TimeInterval = 10 * 60
    ) {
        self.manager = manager
        self.timeout = timeout
        self.maximumCachedLocationAge = maximumCachedLocationAge
        super.init()
        // City-level accuracy is plenty for weather and gets a fix much faster, with less battery.
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.delegate = self
    }

    var authorization: LocationAuthorization {
        LocationAuthorization(manager.authorizationStatus)
    }

    func requestAuthorization() async -> LocationAuthorization {
        let current = authorization
        guard current == .notDetermined else { return current }

        return await withCheckedContinuation { continuation in
            authorizationWaiters.append(continuation)
            if authorizationWaiters.count == 1 {
                manager.requestWhenInUseAuthorization()
            }
        }
    }

    // Given more time I'd wrap this in withTaskCancellationHandler so a cancelled
    // load stops waiting on the fix. Today the caller just ignores the late result,
    // and the timeout below guarantees the continuation always resumes.
    func currentCoordinate() async throws -> Coordinate {
        guard authorization == .authorized else {
            throw LocationError.notAuthorized
        }

        // A fix from a few minutes ago is just as good for weather and returns instantly.
        if let recent = manager.location,
           abs(recent.timestamp.timeIntervalSinceNow) < maximumCachedLocationAge,
           let coordinate = Coordinate(recent.coordinate) {
            return coordinate
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationWaiters.append(continuation)
            guard locationWaiters.count == 1 else { return }
            manager.requestLocation()
            startTimeout()
        }
    }

    // MARK: - Private

    private func startTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self, timeout] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            self?.finishLocationRequest(with: .failure(LocationError.timedOut))
        }
    }

    private func finishLocationRequest(with result: Result<Coordinate, Error>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        // Copy and clear first so a waiter that immediately asks again starts a fresh request.
        let waiters = locationWaiters
        locationWaiters.removeAll()
        waiters.forEach { $0.resume(with: result) }
    }

    fileprivate func handleAuthorizationChange(_ status: LocationAuthorization) {
        // CoreLocation fires this once as soon as the delegate is set, with the current
        // status. Only an actual decision should release anyone waiting on the prompt.
        guard status != .notDetermined else { return }

        let waiters = authorizationWaiters
        authorizationWaiters.removeAll()
        waiters.forEach { $0.resume(returning: status) }

        if status != .authorized {
            finishLocationRequest(with: .failure(LocationError.notAuthorized))
        }
    }
}

extension CoreLocationProvider: CLLocationManagerDelegate {
    // The manager is created on the main thread, so CoreLocation calls back on the main
    // thread. assumeIsolated states that out loud and traps if it ever stops being true.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = LocationAuthorization(manager.authorizationStatus)
        MainActor.assumeIsolated {
            handleAuthorizationChange(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last.flatMap { Coordinate($0.coordinate) }
        MainActor.assumeIsolated {
            if let coordinate {
                finishLocationRequest(with: .success(coordinate))
            } else {
                finishLocationRequest(with: .failure(LocationError.unavailable))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // With requestLocation() a failure is final; there's no retry coming from CoreLocation.
        MainActor.assumeIsolated {
            finishLocationRequest(with: .failure(LocationError.unavailable))
        }
    }
}

extension LocationAuthorization {
    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .authorizedAlways, .authorizedWhenInUse:
            self = .authorized
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        @unknown default:
            self = .denied
        }
    }
}

extension Coordinate {
    init?(_ coordinate: CLLocationCoordinate2D) {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
