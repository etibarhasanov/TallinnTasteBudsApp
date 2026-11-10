import SwiftUI
import MapKit

/// Every screen one tab can push onto another: a place, a list, a person, or
/// a place a list named that is not on the map.
enum Route: Hashable {
    case place(String)
    case list(String)
    case profile(String)
    case venue(ListItem)
    case discounts
}

extension View {
    /// Registers every route on a tab's navigation stack, so any screen can
    /// link to any other with `NavigationLink(value:)`.
    func withRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .place(let id): PlaceDetailView(id: id)
            case .list(let id): ListDetailView(id: id)
            case .profile(let name): ProfileView(name: name)
            case .venue(let item): VenueView(item: item)
            case .discounts: DiscountsView()
            }
        }
    }
}

/// Walking directions in Apple Maps.
enum Directions {
    static func open(name: String, coordinate: CLLocationCoordinate2D) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}
