import SwiftUI
import MapKit

/// Discover: what the Map tab opens on, laid over the map the way the
/// website's phone front page is (`assets/discover.js`). A map of unlabelled
/// marks is a question to somebody who has never been here — which of these,
/// and why — so the app answers it first, and the map is one press away.
///
/// In the phone's order: the map as one card with Open map on its corner,
/// New lists, Overlooked places, Play, Popular lists and New on the map, then
/// the ways out to Feedback and Privacy. Three of the shelves and Play are the
/// website's `GET /api/discover`, the same answer for everybody; New on the
/// map is the `added` date the app already holds, so the page is never empty.
/// While the route is out its two shelves of lists are blank cards; when it
/// does not answer, one sentence with Try again stands in for them.
///
/// Play offers lists to go round, swiped one at a time: the reader's own walks
/// still going first (`/api/walk?mine=1`, signed in only), then the lists
/// most people have finished, then lists to be the first on. Each opens its
/// list on Route, which is where a walk is started.
struct DiscoverView: View {
    @Environment(ContentStore.self) private var content
    @Environment(LocationProvider.self) private var location
    @Environment(AccountStore.self) private var account
    @Environment(\.openURL) private var openURL

    let openMap: () -> Void
    let open: (Route) -> Void
    let seeAll: () -> Void

    /// nil while asking, false when the site did not answer.
    @State private var answer: DiscoverAnswer?
    @State private var failed = false
    /// Pressed Try again this many times; a new value asks again.
    @State private var tries = 0
    /// The reader's own walks still going.
    @State private var mine: [MyWalks.Going] = []

    /// The website's PLACES and MIN: a shelf of places shows at most eight,
    /// and is not drawn at all with fewer than three.
    private static let shelf = 8
    private static let fewest = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                mapCard
                if let answer {
                    lists("discoverNewLists", "New lists", answer.fresh)
                    places("discoverQuiet", "Overlooked places",
                           why: content.t("discoverQuietSay", "The five on the map that get opened least. Open one and the next takes its place."),
                           quiet(answer), line: street)
                    play(answer.routes)
                    lists("discoverPopularLists", "Popular lists", answer.popular)
                } else if failed {
                    down
                } else {
                    waiting("discoverNewLists", "New lists")
                    waiting("discoverPopularLists", "Popular lists")
                }
                places("discoverAdded", "New on the map", why: nil, newest, line: month)
                HStack(spacing: 18) {
                    Button(content.t("feedbackTitle", "Feedback")) { openURL(API.base.appendingPathComponent("feedback.html")) }
                    Button(content.t("privacyLink", "Privacy")) { openURL(API.base.appendingPathComponent("privacy.html")) }
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.paper)
        .task(id: tries) { if answer == nil { await load() } }
        .task(id: account.signedIn) {
            mine = account.signedIn ? ((try? await API.get(MyWalks.self, "api/walk", ["mine": "1"]))?.walks ?? []) : []
        }
    }

    // MARK: The map's card

    /// The map itself, standing on Tallinn with the places on it, still: the
    /// whole card is one press to the map, and a picture that panned under a
    /// thumb would be a second map to get lost in.
    private var mapCard: some View {
        Button(action: openMap) {
            Map(initialPosition: .region(MapTab.tallinn), interactionModes: []) {
                ForEach(content.places.filter { !$0.closed }) { place in
                    Annotation("", coordinate: place.coordinate) {
                        Circle().fill(Theme.accent)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .allowsHitTesting(false)
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.hairline))
            .overlay(alignment: .bottomTrailing) {
                Text(content.t("discoverMapGo", "Open map"))
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(Theme.onAccent)
                    .padding(10)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: Shelves

    private func head(_ key: String, _ english: String, all: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            SectionLabel(text: content.t(key, english))
            Spacer()
            if all {
                Button(content.t("discoverSeeAll", "See all"), action: seeAll).font(.subheadline)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func lists(_ key: String, _ english: String, _ rows: [ListSummary]) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                head(key, english, all: true)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(rows) { list in
                            Button { open(.list(list.id)) } label: { listCard(list) }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func listCard(_ list: ListSummary) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(Pins.of(list.pin)).font(.system(size: 22))
            Text(GoogleWords.title(list.id, list.title, content))
                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                .lineLimit(3).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            if let by = list.by {
                Text(content.t("listsBy", "created by {name}", ["name": GoogleWords.who(by)]))
                    .font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
            if !list.taste.isEmpty {
                Text(list.taste.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Theme.ink.opacity(0.8)).lineLimit(2)
            }
        }
        .padding(12)
        .frame(width: 168, height: 170, alignment: .topLeading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.hairline))
    }

    @ViewBuilder
    private func places(_ key: String, _ english: String, why: String?, _ rows: [Place],
                        line: @escaping (Place) -> String) -> some View {
        if rows.count >= Self.fewest {
            VStack(alignment: .leading, spacing: 8) {
                head(key, english)
                if let why {
                    Text(why).font(.footnote).foregroundStyle(Theme.muted).padding(.horizontal, 16)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(rows.prefix(Self.shelf)) { place in
                            Button { open(.place(place.id)) } label: { placeCard(place, line(place)) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func placeCard(_ place: Place, _ line: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Group {
                if let url = place.photoURLs.first {
                    Photo(url: url)
                } else {
                    // A place is on the map before anybody has photographed it.
                    Theme.wash.overlay(Mark(size: 44))
                }
            }
            .frame(width: 140, height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(place.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(1)
            if !line.isEmpty {
                Text(line).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
        }
        .frame(width: 140, alignment: .leading)
    }

    /// Two blank cards under a title, while the route is out.
    private func waiting(_ key: String, _ english: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            head(key, english)
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.wash).frame(width: 168, height: 170)
                }
            }
            .padding(.horizontal, 16)
        }
        .accessibilityHidden(true)
    }

    private var down: some View {
        VStack(spacing: 12) {
            Text(content.t("discoverDown", "The lists are not answering just now. The map is."))
                .font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button(content.t("discoverRetry", "Try again")) {
                failed = false
                tries += 1
            }
                .buttonStyle(.prominent)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
        .padding(.horizontal, 16)
    }

    // MARK: Play

    /// One row of the deck: a walk of the reader's still going, or a route
    /// offered to everybody. A list in both is the reader's.
    private enum PlayRow: Identifiable {
        case going(MyWalks.Going)
        case offered(PlayRoute)
        var id: String {
            switch self {
            case .going(let w): return w.id
            case .offered(let r): return r.id
            }
        }
    }

    @ViewBuilder
    private func play(_ offered: [PlayRoute]) -> some View {
        let ours = Set(mine.map(\.id))
        let deck = mine.map(PlayRow.going) + offered.filter { !ours.contains($0.id) }.map(PlayRow.offered)
        if !deck.isEmpty { playCard(deck) }
    }

    private func playCard(_ routes: [PlayRow]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(content.t("discoverPlayEyebrow", "Play").uppercased())
                .font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
            Text(content.t("discoverPlayTitle", "Go round a list")).font(.title3.bold()).foregroundStyle(Theme.ink)
            Text(content.t("discoverPlaySay", "Check in at every place on a list, on transport of your choice, and you are on its board."))
                .font(.footnote).foregroundStyle(Theme.muted)
            Divider().padding(.vertical, 4)
            // One route at a time, the edge of the next showing; a swipe moves
            // to it, and the dots say how many there are.
            TabView {
                ForEach(routes) { deal in
                    Button { open(.walk(deal.id)) } label: {
                        switch deal {
                        case .going(let walk): goingRow(walk)
                        case .offered(let route): routeRow(route)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: routes.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(height: routes.count > 1 ? 108 : 72)
        }
        .card()
        .padding(.horizontal, 16)
    }

    private func routeRow(_ route: PlayRoute) -> some View {
        var parts = [route.places == 1 ? content.t("listCountOne", "1 place")
                                       : content.t("listCount", "{n} places", ["n": "\(route.places)"])]
        let press: String
        if route.finished > 0, let best = route.best {
            parts.append(content.t("discoverPlayDone", "{n} finished", ["n": "\(route.finished)"]))
            parts.append(content.t("discoverPlayBest", "fastest {took}", ["took": WalkWords(content: content).took(best)]))
            if let went = WalkWords(content: content).went(route.mode) { parts.append(went) }
            press = content.t("walkStart", "Start")
        } else {
            parts.append(content.t("discoverPlayNobody", "nobody has finished it yet"))
            press = content.t("discoverPlayFirst", "Be the first")
        }
        return HStack(spacing: 12) {
            Text(Pins.of(route.pin)).font(.system(size: 24))
                .frame(width: 46, height: 46).background(Theme.wash, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(GoogleWords.title(route.id, route.title, content))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(2)
                Text(parts.joined(separator: " · ")).font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
            }
            Spacer(minLength: 0)
            Text(press).font(.footnote.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Theme.accent, in: Capsule()).foregroundStyle(Theme.onAccent)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
    }

    private func goingRow(_ walk: MyWalks.Going) -> some View {
        HStack(spacing: 12) {
            Text(Pins.of(walk.pin)).font(.system(size: 24))
                .frame(width: 46, height: 46).background(Theme.wash, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(GoogleWords.title(walk.id, walk.title, content))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(2)
                Text(content.t("walkToGo", "{n} of {total} checked · {left} to go",
                               ["n": "\(walk.checked)", "total": "\(walk.total)", "left": "\(walk.total - walk.checked)"]))
                    .font(.caption).foregroundStyle(Theme.muted)
                ProgressView(value: Double(walk.checked), total: Double(max(1, walk.total))).tint(Theme.accent)
            }
            Spacer(minLength: 0)
            Text(content.t("discoverPlayKeep", "Keep going")).font(.footnote.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Theme.accent, in: Capsule()).foregroundStyle(Theme.onAccent)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
    }

    // MARK: What the shelves hold

    /// The places the route says are opened least, in its order, that are
    /// still open on the map the app holds.
    private func quiet(_ answer: DiscoverAnswer) -> [Place] {
        answer.quiet.compactMap { content.place($0) }.filter { !$0.closed }
    }

    private var newest: [Place] {
        content.places.filter { !$0.closed && !$0.added.isEmpty }.sorted { $0.added > $1.added }
    }

    /// The street and the number, which is what an address is before its comma.
    private func street(_ place: Place) -> String {
        String(place.address.split(separator: ",").first ?? "")
    }

    /// "November 2026", in the reader's language.
    private func month(_ place: Place) -> String {
        let parse = DateFormatter()
        parse.dateFormat = "yyyy-MM-dd"
        parse.locale = Locale(identifier: "en_US_POSIX")
        parse.timeZone = TimeZone(identifier: "UTC")
        guard let day = parse.date(from: String(place.added.prefix(10))) else { return "" }
        let say = DateFormatter()
        say.locale = Locale(identifier: content.lang)
        say.timeZone = TimeZone(identifier: "UTC")
        say.setLocalizedDateFormatFromTemplate("LLLLyyyy")
        return say.string(from: day)
    }

    private func load() async {
        do {
            answer = try await API.get(DiscoverAnswer.self, "api/discover")
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }
}

/// What `GET /api/discover` answers. Lenient as everything the app reads:
/// a shelf the site stops sending is an empty shelf.
struct DiscoverAnswer: Decodable {
    let fresh: [ListSummary]
    let popular: [ListSummary]
    let quiet: [String]
    let routes: [PlayRoute]

    enum CodingKeys: String, CodingKey { case fresh, popular, quiet, routes }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fresh = (try? c.decodeIfPresent([ListSummary].self, forKey: .fresh)) ?? []
        popular = (try? c.decodeIfPresent([ListSummary].self, forKey: .popular)) ?? []
        quiet = (try? c.decodeIfPresent([String].self, forKey: .quiet)) ?? []
        routes = (try? c.decodeIfPresent([PlayRoute].self, forKey: .routes)) ?? []
    }
}

/// A list Play offers to go round: how many doors it counts, how many have
/// finished it, the fastest in milliseconds and how that one went round.
struct PlayRoute: Identifiable, Decodable {
    let id: String
    let title: String
    let pin: String?
    let places: Int
    let finished: Int
    let best: Double?
    let mode: String

    enum CodingKeys: String, CodingKey { case id, title, pin, places, finished, best, mode }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        pin = try? c.decodeIfPresent(String.self, forKey: .pin)
        places = (try? c.decodeIfPresent(Int.self, forKey: .places)) ?? 0
        finished = (try? c.decodeIfPresent(Int.self, forKey: .finished)) ?? 0
        best = try? c.decodeIfPresent(Double.self, forKey: .best)
        mode = (try? c.decodeIfPresent(String.self, forKey: .mode)) ?? ""
    }
}
