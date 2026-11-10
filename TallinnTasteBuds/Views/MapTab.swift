import SwiftUI
import MapKit

/// The first tab: every place on Apple's map, with the website's search and
/// filter chips over it, and the places as a list a button away.
struct MapTab: View {
    @Environment(ContentStore.self) private var content
    @Environment(SavesStore.self) private var saves
    @Environment(LocationProvider.self) private var location

    @State private var path = NavigationPath(LaunchScript.routes(tab: 0))
    @State private var query = ""
    @State private var type: String? = LaunchScript.type
    @State private var selected: String? = LaunchScript.select
    @State private var showingList = false
    @State private var camera: MapCameraPosition = .region(MapTab.tallinn)

    static let tallinn = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 59.437, longitude: 24.745),
        span: MKCoordinateSpan(latitudeDelta: 0.07, longitudeDelta: 0.11)
    )

    private var visible: [Place] { content.filtered(query: query, type: type) }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                map
                VStack(spacing: 10) {
                    SearchField(text: $query, prompt: content.t("search", "Search places"))
                        .padding(.horizontal, 16)
                    ChipRow(selected: $type)
                    Spacer()
                    bottom
                }
                .padding(.top, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
            .withRoutes()
            .sheet(isPresented: $showingList) {
                PlacesSheet(places: visible) { id in
                    showingList = false
                    path.append(Route.place(id))
                }
                .presentationDetents([.medium, .large])
            }
            .onAppear { location.start() }
            .onChange(of: query) { _, _ in deselectIfHidden() }
            .onChange(of: type) { _, _ in deselectIfHidden() }
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
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .animation(.snappy, value: selected)
    }

    @ViewBuilder
    private var bottom: some View {
        if let id = selected, let place = content.place(id) {
            PlaceCard(place: place) { path.append(Route.place(place.id)) }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            HStack {
                if visible.isEmpty {
                    Text(content.t("noResults", "Nothing matches those filters yet."))
                        .font(.subheadline)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Theme.paper, in: Capsule())
                } else {
                    Button {
                        showingList = true
                    } label: {
                        Label("\(content.t("listOpen", "Places")) · \(visible.count)", systemImage: "list.bullet")
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

    private func deselectIfHidden() {
        if let id = selected, !visible.contains(where: { $0.id == id }) { selected = nil }
    }
}

/// The search box over the map: the site's own placeholder, a clear button.
struct SearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
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
                .foregroundStyle(on ? .white : Theme.ink)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: open) { PlaceRow(place: place) }
                .buttonStyle(.plain)
            HStack(spacing: 8) {
                Button(action: open) {
                    Text(content.t("appOpen", "Open")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    Directions.open(name: place.name, coordinate: place.coordinate)
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

/// Every place the map is showing, nearest first.
struct PlacesSheet: View {
    @Environment(ContentStore.self) private var content
    @Environment(LocationProvider.self) private var location
    let places: [Place]
    let open: (String) -> Void

    var body: some View {
        NavigationStack {
            List(sorted) { place in
                Button { open(place.id) } label: { PlaceRow(place: place, thumb: 56) }
                    .listRowBackground(Theme.paper)
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
}
