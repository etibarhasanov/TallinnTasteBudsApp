import CoreLocation
import SwiftUI

/// The site's list panel: search, filter chips, sort, and every place in order.
struct ListScreen: View {
    @Binding var opened: Place?

    @Environment(ContentStore.self) private var store
    @Environment(LocationProvider.self) private var location
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            VStack(spacing: 0) {
                head
                FilterChips()
                Divider().overlay(theme.hairline)
                list
            }
            .background(theme.wash)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { BrandMark() }
                ToolbarItem(placement: .topBarTrailing) { sortMenu($store.sort) }
            }
            .searchable(
                text: $store.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: store.strings("searchPlaceholder")
            )
        }
    }

    private var places: [Place] {
        store.visiblePlaces(near: location.location)
    }

    /// The site's list head: the word the panel is standing in, over the name
    /// of what is under it. The title used to be the navigation bar's, and the
    /// bar now carries the logo instead — which is what the header had been
    /// missing, a search field and a count of places and no sign of whose map
    /// this is.
    private var head: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(store.strings("listTitle"))
                .font(.display(19, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(theme.ink)
            Text(store.strings("eyebrow").uppercased(with: Locale(identifier: store.lang)))
                .font(.mono(10))
                .tracking(1.6)   // the site's .16em, at 10px
                .foregroundStyle(theme.muted)
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var list: some View {
        let results = places
        if results.isEmpty {
            ContentUnavailableView {
                Text(store.query.isEmpty ? store.strings("noResults")
                                         : store.strings("searchNone", ["q": store.query]))
                    .font(.running(16))
            }
            .frame(maxHeight: .infinity)
            .background(theme.wash)
        } else {
            List {
                Section {
                    ForEach(results) { place in
                        Button { opened = place } label: {
                            PlaceRow(place: place, distance: distance(to: place))
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(theme.paper)
                        .accessibilityLabel(store.strings("openPlace", ["name": place.name]))
                    }
                } footer: {
                    Text(store.strings.count(results.count))
                        .font(.mono(11))
                        .foregroundStyle(theme.muted)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.wash)
        }
    }

    private func distance(to place: Place) -> CLLocationDistance? {
        // Only worth showing when it is a distance the reader could act on: from
        // another country it is a number with no meaning.
        guard store.sort == .nearest, !location.isAwayFromTallinn,
              let current = location.location else { return nil }
        return store.distance(from: current, to: place)
    }

    private func sortMenu(_ selection: Binding<ContentStore.SortOrder>) -> some View {
        Menu {
            Picker(store.app(.sort), selection: selection) {
                Text(store.strings("listNew")).tag(ContentStore.SortOrder.newest)
                Text(store.strings("listAlphabet")).tag(ContentStore.SortOrder.alphabetical)
                Text(store.app(.sortNearest)).tag(ContentStore.SortOrder.nearest)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .accessibilityLabel(store.app(.sort))
        }
        // Sorting by distance is the one order that needs a fix to mean anything.
        .onChange(of: store.sort) { _, order in
            if order == .nearest { location.request() }
        }
    }
}