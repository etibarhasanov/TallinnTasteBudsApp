import SwiftUI
import CoreLocation

/// Ask: the website's chat, a sheet over the map. Somebody types what they
/// feel like — "cheap ramen, open now" — and `/api/ask`, the site's one route
/// that calls a language model, answers with up to three places and a line
/// about why each. The model only ever names ids it was given and the card is
/// drawn from the app's own copy of the map, so a place it invented is never
/// shown; a place off the map is drawn as Google's, labelled as not mine.
///
/// It is a conversation: every earlier exchange goes with the next question,
/// and the thread goes when the sheet is closed, as on the website. Before a
/// question goes, `AskReader` reads it for what it wants — kinds of place,
/// price, open now, somewhere to be near — the way `assets/ask.js` does, so
/// the Function can narrow eleven hundred places to the ones it could be
/// about. The chat runs on Workers AI's free daily allowance, shared with the
/// website; when it is spent the answer says it is resting until tomorrow.
struct AskSheet: View {
    @Environment(ContentStore.self) private var content
    @Environment(LocationProvider.self) private var location
    @Environment(\.dismiss) private var dismiss
    /// A place pressed in an answer: the map's own, or one of Google's.
    let open: (Route) -> Void

    @State private var question = ""
    @State private var thread: [Turn] = []
    @State private var wish: AskReader.Wish?
    @State private var asking = false
    @FocusState private var typing: Bool

    struct Turn: Identifiable {
        let id = UUID()
        let q: String
        var say = ""
        var picks: [AskAnswer.Pick] = []
        var venues: [CatalogueHit] = []
        var note = ""
        var failed = false
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if thread.isEmpty {
                            Text(content.t("askTitle", "What do you feel like?"))
                                .font(.title2.bold()).foregroundStyle(Theme.ink)
                        }
                        ForEach(thread) { turn in
                            turnView(turn).id(turn.id)
                        }
                        if asking {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text(content.t("askThinking", "Looking…")).foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: thread.count) { _, _ in
                    if let last = thread.last { withAnimation { scroller.scrollTo(last.id, anchor: .top) } }
                }
            }
            .safeAreaInset(edge: .bottom) { field }
            .paperBackground()
            .navigationTitle(content.t("askOpen", "Ask"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(content.t("close", "Close")) { dismiss() }
                }
            }
            .onAppear { typing = true }
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            TextField(content.t("askPlaceholder", "cheap ramen, open now"), text: $question, axis: .vertical)
                .lineLimit(1...3)
                .focused($typing)
                .submitLabel(.send)
                .onSubmit { send() }
                .padding(10)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline))
            Button(content.t("askSend", "Ask")) { send() }
                .buttonStyle(.prominent)
                .disabled(asking || question.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
        .background(Theme.paper)
    }

    @ViewBuilder
    private func turnView(_ turn: Turn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(turn.q)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.wash, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .trailing)
            if turn.failed {
                Text(content.t("appOffline", "Couldn’t reach tallinntastebuds.ee.")).foregroundStyle(Theme.accent)
            } else if !turn.say.isEmpty || !turn.picks.isEmpty {
                if !turn.say.isEmpty { Text(turn.say).foregroundStyle(Theme.ink) }
                ForEach(turn.picks, id: \.id) { pick in pickRow(pick, venues: turn.venues) }
                if !turn.note.isEmpty {
                    Text(turn.note).font(.caption).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    @ViewBuilder
    private func pickRow(_ pick: AskAnswer.Pick, venues: [CatalogueHit]) -> some View {
        if let place = content.place(pick.id) {
            Button { open(.place(place.id)) } label: {
                HStack(alignment: .top, spacing: 12) {
                    Group {
                        if let url = place.photoURLs.first { Photo(url: url) } else { Theme.wash.overlay(Mark(size: 28)) }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(place.name).font(.headline).foregroundStyle(Theme.ink)
                        if !pick.why.isEmpty { Text(pick.why).font(.subheadline).foregroundStyle(Theme.ink) }
                        if let far = pick.far { Text(distance(far * 1000)).font(.caption).foregroundStyle(Theme.muted) }
                    }
                    Spacer(minLength: 0)
                }
                .card()
            }
            .buttonStyle(.plain)
        } else if let hit = venues.first(where: { $0.id == pick.id }) {
            Button { open(.venue(ListItem(hit: hit))) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(content.t("askNotMine", "Not on my map — I have never been. What follows is Google's, not mine."))
                        .font(.caption).foregroundStyle(Theme.muted)
                    Text(hit.name).font(.headline).foregroundStyle(Theme.ink)
                    if !pick.why.isEmpty { Text(pick.why).font(.subheadline).foregroundStyle(Theme.ink) }
                    Text([hit.category, hit.rating.map { String(format: "%.1f ★ Google", $0) } ?? ""]
                            .filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                .card()
            }
            .buttonStyle(.plain)
        }
    }

    private func distance(_ m: Double) -> String {
        m < 1000
            ? content.t("askMetres", "{n} m", ["n": "\(max(10, Int((m / 10).rounded()) * 10))"])
            : content.t("askKm", "{n} km", ["n": String(format: "%.1f", m / 1000)])
    }

    // MARK: Asking

    private func send() {
        let q = String(question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(AskReader.maxQuestion))
        guard !q.isEmpty, !asking else { return }
        question = ""
        let read = AskReader.read(q, content: content)
        let carried = AskReader.carry(wish, read)
        wish = carried
        let history = thread.filter { !$0.failed }.suffix(10).map { turn -> [String: Any] in
            ["q": turn.q, "say": turn.say, "picks": turn.picks.map { ["id": $0.id, "why": $0.why] }]
        }
        thread.append(Turn(q: q))
        let index = thread.count - 1
        asking = true
        Task {
            defer { asking = false }
            var body: [String: Any] = ["q": q, "lang": content.lang, "wish": carried.json, "history": Array(history)]
            // The position goes only with a question that asks for somewhere
            // near, as the website's privacy page promises.
            if carried.nearby, location.isReal, let here = location.location?.coordinate {
                body["here"] = ["lat": here.latitude, "lng": here.longitude]
            }
            guard let answer = try? await API.post(AskAnswer.self, "api/ask", body), answer.ok else {
                thread[index].failed = true
                return
            }
            var turn = thread[index]
            turn.picks = answer.picks
            turn.venues = answer.venues
            switch answer.source {
            case "resting":
                turn.say = content.t("askResting", "We have overworked today. We are on a break until the new day — come back tomorrow.")
            default:
                if answer.picks.isEmpty {
                    turn.say = answer.say.isEmpty
                        ? content.t("askNothing", "Nothing on the map answers that. Try a dish, a kind of place, or a street.")
                        : answer.say
                } else {
                    turn.say = answer.say.isEmpty ? content.t("askHere", "Here is where I would go.") : answer.say
                }
            }
            if let at = answer.at {
                turn.note = at.here
                    ? content.t("askFromHere", "Distances are from your location on the map, as the crow flies.")
                    : content.t("askFrom", "Distances are from {name}, as the crow flies.", ["name": at.label.isEmpty ? at.where : at.label])
            }
            thread[index] = turn
        }
    }
}

/// What `/api/ask` answers.
struct AskAnswer: Decodable {
    let ok: Bool
    let source: String
    let say: String
    let picks: [Pick]
    let venues: [CatalogueHit]
    let at: At?

    struct Pick: Decodable {
        let id: String
        let why: String
        /// Kilometres from where the visitor said they are, or nil.
        let far: Double?

        enum CodingKeys: String, CodingKey { case id, why, far }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            why = (try? c.decodeIfPresent(String.self, forKey: .why)) ?? ""
            far = try? c.decodeIfPresent(Double.self, forKey: .far)
        }
    }

    /// What "near" was measured from: the visitor's own dot, or a place.
    struct At: Decodable {
        let here: Bool
        let label: String
        let `where`: String

        enum CodingKeys: String, CodingKey { case here, label, `where` }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            here = (try? c.decodeIfPresent(Bool.self, forKey: .here)) ?? false
            label = (try? c.decodeIfPresent(String.self, forKey: .label)) ?? ""
            `where` = (try? c.decodeIfPresent(String.self, forKey: .where)) ?? ""
        }
    }

    enum CodingKeys: String, CodingKey { case ok, source, say, picks, venues, at }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = (try? c.decodeIfPresent(Bool.self, forKey: .ok)) ?? false
        source = (try? c.decodeIfPresent(String.self, forKey: .source)) ?? ""
        say = (try? c.decodeIfPresent(String.self, forKey: .say)) ?? ""
        picks = (try? c.decodeIfPresent([Pick].self, forKey: .picks)) ?? []
        venues = (try? c.decodeIfPresent([CatalogueHit].self, forKey: .venues)) ?? []
        at = try? c.decodeIfPresent(At.self, forKey: .at)
    }
}

/// Reading a sentence as a wish, the website's `assets/ask.js` read() and
/// carry(): which kinds of place, how dear, open now, what to be near, and
/// the words left over. The vocabulary is the site's — the kinds' labels in
/// every language from the taxonomy, and cheap, fancy, open, near and me
/// from `askWords*` in the reader's language — so a word the site learns
/// reaches the app with no release. Cuisines are left to the server, which
/// still matches the words left over against them.
@MainActor
enum AskReader {
    static let maxQuestion = 200

    struct Wish {
        var types: [String] = []
        var cheap = false
        var fancy = false
        var open = false
        var nearby = false
        var near = ""
        var rest: [String] = []

        var json: [String: Any] {
            ["types": types, "kitchens": [String](), "cheap": cheap, "fancy": fancy, "open": open,
             "nearby": nearby, "near": near, "rest": rest]
        }
    }

    /// The website's NOISE: the filler that matched the wrong places.
    private static let noise = Set((
        "a an the and or of for in on at to me i im is are want would like some " +
        "something somewhere place places good nice please can you find show " +
        "how does do it this that what which why who there here " +
        "more other another else any few couple options option spots spot ideas " +
        "idea suggestions suggestion recommend recommendation recommendations tell give " +
        "best top " +
        "one first second third next last latest instead rather actually maybe also " +
        "again then just really " +
        "ja voi vai see on ning kus midagi kohta koht hea palun kuidas mis kas kuhu " +
        "veel muud muid teisi moni moned paar valikuid valikud soovita soovitusi " +
        "parim parimad parimat " +
        "esimene teine kolmas jargmine viimane hoopis pigem tegelikult vist jalle siis lihtsalt " +
        "и или на в где что нибудь место хорошее пожалуйста хочу как это куда " +
        "еще другие другое другои другую несколько пару варианты вариант вариантов " +
        "посоветуи посоветуите подскажи подскажите лучшии лучшие лучшая лучшее самыи самое " +
        "первыи первая второи вторая третии последнии следующии вместо лучше вообще " +
        "может тоже опять снова тогда просто"
    ).split(separator: " ").map(String.init))

    private static let punctuation = CharacterSet(charactersIn: ".,!?;:()[]{}\"'`/\\|~@#$%^&*_+=<>–—‘’“”«»¿¡-")

    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    private static func clean(_ text: String) -> String {
        fold(text).components(separatedBy: punctuation).joined(separator: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func has(_ q: String, _ phrase: String) -> Bool {
        (" " + q + " ").contains(" " + phrase + " ")
    }

    private static func phrases(_ list: String) -> [String] {
        list.split(separator: "|").map { clean(String($0)) }.filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
    }

    private static func said(_ q: String, _ list: [String]) -> String? { list.first { has(q, $0) } }

    /// A label's ways of being said: each half of a slash, and each word of a
    /// half of four letters or more.
    private static func ways(_ label: String) -> [String] {
        var out: [String] = []
        for half in label.split(separator: "/") {
            let whole = clean(String(half))
            if whole.count > 2 { out.append(whole) }
            if whole.contains(" ") { out += whole.split(separator: " ").map(String.init).filter { $0.count > 3 } }
        }
        return out
    }

    static func read(_ question: String, content: ContentStore) -> Wish {
        let q = clean(String(question.prefix(maxQuestion)))
        let cheapWords = content.t("askWordsCheap", "cheap|cheaply|budget|affordable|inexpensive|not expensive|cheaper|less expensive")
        let fancyWords = content.t("askWordsFancy", "fancy|posh|expensive|upmarket|smart|special|fine dining|splash out|treat|celebrate|celebration")
        let cheap = phrases(cheapWords), fancy = phrases(fancyWords)
        let open = phrases(content.t("askWordsOpen", "open now|still open|open|right now|tonight|now|late"))
        let near = phrases(content.t("askWordsNear", "nearest|closest|nearer|closer|near|nearby|close to|close by|next to|not far from"))
        let me = phrases(content.t("askWordsMe", "me|us|my place|my hotel|my location|where i am|where we are|here|around here|from here"))

        var wish = Wish()
        // Both price lists read together, longest first, so "not expensive"
        // outranks the "expensive" inside it.
        if let priced = said(q, phrases(fancyWords + "|" + cheapWords)) {
            if fancy.contains(priced) { wish.fancy = true } else { wish.cheap = true }
        }
        wish.open = said(q, open) != nil
        let wantsNear = said(q, near)
        wish.nearby = wantsNear != nil

        var kinds: [String] = []
        for type in content.types {
            let hit = type.names.values.flatMap { ways($0) }.filter { has(q, $0) }
            if !hit.isEmpty {
                wish.types.append(type.id)
                kinds += hit
            }
        }

        let spent = (fancy + cheap + open + near).filter { has(q, $0) }.sorted { $0.count > $1.count }
        func leftover(_ text: String) -> [String] {
            var left = text
            for p in spent { left = left.replacingOccurrences(of: p, with: " ") }
            return left.split(separator: " ").map(String.init).filter { $0.count >= 3 && !noise.contains($0) }
        }
        wish.rest = Array(leftover(q).prefix(20))

        // What to be near: what follows the phrase, or what is left over,
        // with the kinds of place taken out — never the visitor themselves.
        if let wantsNear, said(q, me) == nil {
            var whole = " " + q + " "
            for p in kinds { whole = whole.replacingOccurrences(of: " " + p + " ", with: " ") }
            let parts = whole.components(separatedBy: " " + wantsNear + " ")
            let after = parts.dropFirst().joined(separator: " ")
            let words = leftover(after).isEmpty ? leftover(whole) : leftover(after)
            wish.near = String(words.joined(separator: " ").prefix(80))
        }
        return wish
    }

    /// A follow-up keeps the conversation's topic and price unless it names
    /// new ones, and open and near once asked for.
    static func carry(_ earlier: Wish?, _ now: Wish) -> Wish {
        guard let earlier else { return now }
        let topic = !now.types.isEmpty || !now.rest.isEmpty
        let price = now.cheap || now.fancy
        var out = now
        if !topic { out.types = earlier.types; out.rest = earlier.rest }
        if !price { out.cheap = earlier.cheap; out.fancy = earlier.fancy }
        out.open = now.open || earlier.open
        out.nearby = now.nearby || earlier.nearby
        out.near = now.nearby ? now.near : earlier.near
        return out
    }
}
