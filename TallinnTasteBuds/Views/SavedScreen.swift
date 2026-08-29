import SwiftUI

/// The reader's own shortlist — the one thing in the app that is not a mirror of
/// the website. It lives on the device, in the order the site would list them.
struct SavedScreen: View {
    @Binding var opened: Place?

    @Environment(ContentStore.self) private var store
    @Environment(Favourites.self) private var favourites
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            Group {
                if saved.isEmpty {
                    ContentUnavailableView {
                        Label(store.app(.savedEmpty), systemImage: "bookmark")
                    } description: {
                        Text(store.app(.savedEmptyHint)).font(.running(15))
                    }
                    .background(theme.wash)
                } else {
                    List {
                        ForEach(saved) { place in
                            Button { opened = place } label: { PlaceRow(place: place) }
                                .buttonStyle(.plain)
                                .listRowBackground(theme.paper)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        favourites.toggle(place)
                                    } label: {
                                        Label(store.app(.save), systemImage: "bookmark.slash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(theme.wash)
                }
            }
            .navigationTitle(store.app(.tabSaved))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// Drawn from the live list, so a place that closes on the website shows as
    /// closed here too rather than as a stale copy of itself.
    private var saved: [Place] {
        favourites.filter(store.allPlacesByName)
    }
}
