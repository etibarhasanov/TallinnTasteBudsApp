import SwiftUI
import MapKit

/// Every screen one tab can push onto another: a place, a list, a person, a
/// place a list named that is not on the map, or one of your rides.
enum Route: Hashable {
    case place(String)
    case list(String)
    /// A list opened on its Route, to go round it.
    case walk(String)
    case profile(String)
    case venue(ListItem)
    case discounts
    /// Your rides, and one of them opened.
    case rides
    case ride(String)
}

extension View {
    /// Registers every route on a tab's navigation stack, so any screen can
    /// link to any other with `NavigationLink(value:)`.
    func withRoutes() -> some View {
        navigationDestination(for: Route.self) { RouteScreen(route: $0) }
    }
}

/// The screen a route opens — for `withRoutes()`, and for a screen that
/// pushes one from something that is not a `NavigationLink`, such as a link
/// in a write-up.
struct RouteScreen: View {
    let route: Route

    var body: some View {
        switch route {
        case .place(let id): PlaceDetailView(id: id)
        case .list(let id): ListDetailView(id: id)
        case .walk(let id): ListDetailView(id: id, opening: .route)
        case .profile(let name): ProfileView(name: name)
        case .venue(let item): VenueView(item: item)
        case .discounts: DiscountsView()
        case .rides: RidesView()
        case .ride(let id): RideDetailView(id: id)
        }
    }
}
