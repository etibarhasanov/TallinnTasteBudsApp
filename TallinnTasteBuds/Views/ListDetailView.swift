import SwiftUI
import MapKit

/// One list, read: its places in its author's order with what they wrote
/// about each, and the same list as numbered pins on a map.
struct ListDetailView: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account
    let id: String

    @State private var list: ListDetail?
    @State private var editing = false
    @State private var signingIn = false
    @State private var kept: Bool?
    @State private var keeps: Int?
    @State private var failed = false
    @State private var gone = false
    @State private var showMap = LaunchScript.listMap
    /// The place pressed on the page, which the map opens on.
    @State private var focus: String? = LaunchScript.listFocus

    var body: some View {
        Group {
            if let list {
                VStack(spacing: 0) {
                    Picker("", selection: $showMap) {
                        Text(content.t("listsViewList", "List")).tag(false)
                        Text(content.t("listsViewMap", "Map")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    if showMap {
                        ListMap(list: list, focus: focus)
                    } else {
                        // Pressing a place on the page goes to the map, on
                        // that place, rather than off the list: a list is
                        // read to decide where to go, and where it is is the
                        // next question. Its card on the map opens the place.
                        ListPage(list: list, keepsNow: keeps) { item in
                            focus = item.id
                            withAnimation(.snappy) { showMap = true }
                        }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        ShareLink(item: API.listLink(list.id), subject: Text(list.title)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        if list.mine {
                            Button(content.t("appEdit", "Edit")) { editing = true }
                        } else {
                            Button {
                                Task { await toggleKeep(list) }
                            } label: {
                                Image(systemName: (kept ?? list.kept) ? "heart.fill" : "heart")
                            }
                            .accessibilityLabel(content.t("listsKeep", "Save"))
                        }
                    }
                }
                .fullScreenCover(isPresented: $editing) {
                    ListEditor(list: list, isPublic: list.isPublic) { Task { await load() } }
                }
                .sheet(isPresented: $signingIn) {
                    SignInView(reason: content.t("listsKeepIn", "Sign in to save this list"))
                }
            } else if gone {
                EmptyNote(title: content.t("appListGone", "This list is gone"),
                          text: content.t("appListGoneSay", "Its author deleted it or made it private."),
                          systemImage: "list.bullet.clipboard")
            } else if failed {
                VStack(spacing: 10) {
                    Text(content.t("appOffline", "Couldn’t reach tallinntastebuds.ee.")).foregroundStyle(Theme.muted)
                    Button(content.t("appRetry", "Try again")) { Task { await load() } }
                }
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task { if list == nil { await load() } }
    }

    /// Saving somebody else's list needs an account; signed out, the heart
    /// asks for one at the moment somebody has decided they want the list.
    private func toggleKeep(_ list: ListDetail) async {
        guard account.signedIn else { signingIn = true; return }
        let on = !(kept ?? list.kept)
        kept = on
        do {
            keeps = try await account.keep(list.id, on)
        } catch {
            kept = !on
        }
    }

    private func load() async {
        failed = false
        do {
            let envelope = try await API.get(ListEnvelope.self, "api/lists", ["id": id])
            if let l = envelope.list {
                list = l
                if LaunchScript.edit == l.id { editing = true }
            } else {
                gone = true
            }
        } catch API.Failure.notFound {
            gone = true
        } catch {
            failed = true
        }
    }
}

/// The list as a page you read down.
private struct ListPage: View {
    @Environment(ContentStore.self) private var content
    let list: ListDetail
    /// The count after a save pressed here, before the list is read again.
    var keepsNow: Int?
    /// A place pressed: show it on the list's map.
    let pick: (ListItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(list.title).font(.title.bold()).foregroundStyle(Theme.ink)
                    HStack(spacing: 4) {
                        if let by = list.by {
                            NavigationLink(value: Route.profile(by)) {
                                Text(by).fontWeight(.semibold).foregroundStyle(Theme.ink)
                            }
                            Text("·").foregroundStyle(Theme.muted)
                        }
                        Text(counts).foregroundStyle(Theme.muted)
                    }
                    .font(.subheadline)
                    if !list.intro.isEmpty {
                        Text(list.intro).font(.body).foregroundStyle(Theme.ink).padding(.top, 4)
                    }
                }
                .padding(16)

                if list.items.isEmpty {
                    Text(content.t("listsEmpty", "Nothing on this list yet."))
                        .foregroundStyle(Theme.muted).padding(16)
                }
                ForEach(Array(list.items.enumerated()), id: \.element.id) { index, item in
                    Divider().overlay(Theme.hairline)
                    if item.coordinate != nil {
                        Button { pick(item) } label: {
                            ListItemRow(number: index + 1, item: item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Nowhere to put it on a map: straight to its page.
                        NavigationLink(value: route(for: item)) {
                            ListItemRow(number: index + 1, item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var counts: String {
        var parts = [content.t("appPlacesN", "{n} places", ["n": "\(list.items.count)"])]
        let keeps = keepsNow ?? list.keeps
        if keeps == 1 { parts.append(content.t("listsKeptOne", "saved by 1 person")) }
        if keeps > 1 { parts.append(content.t("listsKeptN", "saved by {n} people", ["n": "\(keeps)"])) }
        if !list.isPublic { parts.append(content.t("appPrivate", "Only you")) }
        return parts.joined(separator: " · ")
    }

    private func route(for item: ListItem) -> Route {
        if item.map, content.place(item.place) != nil { return .place(item.place) }
        return .venue(item)
    }
}

/// One numbered place on a list.
struct ListItemRow: View {
    @Environment(ContentStore.self) private var content
    let number: Int
    let item: ListItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.title3.bold())
                .foregroundStyle(Theme.accent)
                .frame(width: 26, alignment: .leading)
            thumb
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.headline).foregroundStyle(Theme.ink)
                if !item.map {
                    Text(content.t("appNotOnMapShort", "Not on the map"))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.hairline))
                }
                if !item.say.isEmpty {
                    Text(item.say).font(.subheadline).foregroundStyle(Theme.ink)
                }
                if !item.mustOrder.isEmpty {
                    (Text(content.t("mustOrder", "Must order") + ": ").foregroundStyle(Theme.muted)
                     + Text(item.mustOrder).fontWeight(.semibold).foregroundStyle(Theme.ink))
                        .font(.footnote)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Theme.hairline).padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumb: some View {
        if item.map, let place = content.place(item.place), let url = place.photoURLs.first {
            Photo(url: url)
        } else if item.map {
            Theme.wash.overlay(Mark(size: 26))
        } else {
            Theme.wash.overlay(Image(systemName: "fork.knife").foregroundStyle(Theme.muted))
        }
    }
}

/// The list as pins, numbered in the author's order and wearing the list's
/// own marker, with the pressed one's card at the bottom.
private struct ListMap: View {
    @Environment(ContentStore.self) private var content
    let list: ListDetail
    /// The place to open on, pressed on the list's page; nil frames them all.
    var focus: String?

    @State private var selected: String?
    @State private var camera: MapCameraPosition = .automatic
    /// False until the selection made on the way in has gone by, so that one
    /// does not move the map: opening on the whole list frames them all.
    @State private var settled = false

    private struct Pinned: Identifiable {
        let number: Int
        let item: ListItem
        let coordinate: CLLocationCoordinate2D
        var id: String { item.id }
    }

    private var placed: [Pinned] {
        list.items.enumerated().compactMap { i, item in
            item.coordinate.map { Pinned(number: i + 1, item: item, coordinate: $0) }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $camera, selection: $selected) {
                UserAnnotation()
                ForEach(placed) { pin in
                    Annotation(pin.item.name, coordinate: pin.coordinate, anchor: .center) {
                        NumberedPin(emoji: Pins.of(list.pin), number: pin.number, selected: selected == pin.id)
                    }
                    .annotationTitles(.hidden)
                    .tag(pin.id)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            // The blue dot is the app's tint; left to the accent it drew you
            // in brick red, the colour of a pin, beside a blue route.
            .tint(Theme.here)

            VStack(alignment: .trailing, spacing: 12) {
                LocateButton(camera: $camera).padding(.trailing, 14)
                card
            }
        }
        .onAppear {
            if let focus, let pin = placed.first(where: { $0.id == focus }) {
                selected = pin.id
                camera = .region(MKCoordinateRegion(center: pin.coordinate, latitudinalMeters: 700, longitudinalMeters: 700))
            } else if selected == nil {
                selected = placed.first?.id
            }
        }
        .onChange(of: selected) { _, id in
            // Pressing a pin brings it to the middle, the way the list's
            // press does, so the card and the pin are seen together.
            guard settled else { settled = true; return }
            guard let id, let pin = placed.first(where: { $0.id == id }) else { return }
            withAnimation(.easeInOut) {
                camera = .region(MKCoordinateRegion(center: pin.coordinate, latitudinalMeters: 900, longitudinalMeters: 900))
            }
        }
    }

    @ViewBuilder
    private var card: some View {
        if let id = selected, let found = placed.first(where: { $0.id == id }) {
            NavigationLink(value: route(for: found.item)) {
                ListItemRow(number: found.number, item: found.item)
                    .padding(.vertical, 4)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private func route(for item: ListItem) -> Route {
        if item.map, content.place(item.place) != nil { return .place(item.place) }
        return .venue(item)
    }
}

/// A list's marker in a paper circle, with its number on a red badge.
struct NumberedPin: View {
    let emoji: String
    let number: Int
    var selected = false

    var body: some View {
        let size: CGFloat = selected ? 44 : 32
        Text(emoji)
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background(Theme.paper, in: Circle())
            .overlay(Circle().stroke(Theme.accent, lineWidth: selected ? 3 : 2))
            .overlay(alignment: .topTrailing) {
                Text("\(number)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 17, minHeight: 17)
                    .background(Theme.accent, in: Circle())
                    .offset(x: 6, y: -6)
            }
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            .animation(.snappy, value: selected)
    }
}
