import SwiftUI
import MapKit

/// One list, read: its places in its author's order with what they wrote
/// about each, the same list as numbered pins on a map, and its Route — the
/// places in the shortest order to go round them, and a walk to check in on.
struct ListDetailView: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss
    let id: String
    /// Which of the three views it opens on.
    var opening: Shown = LaunchScript.listView

    enum Shown: Hashable { case list, map, route }

    @State private var list: ListDetail?
    @State private var editing = false
    @State private var signingIn = false
    @State private var kept: Bool?
    @State private var keeps: Int?
    @State private var failed = false
    @State private var gone = false
    /// Deleted in the editor, so this screen closes behind it.
    @State private var deleted = false
    @State private var shown: Shown?
    @State private var game: WalkGame?
    /// The place pressed on the page, which the map opens on.
    @State private var focus: String? = LaunchScript.listFocus

    var body: some View {
        Group {
            if let list {
                let view = Binding(get: { shown ?? opening }, set: { shown = $0 })
                VStack(spacing: 0) {
                    Picker("", selection: view) {
                        Text(content.t("listsViewList", "List")).tag(Shown.list)
                        Text(content.t("listsViewMap", "Map")).tag(Shown.map)
                        // A route needs two places to stand at.
                        if list.items.filter({ $0.coordinate != nil }).count > 1 {
                            Text(content.t("walkView", "Route")).tag(Shown.route)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    switch view.wrappedValue {
                    case .map:
                        ListMap(list: list, focus: focus, game: game) {
                            withAnimation(.snappy) { shown = .route }
                        }
                    case .route:
                        if let game {
                            WalkRoute(game: game) {
                                focus = nil
                                withAnimation(.snappy) { shown = .map }
                            }
                        }
                    case .list:
                        // Pressing a place on the page goes to the map, on
                        // that place, rather than off the list: a list is
                        // read to decide where to go, and where it is is the
                        // next question. Its card on the map opens the place.
                        ListPage(list: list, keepsNow: keeps) { item in
                            focus = item.id
                            withAnimation(.snappy) { shown = .map }
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
                // A deleted list leaves this screen too, once the editor has
                // gone from over it: reading it again would only be a 404,
                // and staying would show a list that is no longer there.
                .fullScreenCover(isPresented: $editing, onDismiss: { if deleted { dismiss() } }) {
                    ListEditor(list: list, isPublic: list.isPublic,
                               done: { Task { await load() } },
                               deleted: { deleted = true })
                }
                .sheet(isPresented: $signingIn) {
                    SignInView(reason: content.t("listsKeepIn", "Sign in to save this list"))
                }
            } else if gone {
                EmptyNote(title: content.t("listsGoneTitle", "Not here"),
                          text: content.t("listsErrGone", "This list is not here. It may have been deleted, or the link may be private."),
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
                let walk = WalkGame(list: l)
                game = walk
                Task { await walk.load() }
                if LaunchScript.edit == l.id { editing = true }
            } else {
                list = nil
                gone = true
            }
        } catch API.Failure.notFound {
            // Not the copy read before it went: a list that is gone is shown
            // as gone.
            list = nil
            game = nil
            gone = true
        } catch {
            // Offline with a list already on screen: keep showing it.
            failed = list == nil
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
                    Text(GoogleWords.title(list.id, list.title, content)).font(.title.bold()).foregroundStyle(Theme.ink)
                    HStack(spacing: 4) {
                        if let by = list.by {
                            NavigationLink(value: Route.profile(by)) {
                                Text(GoogleWords.who(by)).fontWeight(.semibold).foregroundStyle(Theme.ink)
                            }
                            Text("·").foregroundStyle(Theme.muted)
                        }
                        Text(counts).foregroundStyle(Theme.muted)
                    }
                    .font(.subheadline)
                    if !list.intro.isEmpty {
                        Text(GoogleWords.intro(list.id, list.intro, content)).font(.body).foregroundStyle(Theme.ink).padding(.top, 4)
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
        if !list.isPublic { parts.append(content.t("listsWhoPrivate", "Private")) }
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
    /// The card under a list's map: a line for the name and two for what is
    /// said about it, whatever is said, so every card is the same height.
    var compact = false

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
                if compact {
                    HStack(spacing: 6) {
                        Text(item.name).font(.headline).foregroundStyle(Theme.ink).lineLimit(1)
                        if !item.map { notOnMap.fixedSize() }
                    }
                    gist.font(.subheadline).lineLimit(2, reservesSpace: true)
                } else {
                    Text(item.name).font(.headline).foregroundStyle(Theme.ink)
                    if !item.map { notOnMap }
                    if !item.say.isEmpty {
                        Text(item.say).font(.subheadline).foregroundStyle(Theme.ink)
                    }
                    if !item.mustOrder.isEmpty {
                        mustOrder.font(.footnote)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Theme.hairline).padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var notOnMap: some View {
        Text(content.t("appNotOnMapShort", "Not on the map"))
            .font(.caption)
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.hairline))
    }

    private var mustOrder: Text {
        Text(content.t("mustOrder", "Must order") + ": ").foregroundStyle(Theme.muted)
            + Text(item.mustOrder).fontWeight(.semibold).foregroundStyle(Theme.ink)
    }

    /// The compact card's one say about the place, in two lines it always
    /// keeps room for: what the author wrote, else what to order, else where
    /// it is.
    private var gist: Text {
        if !item.say.isEmpty { return Text(item.say).foregroundStyle(Theme.ink) }
        if !item.mustOrder.isEmpty { return mustOrder }
        return Text(item.address.isEmpty ? " " : item.address).foregroundStyle(Theme.muted)
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
    /// The walk on this list, drawn on the map while it is on: a dashed line
    /// through the places in the walker's order, a tick on the ones checked,
    /// the next one filled, and the walk's bar where the card would be.
    var game: WalkGame?
    /// The walk's bar's way back to the Route view.
    var toRoute: () -> Void = {}

    private var walking: Bool { game.map { $0.started && !$0.finished } ?? false }

    @State private var selected: String?
    /// The card the row of cards is on. Kept apart from `selected` so the row
    /// is put on its first card only once it is there to scroll.
    @State private var carded: String?
    @State private var camera: MapCameraPosition = .automatic
    /// False until the selection made on the way in has gone by, so that one
    /// does not move the map: opening on the whole list frames them all.
    @State private var settled = false
    @State private var opened = false

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
                if walking, let game {
                    let stops = game.stops
                    MapPolyline(coordinates: stops.compactMap(\.coordinate))
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 6]))
                    ForEach(Array(stops.enumerated()), id: \.element.id) { i, item in
                        Annotation(item.name, coordinate: item.coordinate!, anchor: .center) {
                            WalkPin(number: i + 1, checked: game.check(item.place) != nil, next: game.next == item)
                        }
                        .annotationTitles(.hidden)
                        .tag(item.id)
                    }
                } else {
                    ForEach(placed) { pin in
                        Annotation(pin.item.name, coordinate: pin.coordinate, anchor: .center) {
                            NumberedPin(emoji: Pins.of(list.pin), number: pin.number, selected: selected == pin.id)
                        }
                        .annotationTitles(.hidden)
                        .tag(pin.id)
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            // The blue dot is the app's tint; left to the accent it drew you
            // in brick red, the colour of a pin, beside a blue route.
            .tint(Theme.here)

            VStack(alignment: .trailing, spacing: 12) {
                LocateButton(camera: $camera).padding(.trailing, 14)
                if walking, let game {
                    WalkBand(game: game, onList: toRoute)
                } else {
                    card
                }
            }
        }
        .onAppear {
            // Only the first time: coming back from a place opened on a card
            // leaves the map on the card it was swiped to.
            guard !opened else { return }
            opened = true
            if let focus, let pin = placed.first(where: { $0.id == focus }) {
                selected = pin.id
                camera = .region(MKCoordinateRegion(center: pin.coordinate, latitudinalMeters: 700, longitudinalMeters: 700))
            } else if selected == nil {
                selected = placed.first?.id
            }
        }
        .onChange(of: selected) { _, id in
            // Pressing a pin, or swiping to its card, brings it to the
            // middle, the way the list's press does, so the card and the pin
            // are seen together.
            guard settled else { settled = true; return }
            guard let id, let pin = placed.first(where: { $0.id == id }) else { return }
            withAnimation(.easeInOut) {
                camera = .region(MKCoordinateRegion(center: pin.coordinate, latitudinalMeters: 900, longitudinalMeters: 900))
            }
        }
    }

    /// The places' cards side by side in the list's order, one at a time with
    /// the edge of the next one showing, which is what says they swipe.
    /// Swiping to a card selects its place, so the map goes to its pin as
    /// pressing the pin would; pressing a pin brings its card round.
    ///
    /// The row is lazy: a card's photo is fetched when the card comes near
    /// the screen, not every photo on the list when the map opens. Every
    /// card is the same height (`compact`), so the row does not jump as it
    /// is swiped.
    @ViewBuilder
    private var card: some View {
        if selected != nil, !placed.isEmpty {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(placed) { pin in
                        NavigationLink(value: route(for: pin.item)) {
                            ListItemRow(number: pin.number, item: pin.item, compact: true)
                                .padding(.vertical, 4)
                                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18))
                                .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
                        }
                        .buttonStyle(.plain)
                        .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $carded)
            // 20 points each side: a card is that much narrower than the
            // screen, and 12 of it (less the 8 between cards) is the edge of
            // the next card showing.
            .safeAreaPadding(.horizontal, 20)
            // The cards' shadows fall outside the row; clipped, they'd be cut.
            .scrollClipDisabled()
            .padding(.bottom, 12)
            // The row starts on the selected place, set here rather than
            // before the row exists so it is a change the row scrolls for.
            .onAppear { carded = selected }
            .onDisappear { carded = nil }
            .onChange(of: carded) { _, id in
                if let id, id != selected { selected = id }
            }
            // A pin pressed puts its card there at once, not with a scroll:
            // a scroll past the cards between would report each of them on
            // the way and could stop the selection on the first.
            .onChange(of: selected) { _, id in
                if let id, id != carded { carded = id }
            }
        }
    }

    private func route(for item: ListItem) -> Route {
        if item.map, content.place(item.place) != nil { return .place(item.place) }
        return .venue(item)
    }
}

/// A place on a walk drawn on the map: its number in the walker's order, a
/// tick in the walk's green once checked, the next one filled.
struct WalkPin: View {
    let number: Int
    let checked: Bool
    let next: Bool

    var body: some View {
        ZStack {
            Circle().fill(checked ? RouteView.Mode.foot.color : next ? Theme.accent : Theme.paper)
            Circle().stroke(checked ? RouteView.Mode.foot.color : Theme.accent, lineWidth: 2)
            if checked {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            } else {
                Text("\(number)").font(.system(size: 12, weight: .bold)).foregroundStyle(next ? Theme.onAccent : Theme.accent)
            }
        }
        .frame(width: 28, height: 28)
        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
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
                    .foregroundStyle(Theme.onAccent)
                    .frame(minWidth: 17, minHeight: 17)
                    .background(Theme.accent, in: Circle())
                    .offset(x: 6, y: -6)
            }
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            .animation(.snappy, value: selected)
    }
}
