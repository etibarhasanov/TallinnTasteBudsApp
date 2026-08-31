import CoreLocation
import MapKit
import SwiftUI

/// The map, which is the site's front page and the app's.
///
/// Apple Maps replaces Leaflet and the CARTO tiles here — no key to keep, no
/// watermark to apologise for, and the reader gets the map their phone already
/// knows how to drive.
struct MapScreen: View {
    @Binding var opened: Place?
    @Binding var style: StylePreference

    @Environment(ContentStore.self) private var store
    @Environment(LocationProvider.self) private var location
    @Environment(RadioPlayer.self) private var radio
    @Environment(\.theme) private var theme

    @State private var camera: MapCameraPosition = .region(MapScreen.tallinnRegion)
    /// The pin MapKit says was tapped. Held only for the instant it takes to
    /// turn into an open sheet.
    @State private var selectedID: String?
    /// Whether the map is close enough in to put names beside the pins.
    @State private var showNames = false
    /// How wide a slice of the world is on screen, and how many points wide the
    /// map is drawn — together they say how far apart two pins look, which is
    /// what decides whether they share a dot.
    @State private var visibleSpan = MapScreen.tallinnRegion.span.longitudeDelta
    @State private var mapWidth: Double = 390
    @State private var toast: String?

    /// The site starts labelling at Leaflet zoom 14. On a phone that is a view
    /// roughly two kilometres wide, and at Tallinn's latitude two kilometres of
    /// longitude is about 0.034 degrees — so this is that threshold, expressed
    /// in the units MapKit reports.
    ///
    /// MapKit declutters overlapping titles itself, which is the collision
    /// planning the site has to do by hand.
    static let nameSpan: CLLocationDegrees = 0.034

    static let tallinnRegion = MKCoordinateRegion(
        center: LocationProvider.tallinn,
        span: MKCoordinateSpan(latitudeDelta: 0.09, longitudeDelta: 0.16)
    )

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                map
                controls
                if let toast { toastView(toast) }
            }
            .background(theme.wash)
            .navigationTitle(store.strings("wordmark"))
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: store.lang) { _, lang in
                radio.follow(store.radio?.station(for: lang))
            }
            // A stream fails several seconds after the tap that started it, so
            // the message has to wait for the failure rather than be looked for
            // the instant the button is pressed.
            .onChange(of: radio.failed) { _, failed in
                if failed { show(store.strings("radioFail")) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { languageMenu }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    appearanceMenu
                    radioButton
                }
            }
        }
    }

    private var places: [Place] { store.visiblePlaces(near: location.location) }

    /// Taps are MapKit's job, not a Button's.
    ///
    /// A Button inside an annotation takes the touch that lands on it and keeps
    /// it, so a pinch that happens to start with one finger over a pin never
    /// forms and the map sits still. With seventy-odd pins on screen that is
    /// not an edge case, it is most pinches. Handing selection to MapKit fixes
    /// it at the root: the pin content is inert, MapKit does the hit-testing,
    /// and it already knows the difference between a tap on a pin and the first
    /// finger of a pinch.
    /// What is actually drawn: one dot per group, where a group is usually one
    /// place and sometimes several that would land on top of each other.
    private var groups: [PinCluster.Group] {
        PinCluster.groups(for: places, span: visibleSpan, width: mapWidth)
    }

    private var map: some View {
        Map(position: $camera, selection: $selectedID) {
            ForEach(groups) { group in
                if let place = group.place {
                    Annotation(place.name, coordinate: place.coordinate, anchor: .center) {
                        PinFace(place: place)
                            .accessibilityLabel(store.strings("openPlace", ["name": place.name]))
                    }
                    .tag(group.id)
                    .annotationTitles(showNames ? .visible : .hidden)
                } else {
                    Annotation("", coordinate: group.coordinate, anchor: .center) {
                        ClusterFace(count: group.places.count)
                            .accessibilityLabel(store.strings(
                                "clusterLabel", ["count": String(group.places.count)]))
                    }
                    .tag(group.id)
                    .annotationTitles(.hidden)
                }
            }
            if let here = location.location {
                Annotation(store.strings("locateHere"), coordinate: here.coordinate) {
                    hereDot
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls { MapCompass() }
        .ignoresSafeArea(edges: .bottom)
        .background {
            // How wide the map is drawn decides how far apart two pins look.
            // A GeometryReader behind it rather than onGeometryChange, which
            // arrived in iOS 18 and this app runs from 17.
            GeometryReader { geo in
                Color.clear
                    .onAppear { mapWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, width in mapWidth = width }
            }
        }
        // The site paints its labels on zoomend and moveend rather than during
        // the gesture, and the same restraint suits here: names that appear
        // halfway through a pinch are noise.
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleSpan = context.region.span.longitudeDelta
            showNames = visibleSpan < Self.nameSpan
        }
        .onChange(of: selectedID) { _, id in
            guard let id, let group = groups.first(where: { $0.id == id }) else { return }
            if let place = group.place {
                opened = place
            } else {
                // Zoom in until the group comes apart, which is the only thing
                // a cluster can usefully do when tapped.
                withAnimation {
                    let span = PinCluster.spanThatSplits(group, width: mapWidth)
                    camera = .region(MKCoordinateRegion(
                        center: group.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: span * 0.6, longitudeDelta: span)
                    ))
                }
            }
            // Let go of the selection immediately, so tapping the same pin
            // again after closing the sheet opens it again rather than being
            // a no-op against a selection that never changed.
            selectedID = nil
        }
    }

    /// Deliberately not a pin. The site gives "here" a colour of its own —
    /// blue beside the red places, orange beside the green ones — so that the
    /// one dot that is not a recommendation never reads as one.
    private var hereDot: some View {
        ZStack {
            Circle()
                .fill(theme.here.opacity(0.20))
                .frame(width: 32, height: 32)
            Circle()
                .fill(theme.here)
                .frame(width: 15, height: 15)
            Circle()
                .stroke(theme.paper, lineWidth: 2.5)
                .frame(width: 15, height: 15)
        }
        .allowsHitTesting(false)
        .accessibilityLabel(store.strings("locateHere"))
    }

    private var controls: some View {
        VStack(spacing: 0) {
            FilterChips()
                .background(.thinMaterial)
            Spacer()
            HStack(spacing: 10) {
                actionButton(icon: "die.face.5", label: store.strings("randomPick"), action: surpriseMe)
                actionButton(icon: "location", label: store.strings("locate"), action: locate)
            }
            .padding(.bottom, 18)
        }
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.display(13))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(theme.paper)
                .foregroundStyle(theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    /// The site keeps language and colour in the rail beside the map, because
    /// that is what they change. Same here, rather than a screen away.
    private var languageMenu: some View {
        Menu {
            Picker(store.strings("language"), selection: languageBinding) {
                ForEach(store.strings.languages) { language in
                    Text(language.name).tag(language.code)
                }
            }
        } label: {
            Image(systemName: "globe")
                .accessibilityLabel(store.strings("language"))
        }
    }

    /// Written out rather than taken off `$store` so picking a language also
    /// remembers it — that is what `select(language:)` is for.
    private var languageBinding: Binding<String> {
        Binding(get: { store.lang }, set: { store.select(language: $0) })
    }

    private var appearanceMenu: some View {
        Menu {
            Picker(store.app(.appearance), selection: $style) {
                ForEach(StylePreference.allCases) { option in
                    Text(store.app(option.labelKey)).tag(option)
                }
            }
        } label: {
            Image(systemName: "circle.lefthalf.filled")
                .accessibilityLabel(store.app(.appearance))
        }
    }

    private var radioButton: some View {
        Button {
            radio.toggle(store.radio?.station(for: store.lang))
        } label: {
            Image(systemName: radio.isPlaying ? "stop.circle" : "play.circle")
                .accessibilityLabel(radio.isPlaying ? store.strings("radioStop") : store.strings("radioPlay"))
        }
        .disabled(store.radio?.station(for: store.lang) == nil)
    }

    // MARK: - Actions

    private func surpriseMe() {
        guard let pick = store.randomPick(near: location.location) else {
            show(store.strings("randomNone"))
            return
        }
        withAnimation {
            camera = .region(MKCoordinateRegion(
                center: pick.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
        opened = pick
    }

    private func locate() {
        location.request()
        // The fix arrives asynchronously; wait a beat for it rather than framing
        // the map on a stale one.
        Task {
            for _ in 0..<20 {
                if let here = location.location {
                    if location.isAwayFromTallinn {
                        show(store.strings("locateAway"))
                        withAnimation { camera = .region(Self.tallinnRegion) }
                    } else {
                        withAnimation {
                            camera = .region(MKCoordinateRegion(
                                center: here.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                            ))
                        }
                    }
                    return
                }
                if location.failed { break }
                try? await Task.sleep(for: .milliseconds(150))
            }
            show(store.strings("locateFail"))
        }
    }

    private func show(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(3))
            if toast == message { toast = nil }
        }
    }

    private func toastView(_ message: String) -> some View {
        Text(message)
            .font(.mono(12))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(theme.paper)
            .foregroundStyle(theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
            .padding(.top, 60)
            .transition(.opacity)
            .accessibilityAddTraits(.isStaticText)
    }
}
