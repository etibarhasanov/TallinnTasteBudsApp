import Foundation
import Observation

/// Everything the map shows, in the reader's language.
///
/// Reads three of the website's own files — the places (`data/map.json`), the
/// kinds of place (`data/taxonomy.json`) and one language's strings and
/// write-ups (`data/lang/<code>.json`) — and keeps the last good copy of each
/// on disk. It starts from the disk or the bundled snapshot, so the map draws
/// at once, and then asks the site for anything newer.
struct Language: Hashable {
    let code: String
    let name: String
}

@MainActor
@Observable
final class ContentStore {
    private(set) var places: [Place] = []
    private(set) var types: [PlaceType] = []
    /// Every discount in `data/deals.json`, live or not.
    private(set) var deals: [Deal] = []
    /// Code → the language's own name, from `data/lang/index.json`.
    private(set) var languages: [Language] = [Language(code: "en", name: "English")]
    private(set) var ui: [String: String] = [:]
    private(set) var blurbs: [String: String] = [:]
    private(set) var lastError: String?
    private(set) var refreshing = false

    private(set) var lang: String
    private var english: [String: String] = [:]
    /// The strings only the app says — the tab names, the list editor's
    /// hints — in every language the site speaks, from `Seed/app-strings.json`.
    private var own: [String: [String: String]] = [:]

    private static let langKey = "lang"

    init() {
        lang = UserDefaults.standard.string(forKey: Self.langKey) ?? "en"
        loadLocal()
    }

    // MARK: Reading

    func place(_ id: String) -> Place? { places.first { $0.id == id } }

    func blurb(_ id: String) -> String? {
        let text = blurbs[id]
        return (text?.isEmpty ?? true) ? nil : text
    }

    func type(_ id: String) -> PlaceType? { types.first { $0.id == id } }

    /// The discount the map shows for a place, if it has one switched on.
    func deal(_ placeID: String) -> Deal? { deals.first { $0.id == placeID && $0.shown } }

    /// Every discount switched on, the map's places and Google's alike.
    var liveDeals: [Deal] { deals.filter(\.shown) }

    /// The chip id that stands for "has a discount" — not a kind of place,
    /// which is why the website's validator refuses a taxonomy entry by it.
    static let discountChip = "discount"

    /// The chip row: every kind of place the site puts on it, in its order.
    var chips: [PlaceType] { types.filter { $0.chip } }

    /// A string from the site's `ui.json`, in this language, falling back to
    /// English and then to the text written here. The site's keys are used
    /// wherever the site already says the thing, so the app is in eleven
    /// languages for free. Strings only the app needs — every key that starts
    /// `app` — carry their English here and their ten translations in
    /// `Seed/app-strings.json`; a key the site later takes into `ui.json`
    /// is read from there instead, since the site is asked first.
    func t(_ key: String, _ fallback: String, _ args: [String: String] = [:]) -> String {
        var text = ui[key] ?? own[lang]?[key] ?? english[key] ?? fallback
        for (name, value) in args { text = text.replacingOccurrences(of: "{\(name)}", with: value) }
        return text
    }

    // MARK: Loading

    private func loadLocal() {
        if let data = Disk.read("map.json") ?? Disk.seed("seed-map"), let p = Place.decodeAll(data), !p.isEmpty {
            places = p
        }
        if let data = Disk.read("taxonomy.json") ?? Disk.seed("seed-taxonomy"), let t = PlaceType.decodeAll(data) {
            types = t
        }
        if let data = Disk.read("deals.json") ?? Disk.seed("seed-deals"), let d = Deal.decodeAll(data) {
            deals = d
        }
        if let data = Disk.read("lang-index.json") ?? Disk.seed("seed-lang-index") {
            applyIndex(data)
        }
        if let data = Disk.seed("app-strings"),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]] {
            own = parsed
        }
        if let data = Disk.seed("seed-lang-en"), let parsed = Self.parseLang(data) {
            english = parsed.ui
            if lang == "en" { ui = parsed.ui; blurbs = parsed.blurbs }
        }
        if let data = Disk.read("lang-en.json"), let parsed = Self.parseLang(data) {
            english = parsed.ui
        }
        if let data = Disk.read("lang-\(lang).json"), let parsed = Self.parseLang(data) {
            ui = parsed.ui
            blurbs = parsed.blurbs
        }
        if lang == "en" && ui.isEmpty { ui = english }
        // A first launch picks the phone's own language when the site has it.
        if UserDefaults.standard.string(forKey: Self.langKey) == nil {
            let codes = Set(languages.map(\.code))
            for preferred in Locale.preferredLanguages {
                let code = String(preferred.prefix(2))
                if codes.contains(code) { lang = code; break }
            }
        }
    }

    /// Ask the site for anything newer. Quietly keeps what it has on failure.
    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            async let mapData = API.data("data/map.json")
            async let taxData = API.data("data/taxonomy.json")
            async let indexData = API.data("data/lang/index.json")
            async let dealData = API.data("data/deals.json")
            let (m, t, i, d) = try await (mapData, taxData, indexData, dealData)
            if let parsed = Deal.decodeAll(d) { deals = parsed; Disk.write(d, "deals.json") }
            if let p = Place.decodeAll(m), !p.isEmpty { places = p; Disk.write(m, "map.json") }
            if let ty = PlaceType.decodeAll(t), !ty.isEmpty { types = ty; Disk.write(t, "taxonomy.json") }
            applyIndex(i)
            Disk.write(i, "lang-index.json")
            try await loadLanguage(lang)
            if lang != "en" {
                let en = try await API.data("data/lang/en.json")
                if let parsed = Self.parseLang(en) { english = parsed.ui; Disk.write(en, "lang-en.json") }
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setLanguage(_ code: String) async {
        lang = code
        UserDefaults.standard.set(code, forKey: Self.langKey)
        if let data = Disk.read("lang-\(code).json"), let parsed = Self.parseLang(data) {
            ui = parsed.ui
            blurbs = parsed.blurbs
        }
        try? await loadLanguage(code)
    }

    private func loadLanguage(_ code: String) async throws {
        let data = try await API.data("data/lang/\(code).json")
        guard let parsed = Self.parseLang(data) else { return }
        Disk.write(data, "lang-\(code).json")
        if code == lang {
            ui = parsed.ui
            blurbs = parsed.blurbs
        }
        if code == "en" { english = parsed.ui }
    }

    private func applyIndex(_ data: Data) {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String], !dict.isEmpty else { return }
        // English first, then the rest by their own names, which is the order
        // a reader scanning for their language expects.
        languages = dict.map { ($0.key, $0.value) }.sorted { a, b in
            if a.0 == "en" { return true }
            if b.0 == "en" { return false }
            return a.1.localizedCompare(b.1) == .orderedAscending
        }.map { Language(code: $0.0, name: $0.1) }
    }

    private static func parseLang(_ data: Data) -> (ui: [String: String], blurbs: [String: String])? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let ui = (root["ui"] as? [String: Any] ?? [:]).compactMapValues { $0 as? String }
        let blurbs = (root["blurbs"] as? [String: Any] ?? [:]).compactMapValues { $0 as? String }
        return (ui, blurbs)
    }

    // MARK: Search

    /// The places a search and a chip leave on the map. The search reads the
    /// name, the address, the kinds of place in this language, what to order
    /// and the write-up — the same fields the website's search reads.
    func filtered(query: String, type: String?) -> [Place] {
        let q = Self.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return places.filter { p in
            if p.closed { return false }
            if type == Self.discountChip {
                if self.deal(p.id) == nil { return false }
            } else if let type, !p.types.contains(type) {
                return false
            }
            guard !q.isEmpty else { return true }
            var hay = [p.name, p.address] + p.mustOrder
            for id in p.types {
                if let t = self.type(id) { hay.append(t.name(lang)); hay.append(t.name("en")); hay += t.words }
            }
            if let b = blurbs[p.id] { hay.append(b) }
            return hay.contains { Self.fold($0).contains(q) }
        }
    }

    /// Lowercased with the accents taken off, so "pohja" finds Põhja Konn.
    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
