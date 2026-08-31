import MapKit
import SwiftUI

/// One place, the way the site's detail panel shows it: photos, the write-up in
/// the reader's language, what to order, and the handful of things you would
/// actually do next — directions, a phone call, the reel, the discount.
struct PlaceDetailView: View {
    let place: Place

    @Environment(ContentStore.self) private var store
    @Environment(Favourites.self) private var favourites
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var web: IdentifiedURL?
    @State private var lightbox: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !place.photos.isEmpty { photos }
                    header
                    if place.closed { closedNote }
                    if let deal = store.deal(for: place) { discount(deal) }
                    actions
                    blurb
                    if !place.mustOrder.isEmpty { mustOrder }
                    facts
                    if place.hasVideo { video }
                    miniMap
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(theme.wash)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { saveButton }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(store.strings("close")) { dismiss() }
                }
            }
        }
        .safariSheet(url: $web)
        .fullScreenCover(item: Binding(
            get: { lightbox.map { PhotoIndex(value: $0) } },
            set: { lightbox = $0?.value }
        )) { start in
            PhotoLightbox(place: place, index: start.value)
                .environment(\.theme, theme)
        }
    }

    // MARK: - Pieces

    private var photos: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.strings("photos").uppercased())
                .font(.mono(10))
                .foregroundStyle(theme.muted)
            photoStrip
        }
    }

    private var photoStrip: some View {
        TabView {
            ForEach(Array(place.photos.enumerated()), id: \.offset) { index, file in
                RemoteImage(url: ContentSource.photoURL(placeID: place.id, file: file))
                    .clipped()
                    .onTapGesture { lightbox = index }
                    .accessibilityLabel(store.strings("photoOf", [
                        "n": String(index + 1), "total": String(place.photos.count)
                    ]))
            }
        }
        .tabViewStyle(.page)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.top, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(place.name)
                .font(.display(26, weight: .bold))
                .foregroundStyle(theme.ink)
            HStack(spacing: 8) {
                PriceGauge(price: place.price, dimmed: place.closed)
                DepthMark(place: place)
            }
            if !store.typeLabels(for: place).isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.strings("types").uppercased())
                        .font(.mono(10))
                        .foregroundStyle(theme.muted)
                    Text(store.typeLabels(for: place).joined(separator: " · "))
                        .font(.running(14))
                        .foregroundStyle(theme.ink)
                }
                .padding(.top, 2)
            }
        }
    }

    private var closedNote: some View {
        Text(store.strings(place.closedNoteKey))
            .font(.mono(12))
            .foregroundStyle(theme.muted)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.hairline)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func discount(_ deal: Deal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.app(.discountOffer).uppercased())
                .font(.mono(10))
                .foregroundStyle(theme.muted)
            Text(deal.offer(in: store.lang))
                .font(.display(17))
                .foregroundStyle(theme.ink)
            Button(store.app(.discountOpen)) {
                // Opened on the site rather than generated here: the code rotates
                // on a clock the staff verifier shares, and two implementations of
                // that would be one too many.
                web = IdentifiedURL(url: ContentSource.dealURL(
                    placeID: place.id,
                    lang: store.lang,
                    darkStyle: colorScheme == .dark
                ))
            }
            .font(.display(14))
            .foregroundStyle(theme.paper)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.paper)
        .overlay {
            RoundedRectangle(cornerRadius: 4).stroke(theme.accent, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var actions: some View {
        HStack(spacing: 10) {
            action(icon: "arrow.triangle.turn.up.right.diamond", title: store.strings("directions")) {
                openDirections()
            }
            if let phone = place.phone, let url = telURL(phone) {
                action(icon: "phone", title: store.strings("call")) { openURL(url) }
            }
            if let site = place.website {
                action(icon: "safari", title: store.strings("website")) { web = IdentifiedURL(url: site) }
            }
        }
    }

    private func action(icon: String, title: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 17))
                Text(title).font(.mono(10)).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(theme.paper)
            .foregroundStyle(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private var blurb: some View {
        Text(place.blurb(in: store.lang))
            .font(.running(17))
            .foregroundStyle(theme.ink)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var mustOrder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.strings("mustOrder").uppercased())
                .font(.mono(10))
                .foregroundStyle(theme.muted)
            ForEach(place.mustOrder, id: \.self) { dish in
                Text("— " + dish)
                    .font(.running(16))
                    .foregroundStyle(theme.ink)
            }
        }
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 10) {
            fact(store.strings("address"), place.address)
            if let phone = place.phone { fact(store.strings("phone"), phone) }
            if let visited = place.visited { fact(store.strings("visited"), store.strings.monthYear(visited)) }
            if place.reel == nil {
                Text(store.strings("notFilmed"))
                    .font(.mono(11))
                    .foregroundStyle(theme.muted)
            }
        }
        .padding(.top, 4)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.mono(10)).foregroundStyle(theme.muted)
            Text(value).font(.running(15)).foregroundStyle(theme.ink)
        }
    }

    private var video: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.strings(place.isTikTok ? "video" : "reel").uppercased())
                .font(.mono(10))
                .foregroundStyle(theme.muted)
            videoButton
        }
    }

    private var videoButton: some View {
        Button {
            if let reel = place.reel { web = IdentifiedURL(url: reel) }
        } label: {
            Label(
                place.isTikTok ? store.strings("videoPlay") : store.strings("reelPlay"),
                systemImage: "play.rectangle"
            )
            .font(.display(14))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(theme.paper)
            .foregroundStyle(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    /// A still of where it is. Tapping it hands over to Maps, which is the only
    /// thing anyone wants from a map this small.
    private var miniMap: some View {
        Button {
            openDirections()
        } label: {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: place.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
            )), interactionModes: []) {
                Marker(place.name, coordinate: place.coordinate)
                    .tint(theme.accent)
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .allowsHitTesting(false)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.strings("directions"))
    }

    private var saveButton: some View {
        Button {
            favourites.toggle(place)
        } label: {
            Image(systemName: favourites.contains(place) ? "bookmark.fill" : "bookmark")
                .accessibilityLabel(favourites.contains(place) ? store.app(.saved) : store.app(.save))
        }
    }

    // MARK: - Helpers

    private func telURL(_ phone: String) -> URL? {
        URL(string: "tel://" + phone.filter { $0.isNumber || $0 == "+" })
    }

    private func openDirections() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        item.name = place.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

private struct PhotoIndex: Identifiable {
    let value: Int
    var id: Int { value }
}

/// Full-screen photos, the site's lightbox.
struct PhotoLightbox: View {
    let place: Place
    let index: Int

    @Environment(ContentStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var current: Int = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $current) {
                ForEach(Array(place.photos.enumerated()), id: \.offset) { offset, file in
                    RemoteImage(url: ContentSource.photoURL(placeID: place.id, file: file), contentMode: .fit)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page)
            .ignoresSafeArea()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .padding(14)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(20)
            .accessibilityLabel(store.strings("photoClose"))

            VStack {
                Spacer()
                Text(store.strings("photoOf", [
                    "n": String(current + 1), "total": String(place.photos.count)
                ]))
                .font(.mono(11))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.bottom, 30)
            }
        }
        .onAppear { current = index }
    }
}
