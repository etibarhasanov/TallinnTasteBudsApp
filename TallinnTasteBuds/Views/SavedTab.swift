import SwiftUI

/// The places this phone saved, newest first.
struct SavedTab: View {
    @Environment(ContentStore.self) private var content
    @Environment(SavesStore.self) private var saves

    @State private var path = NavigationPath(LaunchScript.routes(tab: 2))

    private var places: [Place] { saves.ids.compactMap { content.place($0) } }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if places.isEmpty {
                    EmptyNote(title: content.t("appSavedNone", "Nothing saved yet"),
                              text: content.t("appSavedNoneSay", "Press the heart on any place to keep it here."),
                              systemImage: "heart")
                } else {
                    List {
                        ForEach(places) { place in
                            NavigationLink(value: Route.place(place.id)) { PlaceRow(place: place, thumb: 56) }
                                .listRowBackground(Theme.paper)
                        }
                        .onDelete { offsets in
                            let gone = offsets.map { places[$0].id }
                            for id in gone { saves.toggle(id) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .paperBackground()
            .navigationTitle(content.t("listSaved", "Places I saved"))
            .withRoutes()
        }
    }
}
