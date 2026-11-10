import SwiftUI

/// The second tab: everybody's lists, the most opened first, searchable by
/// title, author or place — the same directory as `/lists` on the website.
///
/// Signed in, your own lists and the ones you saved sit above them, with the
/// card that makes a new one first. Signed out, that space says what lists
/// are and asks you to sign in — reading them never needs an account.
struct ListsTab: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account

    @State private var path = NavigationPath(LaunchScript.routes(tab: 1))
    @State private var query = ""
    @State private var lists: [ListSummary] = []
    @State private var next: String?
    @State private var loading = false
    @State private var failed = false
    @State private var making = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if query.isEmpty {
                        if account.signedIn { yours } else if account.checked { makeYourOwn }
                    }
                    SectionLabel(text: query.isEmpty
                                 ? content.t("listsAllTitle", "Everybody’s lists")
                                 : content.t("listsAllFor", "Lists matching “{q}”", ["q": query]))
                        .padding(.top, 8)
                    ForEach(lists) { list in
                        NavigationLink(value: Route.list(list.id)) { ListCard(list: list) }
                            .buttonStyle(.plain)
                            .onAppear { if list.id == lists.last?.id { Task { await more() } } }
                    }
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .paperBackground()
            .navigationTitle(content.t("listsTitle", "Lists"))
            .searchable(text: $query, prompt: content.t("listsAllSearchHint", "Search by list, author or place"))
            .refreshable {
                await load()
                await account.refreshLists()
            }
            .sheet(isPresented: $making) {
                NewListView { id in path.append(Route.list(id)) }
            }
            .task(id: query) {
                // A short wait, so a search is sent when the typing stops
                // rather than once a letter.
                if !query.isEmpty { try? await Task.sleep(for: .milliseconds(350)) }
                if Task.isCancelled { return }
                await load()
            }
            .withRoutes()
        }
    }

    /// Your lists as cards you swipe across, "New list" first; then the ones
    /// you saved, the same way.
    private var yours: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: content.t("listsYours", "Your lists"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button { making = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "plus").font(.title2.bold())
                            Text(content.t("appNewList", "New list")).font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Theme.accent)
                        .frame(width: 140, height: 112)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius)
                            .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                    }
                    ForEach(account.mine) { list in
                        NavigationLink(value: Route.list(list.id)) { MiniListCard(list: list) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            if !account.kept.isEmpty {
                SectionLabel(text: content.t("listsKept", "Lists you saved")).padding(.top, 8)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(account.kept) { list in
                            NavigationLink(value: Route.list(list.id)) { MiniListCard(list: list) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var makeYourOwn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content.t("appListsMakeTitle", "Make your own lists")).font(.headline).foregroundStyle(Theme.ink)
            Text(content.t("appListsMakeSay", "Top tens, where to take your parents, the bakeries worth the walk. Making lists needs an account; reading them doesn’t."))
                .font(.subheadline).foregroundStyle(Theme.ink)
            SignInButton()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.wash, in: RoundedRectangle(cornerRadius: Theme.radius))
    }

    @ViewBuilder
    private var footer: some View {
        if loading {
            ProgressView().frame(maxWidth: .infinity).padding()
        } else if failed {
            VStack(spacing: 8) {
                Text(content.t("appOffline", "Couldn’t reach tallinntastebuds.ee.")).foregroundStyle(Theme.muted)
                Button(content.t("appRetry", "Try again")) { Task { await load() } }
            }
            .frame(maxWidth: .infinity).padding()
        } else if lists.isEmpty {
            Text(query.isEmpty ? content.t("appListsNone", "No lists yet.") : content.t("searchNone", "Nothing matches “{q}”.", ["q": query]))
                .foregroundStyle(Theme.muted).frame(maxWidth: .infinity).padding()
        }
    }

    private func load() async {
        loading = true
        failed = false
        defer { loading = false }
        do {
            var q = ["all": "1"]
            if !query.isEmpty { q["q"] = query }
            let page = try await API.get(ListsPage.self, "api/lists", q)
            lists = page.all
            next = page.next
        } catch is CancellationError {
        } catch {
            if (error as? URLError)?.code != .cancelled { failed = true }
        }
    }

    private func more() async {
        guard let cursor = next, !loading else { return }
        loading = true
        defer { loading = false }
        var q = ["all": "1", "from": cursor]
        if !query.isEmpty { q["q"] = query }
        if let page = try? await API.get(ListsPage.self, "api/lists", q) {
            let have = Set(lists.map(\.id))
            lists += page.all.filter { !have.contains($0.id) }
            next = page.next
        }
    }
}

/// A list as a card: its title, whose it is, the first few places, and a
/// small picture of where its places are.
struct ListCard: View {
    @Environment(ContentStore.self) private var content
    let list: ListSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(list.title).font(.headline).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                Text(byline).font(.subheadline).foregroundStyle(Theme.muted)
                if !list.taste.isEmpty {
                    Text(list.taste.joined(separator: " · "))
                        .font(.footnote).foregroundStyle(Theme.ink.opacity(0.8)).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            DotsMap(dots: list.dots, pin: Pins.of(list.pin))
                .frame(width: 72, height: 72)
        }
        .card()
    }

    private var byline: String {
        var parts: [String] = []
        if let by = list.by { parts.append(by) }
        if let n = list.n { parts.append(content.t("appPlacesN", "{n} places", ["n": "\(n)"])) }
        if list.keeps == 1 { parts.append(content.t("listsKeptOne", "saved by 1 person")) }
        if list.keeps > 1 { parts.append(content.t("listsKeptN", "saved by {n} people", ["n": "\(list.keeps)"])) }
        return parts.joined(separator: " · ")
    }
}

/// Where a list's places are, as dots on a square of paper, with the list's
/// own pin in the corner. The website draws the same thing on its directory.
struct DotsMap: View {
    let dots: [[Double]]
    let pin: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Canvas { ctx, size in
                let points = dots.compactMap { $0.count == 2 ? ($0[0], $0[1]) : nil }
                guard !points.isEmpty else { return }
                let lats = points.map { $0.0 }, lngs = points.map { $0.1 }
                // A degree of longitude is about half a degree of latitude
                // this far north, so the box is squared up before drawing.
                let latSpan = max((lats.max()! - lats.min()!), 0.004)
                let lngSpan = max((lngs.max()! - lngs.min()!) * 0.51, 0.004)
                let span = max(latSpan, lngSpan) * 1.3
                let midLat = (lats.max()! + lats.min()!) / 2
                let midLng = (lngs.max()! + lngs.min()!) / 2
                for (lat, lng) in points {
                    let x = size.width / 2 + CGFloat((lng - midLng) * 0.51 / span) * size.width
                    let y = size.height / 2 - CGFloat((lat - midLat) / span) * size.height
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7)), with: .color(Theme.accent))
                }
            }
            .background(Theme.wash, in: RoundedRectangle(cornerRadius: 12))
            if dots.isEmpty {
                // Nothing to draw (a profile's rows carry no points): the
                // list's pin, large, is the picture instead.
                Text(pin).font(.system(size: 30)).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(pin).font(.system(size: 16)).padding(4)
            }
        }
    }
}

/// One of your lists, or one you saved, as a small card in a row you swipe.
struct MiniListCard: View {
    @Environment(ContentStore.self) private var content
    let list: ListSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(list.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                .lineLimit(3).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Text(Pins.of(list.pin))
                if let n = list.n { Text(content.t("appPlacesN", "{n} places", ["n": "\(n)"])) }
                if list.isPublic == false { Image(systemName: "lock.fill") }
            }
            .font(.caption).foregroundStyle(Theme.muted)
            if let by = list.by { Text(by).font(.caption).foregroundStyle(Theme.muted).lineLimit(1) }
        }
        .padding(10)
        .frame(width: 140, height: 112, alignment: .topLeading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.hairline))
    }
}
