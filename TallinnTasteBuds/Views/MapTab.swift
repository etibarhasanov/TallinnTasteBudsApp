import SwiftUI
import MapKit

/// The first tab: every place on Apple's map, with the website's search and
/// filter chips over it, and the places as a list a button away.
///
/// The search is the city's, the way a maps app does it. While you type,
/// suggestions drop under the field: the places on this map first, then
/// everywhere in Tallinn, which the website answers from `/api/places?q=` —
/// the same search its own pages use, so a word finds the same places here
/// and there. Press a suggestion and the map goes to that one place. Press
/// Search and every result is drawn at once, the map's own as the mark and
/// the rest of the city as plain dots; move the map and Search this area
/// asks again for the part on screen. Empty the field and the map is the one
/// that opens. Offline, the places the app carries still answer.
struct MapTab: View {
    @Environment(ContentStore.self) private var content
    @Environment(SavesStore.self) private var saves
    @Environment(LocationProvider.self) private var location

    @State private var path = NavigationPath(LaunchScript.routes(tab: 0))
    @State private var query = LaunchScript.query ?? ""
    @State private var type: String? = LaunchScript.type
    @State private var selected: String? = LaunchScript.select
    @State private var showingList = false
    @State private var camera: MapCameraPosition = .region(MapTab.tallinn)

    /// What the site answered for the field, and whether it is still being
    /// asked or could not be reached.
    @State private var found: [CatalogueHit] = []
    @State private var asking = false
    @State private var unreachable = false
    /// The city's places drawn on the map: one after a suggestion is pressed,
    /// all of them after Search.
    @State private var drawn: [CatalogueHit] = []
    /// What the map shows, where it stood when the results were drawn, and
    /// whether it has been moved since — which is when Search this area shows.
    @State private var region: MKCoordinateRegion?
    @State private var settled: MKCoordinateRegion?
    @State private var moved = false
    @FocusState private var typing: Bool

    static let tallinn = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 59.437, longitude: 24.745),
        span: MKCoordinateSpan(latitudeDelta: 0.07, longitudeDelta: 0.11)
    )

    private var typed: String { query.trimmingCharacters(in: .whitespaces) }

    /// The map's own places the field and the chip leave: the ones the app
    /// finds in what it carries, and any more the site's search reached —
    /// by a kind said in another language, or a typing slip.
    private var visible: [Place] {
        let local = content.filtered(query: query, type: type)
        guard !typed.isEmpty, type == nil else { return local }
        let have = Set(local.map(\.id))
        let more = found
            .filter { $0.map && !have.contains($0.id) }
            .compactMap { content.place($0.id) }
            .filter { !$0.closed }
        return local + more
    }

    /// The rest of the city in the site's answer, less any with no point to
    /// put a pin on.
    private var city: [CatalogueHit] { found.filter { !$0.map && $0.coordinate != nil } }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                map
                VStack(spacing: 10) {
                    SearchField(text: $query, prompt: content.t("findPlaceholder", "Find anywhere in Tallinn"),
                                focus: $typing, submit: showAll)
                        .padding(.horizontal, 16)
                    if typing && !typed.isEmpty {
                        suggestions.padding(.horizontal, 16)
                    } else {
                        ChipRow(selected: $type)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        LocateButton(camera: $camera)
                    }
                    .padding(.horizontal, 14)
                    bottom
                }
                .padding(.top, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
            .withRoutes()
            .sheet(isPresented: $showingList) {
                PlacesSheet(places: visible, city: drawn) { id in
                    showingList = false
                    path.append(Route.place(id))
                } openCity: { hit in
                    showingList = false
                    go(to: hit)
                }
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                location.start()
                if LaunchScript.typing { typing = true }
            }
            .onChange(of: query) { _, _ in
                if typed.isEmpty {
                    found = []
                    drawn = []
                    unreachable = false
                    moved = false
                }
                deselectIfHidden()
            }
            .onChange(of: type) { _, _ in deselectIfHidden() }
            // A third of a second after the last letter, from two letters:
            // the pause the list picker takes before asking the same route.
            .task(id: query) {
                let q = typed
                guard q.count >= 2 else { asking = false; return }
                asking = true
                try? await Task.sleep(for: .milliseconds(300))
                if Task.isCancelled { return }
                await ask(q, in: nil)
                if LaunchScript.query != nil && !LaunchScript.typing { showAll() }
            }
        }
    }

    private var map: some View {
        // Pressing a pin goes through MapKit's own selection rather than a
        // tap gesture on the pin: a gesture on the map as well, to clear the
        // selection, swallows the pin's on iOS 17, and the map's selection
        // already clears itself when the empty map is pressed.
        Map(position: $camera, selection: $selected) {
            UserAnnotation()
            ForEach(visible) { place in
                Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                    PlacePin(selected: place.id == selected)
                }
                .annotationTitles(.hidden)
                .tag(place.id)
            }
            ForEach(drawn) { hit in
                Annotation(hit.name, coordinate: hit.coordinate ?? MapTab.tallinn.center, anchor: .center) {
                    CityPin(selected: hit.id == selected)
                }
                .annotationTitles(.hidden)
                .tag(hit.id)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        // The blue dot is the app's tint; left to the accent it drew you
        // in brick red, the colour of a pin, beside a blue route.
        .tint(Theme.here)
        .mapControls {
            // MapKit's own locate button sits in the top corner, under the
            // search field, which is why nobody could find it; LocateButton
            // stands at the bottom right instead, the website's corner.
            MapCompass()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            region = context.region
            // The first stop after the app moved the map is where it settled;
            // any stop far enough from that is the reader's own move.
            guard let from = settled else { settled = context.region; return }
            if Self.apart(from, context.region) { moved = true }
        }
        .animation(.snappy, value: selected)
    }

    /// The suggestions under the field: up to three of the map's own, then
    /// the city's, and one line saying what is happening when it needs saying.
    private var suggestions: some View {
        let mine = Array(visible.prefix(3))
        let rest = Array(city.prefix(8))
        let rows = VStack(alignment: .leading, spacing: 0) {
            if !mine.isEmpty {
                SuggestionGroup(title: content.t("findOnMap", "On the map"))
                ForEach(mine) { place in
                    Button { go(to: place) } label: {
                        SuggestionRow(mine: true, name: place.name, detail: place.address,
                                      far: Distance.text(location.distance(to: place.location)))
                    }
                    .buttonStyle(.plain)
                }
            }
            if !rest.isEmpty {
                SuggestionGroup(title: content.t("findInCity", "Everywhere in Tallinn"))
                ForEach(rest) { hit in
                    Button { go(to: hit) } label: {
                        SuggestionRow(mine: false, name: hit.name, detail: hit.address, far: far(hit))
                    }
                    .buttonStyle(.plain)
                }
            }
            if let note = note(empty: mine.isEmpty && rest.isEmpty, waiting: rest.isEmpty) {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // As tall as its rows, and scrolling once they would run under the
        // keyboard.
        return ViewThatFits(in: .vertical) {
            rows
            ScrollView { rows }
        }
        .frame(maxHeight: 330)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.16), radius: 12, y: 5)
    }

    /// The one line under the suggestions: still asking, could not ask, or
    /// nothing anywhere. Nil when the rows say it all.
    private func note(empty: Bool, waiting: Bool) -> String? {
        if typed.count < 2 { return empty ? content.t("searchNone", "Nothing matches “{q}”.", ["q": typed]) : nil }
        if asking && waiting { return content.t("findLooking", "Looking everywhere…") }
        if unreachable { return content.t("appCityUnreachable", "Can’t reach the rest of Tallinn right now.") }
        if empty { return content.t("searchNone", "Nothing matches “{q}”.", ["q": typed]) }
        return nil
    }

    private func far(_ hit: CatalogueHit) -> String {
        guard let lat = hit.lat, let lng = hit.lng else { return "" }
        return Distance.text(location.distance(to: CLLocation(latitude: lat, longitude: lng)))
    }

    @ViewBuilder
    private var bottom: some View {
        if let id = selected, let place = content.place(id) {
            PlaceCard(place: place) { path.append(Route.place(place.id)) }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let id = selected, let hit = drawn.first(where: { $0.id == id }) {
            CityCard(hit: hit, far: far(hit)) { path.append(Route.venue(ListItem(hit: hit))) }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            VStack(spacing: 10) {
                if moved && !drawn.isEmpty && !typing {
                    Button { searchHere() } label: {
                        Label(content.t("findAreaButton", "Search this area"), systemImage: "magnifyingglass")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 11)
                            .background(Theme.accent, in: Capsule())
                            .foregroundStyle(Theme.onAccent)
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                    }
                }
                if visible.isEmpty && drawn.isEmpty {
                    Text(typed.isEmpty
                         ? content.t("noResults", "Nothing matches those filters yet.")
                         : content.t("searchNone", "Nothing matches “{q}”.", ["q": typed]))
                        .font(.subheadline)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Theme.paper, in: Capsule())
                } else {
                    Button {
                        showingList = true
                    } label: {
                        Label("\(content.t("listOpen", "Places")) · \(visible.count + drawn.count)", systemImage: "list.bullet")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 11)
                            .background(Theme.paper, in: Capsule())
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                    }
                    .foregroundStyle(Theme.ink)
                }
            }
            .padding(.bottom, 14)
        }
    }

    // MARK: Asking the site

    /// The site's answer for these words, over the whole city or the part of
    /// it in `box`. A failure leaves the last answer standing and says so; a
    /// search the next letter cancelled says nothing.
    private func ask(_ q: String, in box: MKCoordinateRegion?) async {
        var params = ["q": q, "limit": "40"]
        if let box {
            let south = box.center.latitude - box.span.latitudeDelta / 2
            let north = box.center.latitude + box.span.latitudeDelta / 2
            let west = box.center.longitude - box.span.longitudeDelta / 2
            let east = box.center.longitude + box.span.longitudeDelta / 2
            params["bbox"] = [south, west, north, east].map { String(format: "%.5f", $0) }.joined(separator: ",")
        }
        do {
            let hits = try await API.get([CatalogueHit].self, "api/places", params)
            if Task.isCancelled { return }
            found = hits
            unreachable = false
        } catch {
            if Task.isCancelled { return }
            unreachable = true
        }
        asking = false
    }

    // MARK: What a press does

    /// A place of the map's own, pressed among the suggestions.
    private func go(to place: Place) {
        typing = false
        selected = place.id
        fly(to: place.coordinate)
    }

    /// One of the city's, pressed among the suggestions or in the list: its
    /// dot goes on the map, alone unless it is already among the ones drawn.
    private func go(to hit: CatalogueHit) {
        guard let point = hit.coordinate else { return }
        typing = false
        if !drawn.contains(hit) { drawn = [hit] }
        selected = hit.id
        fly(to: point)
    }

    /// Search: every result on the map at once, framed.
    private func showAll() {
        typing = false
        selected = nil
        drawn = city
        let points = visible.map(\.coordinate) + drawn.compactMap(\.coordinate)
        guard let first = points.first else { return }
        var south = first.latitude, north = first.latitude, west = first.longitude, east = first.longitude
        for p in points {
            south = min(south, p.latitude); north = max(north, p.latitude)
            west = min(west, p.longitude); east = max(east, p.longitude)
        }
        move(to: MKCoordinateRegion(
            center: .init(latitude: (south + north) / 2, longitude: (west + east) / 2),
            span: .init(latitudeDelta: max(0.01, (north - south) * 1.4), longitudeDelta: max(0.01, (east - west) * 1.4))
        ))
    }

    /// Search this area: the same words, held to what the map is showing.
    private func searchHere() {
        guard let box = region, typed.count >= 2 else { return }
        moved = false
        settled = box
        Task {
            await ask(typed, in: box)
            drawn = city
        }
    }

    private func fly(to point: CLLocationCoordinate2D) {
        move(to: MKCoordinateRegion(center: point, span: .init(latitudeDelta: 0.012, longitudeDelta: 0.012)))
    }

    /// A move the app makes, which is not the reader moving the map.
    private func move(to region: MKCoordinateRegion) {
        settled = nil
        moved = false
        withAnimation(.snappy) { camera = .region(region) }
    }

    /// Whether two views of the map differ by enough to be a different place:
    /// a quarter of the screen across, or half as close again.
    private static func apart(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
        abs(a.center.latitude - b.center.latitude) > a.span.latitudeDelta / 4
            || abs(a.center.longitude - b.center.longitude) > a.span.longitudeDelta / 4
            || b.span.latitudeDelta > a.span.latitudeDelta * 1.5
            || b.span.latitudeDelta < a.span.latitudeDelta / 1.5
    }

    private func deselectIfHidden() {
        guard let id = selected else { return }
        if !visible.contains(where: { $0.id == id }) && !drawn.contains(where: { $0.id == id }) { selected = nil }
    }
}

/// A heading among the suggestions: "On the map", "Everywhere in Tallinn".
struct SuggestionGroup: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .kerning(0.8)
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
}

/// One suggestion: the mark for a place on the map and a plain dot for the
/// rest of the city, its name, its street, and how far.
struct SuggestionRow: View {
    let mine: Bool
    let name: String
    let detail: String
    let far: String

    var body: some View {
        HStack(spacing: 10) {
            if mine {
                Mark(size: 30).clipShape(Circle())
            } else {
                Circle().fill(Theme.wash).frame(width: 30, height: 30)
                    .overlay(Circle().fill(Theme.muted).frame(width: 10, height: 10))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.body.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                if !detail.isEmpty {
                    Text(detail).font(.footnote).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(far).font(.footnote).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

/// A place in the city that is not on this map: a plain dot, so the mark
/// stays the sign of somewhere with a write-up.
struct CityPin: View {
    var selected: Bool

    var body: some View {
        Circle()
            .fill(selected ? Theme.ink : Theme.muted)
            .frame(width: selected ? 24 : 14, height: selected ? 24 : 14)
            .overlay(Circle().stroke(.white, lineWidth: selected ? 3 : 2))
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            // A finger is wider than a fourteen-point dot.
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
            .animation(.snappy, value: selected)
    }
}

/// The card that rises for a place in the city: what Google calls it, where
/// it is, and that it is not one of the map's own.
struct CityCard: View {
    @Environment(ContentStore.self) private var content
    let hit: CatalogueHit
    let far: String
    let open: () -> Void
    @State private var route: RouteTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(hit.name).font(.headline).foregroundStyle(Theme.ink).lineLimit(2)
                    Text([hit.category, far].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(Theme.muted).lineLimit(1)
                    if !hit.address.isEmpty {
                        Text(hit.address).font(.footnote).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                    Text(content.t("appNotOnMap", "Not on the Tallinn Tastebuds map"))
                        .font(.footnote).foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                if let point = hit.coordinate {
                    Button {
                        route = RouteTarget(id: hit.id, name: hit.name, coordinate: point)
                    } label: {
                        Text(content.t("directions", "Directions")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.prominent)
                }
                Button(action: open) {
                    Text(content.t("appOpen", "Open")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
        .padding(14)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
        .fullScreenCover(item: $route) { RouteView(target: $0) }
    }
}

/// The search box over the map: the site's own placeholder, a clear button,
/// and the keyboard's Search key.
struct SearchField: View {
    @Binding var text: String
    let prompt: String
    var focus: FocusState<Bool>.Binding
    var submit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused(focus)
                .onSubmit(submit)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

/// "All" and then every kind of place on the site's chip row.
struct ChipRow: View {
    @Environment(ContentStore.self) private var content
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(content.t("filterAll", "All"), on: selected == nil) { selected = nil }
                // First after All, and only while some place has a discount
                // switched on — the website's rule for the same chip.
                if !content.liveDeals.isEmpty {
                    let id = ContentStore.discountChip
                    chip(content.t("filterDiscount", "Discount"), on: selected == id) {
                        selected = (selected == id) ? nil : id
                    }
                }
                ForEach(content.chips) { t in
                    chip(t.name(content.lang), on: selected == t.id) {
                        selected = (selected == t.id) ? nil : t.id
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func chip(_ title: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(on ? Theme.accent : Theme.paper, in: Capsule())
                .foregroundStyle(on ? Theme.onAccent : Theme.ink)
                .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

/// The website's mark, on a stem, for every place on the map.
struct PlacePin: View {
    var selected: Bool

    var body: some View {
        VStack(spacing: 0) {
            Mark(size: selected ? 42 : 30)
                .overlay(Circle().stroke(.white, lineWidth: selected ? 3 : 2))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            Rectangle().fill(.white).frame(width: 2, height: selected ? 8 : 5)
        }
        .animation(.snappy, value: selected)
    }
}

/// The card that rises when a pin is pressed.
struct PlaceCard: View {
    @Environment(ContentStore.self) private var content
    @Environment(SavesStore.self) private var saves
    let place: Place
    let open: () -> Void
    @State private var route: RouteTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: open) { PlaceRow(place: place) }
                .buttonStyle(.plain)
            HStack(spacing: 8) {
                Button(action: open) {
                    Text(content.t("appOpen", "Open")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.prominent)
                Button {
                    route = RouteTarget(id: place.id, name: place.name, coordinate: place.coordinate)
                } label: {
                    Text(content.t("directions", "Directions")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button {
                    saves.toggle(place.id)
                } label: {
                    Image(systemName: saves.isSaved(place.id) ? "heart.fill" : "heart")
                        .frame(width: 30)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(content.t("savePlace", "Save this place"))
            }
            .controlSize(.large)
        }
        .padding(14)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
        .fullScreenCover(item: $route) { RouteView(target: $0) }
    }
}

/// A place in a row: photo, name, what kind, how dear, how far.
struct PlaceRow: View {
    @Environment(ContentStore.self) private var content
    @Environment(LocationProvider.self) private var location
    let place: Place
    var thumb: CGFloat = 64

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let url = place.photoURLs.first {
                    Photo(url: url)
                } else {
                    Theme.wash.overlay(Mark(size: thumb * 0.5).opacity(0.9))
                }
            }
            .frame(width: thumb, height: thumb)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(place.name).font(.headline).foregroundStyle(Theme.ink).lineLimit(2)
                    if let deal = content.deal(place.id) {
                        DealPill(text: deal.badge(content.lang) ?? content.t("filterDiscount", "Discount"))
                    }
                }
                Text(subtitle).font(.subheadline).foregroundStyle(Theme.muted).lineLimit(1)
                if !place.address.isEmpty {
                    Text(place.address).font(.footnote).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        // The kind worth naming first is the most specific one: "Asian" says
        // more than "Restaurant", which is why the general ones go last.
        let general: Set<String> = ["restaurant", "casual", "hidden-gem", "cheap-eats", "date", "laptop"]
        let ordered = place.types.sorted { (general.contains($0) ? 1 : 0) < (general.contains($1) ? 1 : 0) }
        var parts: [String] = []
        if let first = ordered.first, let t = content.type(first) { parts.append(t.name(content.lang)) }
        if let p = place.priceText { parts.append(p) }
        parts.append(Distance.text(location.distance(to: place.location)))
        return parts.joined(separator: " · ")
    }
}

/// Every place the map is showing, nearest first: the map's own, and under
/// them the city's places a search drew.
struct PlacesSheet: View {
    @Environment(ContentStore.self) private var content
    @Environment(LocationProvider.self) private var location
    let places: [Place]
    var city: [CatalogueHit] = []
    let open: (String) -> Void
    var openCity: (CatalogueHit) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sorted) { place in
                    Button { open(place.id) } label: { PlaceRow(place: place, thumb: 56) }
                        .listRowBackground(Theme.paper)
                }
                if !city.isEmpty {
                    Section(content.t("findInCity", "Everywhere in Tallinn")) {
                        ForEach(city) { hit in
                            Button { openCity(hit) } label: {
                                SuggestionRow(mine: false, name: hit.name, detail: hit.address, far: far(hit))
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Theme.paper)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .paperBackground()
            .navigationTitle(content.t("listOpen", "Places"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                Text(location.isReal ? content.t("listNearYou", "Nearest you") : content.t("listNearOldTown", "Nearest the Old Town"))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(Theme.paper)
            }
        }
    }

    private var sorted: [Place] {
        places.sorted { location.distance(to: $0.location) < location.distance(to: $1.location) }
    }

    private func far(_ hit: CatalogueHit) -> String {
        guard let lat = hit.lat, let lng = hit.lng else { return "" }
        return Distance.text(location.distance(to: CLLocation(latitude: lat, longitude: lng)))
    }
}
