import Foundation
import CoreLocation
import Observation

/// Where the phone is, when the reader has said the app may know.
///
/// Used for the blue dot on the map and for how far away each place is, both
/// worked out on the phone. It leaves the phone for one thing: `RouteView`
/// sends it to the site's `/api/route` when somebody asks for the way to a
/// place, which is what the permission prompt and `docs/PRIVACY.md` say.
/// Without permission everything else still works and distances are measured
/// from the Old Town, the way the website does it for a visitor who said no.
@MainActor
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    /// Raekoja plats — the middle of the Old Town.
    static let oldTown = CLLocation(latitude: 59.437, longitude: 24.7536)

    private(set) var location: CLLocation?
    private(set) var status: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        status = manager.authorizationStatus
    }

    /// The point distances are measured from, and whether it is really you.
    var origin: CLLocation { location ?? Self.oldTown }
    var isReal: Bool { location != nil }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.startUpdatingLocation()
        default: break
        }
    }

    func distance(to point: CLLocation) -> CLLocationDistance { origin.distance(from: point) }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in
            self.status = s
            if s == .authorizedWhenInUse || s == .authorizedAlways { self.manager.startUpdatingLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            // A fix from the other side of the world is somebody abroad; the
            // Old Town is the more useful origin for them.
            if last.distance(from: Self.oldTown) < 60_000 { self.location = last }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

enum Distance {
    /// "650 m", "1.2 km", "14 km".
    static func text(_ meters: CLLocationDistance) -> String {
        if meters < 1000 { return "\(Int((meters / 10).rounded()) * 10) m" }
        if meters < 10_000 { return String(format: "%.1f km", meters / 1000) }
        return "\(Int((meters / 1000).rounded())) km"
    }
}
