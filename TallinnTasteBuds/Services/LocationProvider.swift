import CoreLocation
import Observation

/// A thin wrapper over CoreLocation: one fix when asked, never a running trace.
/// The app only needs to know roughly where you are to sort by distance and to
/// centre the map, so it asks for when-in-use and stops the moment it has a fix.
@MainActor
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private(set) var location: CLLocation?
    private(set) var status: CLAuthorizationStatus
    private(set) var failed = false

    /// Tallinn, roughly the middle of the map, used until a fix arrives.
    static let tallinn = CLLocationCoordinate2D(latitude: 59.437, longitude: 24.7536)

    /// Far enough outside the city that sorting by distance stops meaning
    /// anything — the site shows every place rather than a nearest list.
    static let awayThreshold: CLLocationDistance = 60_000

    private let manager = CLLocationManager()

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorised: Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    var isAwayFromTallinn: Bool {
        guard let location else { return false }
        let centre = CLLocation(latitude: Self.tallinn.latitude, longitude: Self.tallinn.longitude)
        return location.distance(from: centre) > Self.awayThreshold
    }

    /// Ask once. Safe to call repeatedly — CoreLocation only shows the prompt the
    /// first time, and after that this is just a request for a fresh fix.
    func request() {
        failed = false
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            failed = true
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Only the status crosses back to the main actor: CLLocationManager is
        // not Sendable, and the one this object owns is already over there.
        let newStatus = manager.authorizationStatus
        Task { @MainActor in
            self.status = newStatus
            switch newStatus {
            case .authorizedWhenInUse, .authorizedAlways: self.manager.requestLocation()
            case .notDetermined: break
            default: self.failed = true
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.location = latest
            self.failed = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.failed = true }
    }
}
