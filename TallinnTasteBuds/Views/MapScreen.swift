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
    @State private var toast: String?

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

    private var map: some View {
        Map(position: $camera) {
            ForEach(places) { place in
                Annotation(place.name, coordinate: place.coordinate, anchor: .center) {
                    pin(for: place)
                }
                .annotationTitles(.hidden)
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
        .accessibilityLabel(store.strings("locateHere"))
    }

    private func pin(for place: Place) -> some View {
        Button {
            opened = place
        } label: {
            ZStack {
                Circle()
                    .fill(place.closed ? theme.muted : theme.accent)
                    .frame(width: 16, height: 16)
                Circle()
                    .stroke(theme.paper, lineWidth: 2.5)
                    .frame(width: 16, height: 16)
                if store.deal(for: place) != nil {
                    Circle()
                        .stroke(theme.accentLit, lineWidth: 2)
                        .frame(width: 26, height: 26)
                }
            }
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.strings("openPlace", ["name": place.name]))
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
                    Text(option.label(store.strings)).tag(option)
                }
            }
        } label: {
            Image(systemName: "circle.lefthalf.filled")
                .accessibilityLabel(store.app(.appearance))
        }
    }

    private var radioButton: some View {
        Button {
            let station = store.radio?.station(for: store.lang)
            radio.toggle(station)
            if radio.failed { show(store.strings("radioFail")) }
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
