import SwiftUI

struct RootView: View {
    @Binding var style: StylePreference

    @Environment(ContentStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @State private var selection = Tab.map
    /// The place a tap anywhere in the app wants opened, so the map and the list
    /// share one detail sheet rather than each keeping their own.
    @State private var opened: Place?

    enum Tab { case map, list, saved, settings }

    var body: some View {
        TabView(selection: $selection) {
            MapScreen(opened: $opened)
                .tabItem { Label(store.app(.tabMap), systemImage: "map") }
                .tag(Tab.map)

            ListScreen(opened: $opened)
                .tabItem { Label(store.app(.tabList), systemImage: "list.bullet") }
                .tag(Tab.list)

            SavedScreen(opened: $opened)
                .tabItem { Label(store.app(.tabSaved), systemImage: "bookmark") }
                .tag(Tab.saved)

            SettingsScreen(style: $style)
                .tabItem { Label(store.app(.tabSettings), systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(Theme.of(scheme).accent)
        .environment(\.theme, Theme.of(scheme))
        .sheet(item: $opened) { place in
            PlaceDetailView(place: place)
                .environment(\.theme, Theme.of(scheme))
        }
    }
}
