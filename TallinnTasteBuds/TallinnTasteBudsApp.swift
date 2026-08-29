import SwiftUI

@main
struct TallinnTasteBudsApp: App {
    @State private var store = ContentStore()
    @State private var favourites = Favourites()
    @State private var location = LocationProvider()
    @State private var radio = RadioPlayer()
    @AppStorage("ttb.style") private var style: StylePreference = .system
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(style: $style)
                .environment(store)
                .environment(favourites)
                .environment(location)
                .environment(radio)
                .preferredColorScheme(style.colorScheme)
                .task {
                    // The first refresh happens behind the cached copy that is
                    // already on screen, so the app never shows a spinner where
                    // the map should be.
                    await store.refresh()
                }
                .onChange(of: scenePhase) { _, phase in
                    // Coming back to the app is the natural moment to pick up an
                    // edit made on the website in the meantime.
                    if phase == .active {
                        Task { await store.refresh() }
                    }
                }
        }
    }
}
