import SwiftUI

@main
struct TallinnTasteBudsApp: App {
    @State private var content = ContentStore()
    @State private var saves = SavesStore()
    @State private var location = LocationProvider()
    @State private var account = AccountStore()
    @Environment(\.scenePhase) private var phase

    init() {
        // Photos are fetched over and over as the map is browsed; a bigger
        // cache keeps them from being fetched again on the next screen.
        URLCache.shared = URLCache(memoryCapacity: 32 << 20, diskCapacity: 256 << 20)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(content)
                .environment(saves)
                .environment(location)
                .environment(account)
                .task {
                    await content.refresh()
                    await account.refresh(saves: saves)
                }
        }
        .onChange(of: phase) { _, now in
            // Coming back to the app is when an edit on the website should
            // show up, without waiting for the next cold start.
            if now == .active {
                Task {
                    await content.refresh()
                    await account.refresh(saves: saves)
                }
            }
        }
    }
}

struct RootView: View {
    @Environment(ContentStore.self) private var content
    @State private var tab = LaunchScript.tab
    @State private var signingIn = LaunchScript.sheet == "signin"
    @State private var scriptedPass = LaunchScript.pass
    @State private var scriptedRoute: RouteTarget?

    var body: some View {
        TabView(selection: $tab) {
            MapTab()
                .tabItem { Label(content.t("appTabMap", "Map"), systemImage: "map") }
                .tag(0)
            ListsTab()
                .tabItem { Label(content.t("listsTitle", "Lists"), systemImage: "list.bullet.clipboard") }
                .tag(1)
            SavedTab()
                .tabItem { Label(content.t("appTabSaved", "Saved"), systemImage: "bookmark") }
                .tag(2)
            MeTab()
                .tabItem { Label(content.t("appTabMe", "Me"), systemImage: "person.crop.circle") }
                .tag(3)
        }
        .sheet(isPresented: $signingIn) { SignInView() }
        .fullScreenCover(item: $scriptedRoute) { RouteView(target: $0) }
        .onAppear {
            if let id = LaunchScript.route, let place = content.place(id) {
                scriptedRoute = RouteTarget(id: place.id, name: place.name, coordinate: place.coordinate)
            }
        }
        .fullScreenCover(isPresented: Binding(get: { scriptedPass != nil }, set: { if !$0 { scriptedPass = nil } })) {
            if let id = scriptedPass, let deal = content.deals.first(where: { $0.id == id }) {
                PassView(deal: deal)
            }
        }
        // The style chosen under Me: its accent on every control, and the
        // system's own dark drawing for the two night styles, so the map,
        // the bars and the keyboard go dark with the page. Last, so the
        // sheets above are inside it: a sheet outside the tint is drawn in
        // the asset catalogue's accent, which is one style's and not this one.
        .tint(Theme.accent)
        .preferredColorScheme(Theme.dark ? .dark : .light)
    }
}
