import CoreLocation
import Observation
import SwiftUI

/// The app's single source of truth, and a mirror of the website's content.
///
/// Nothing here is a property observer on purpose: `@Observable` turns stored
/// properties into computed ones, which cannot carry `willSet`/`didSet`. Side
/// effects go in the explicit setters below instead.
@MainActor
@Observable
final class ContentStore {
    // MARK: - Content, as published by the site

    private(set) var places: [Place] = []
    private(set) var taxonomy: Taxonomy = .empty
    private(set) var deals: [Deal] = []
    private(set) var radio: RadioFeed?
    /// The raw `ui.json` table. `strings` below is the view onto it.
    private(set) var uiTable: [String: [String: String]] = [:]

    /// When the content last came off the network, for the line in Settings.
    /// Nil means everything on screen is the cached or seeded copy.
    private(set) var lastSynced: Date?
    private(set) var isRefreshing = false
    private(set) var lastError: String?

    // MARK: - What the reader has chosen

    /// The reader's language. Set it through `select(language:)` so the choice
    /// is remembered.
    private(set) var lang: String
    var query: String = ""
    var activeTypes: Set<String> = []
    var sort: SortOrder = .newest

    enum SortOrder: String, CaseIterable, Identifiable {
        case newest, alphabetical, nearest
        var id: String { rawValue }
    }

    /// The one chip that is not a taxonomy type. The site reserves this id for
    /// the same reason: two chips answering to one id would filter each other's
    /// places.
    static let dealFilter = "discount"
    private static let langKey = "ttb.lang"

    private let client: ContentClient

    init(client: ContentClient = .shared) {
        self.client = client
        self.lang = UserDefaults.standard.string(forKey: Self.langKey) ?? Self.preferredLanguage()
        loadCached()
    }

    /// The interface text in the reader's language.
    var strings: Strings { Strings(table: uiTable, lang: lang) }

    func select(language code: String) {
        guard code != lang else { return }
        lang = code
        UserDefaults.standard.set(code, forKey: Self.langKey)
    }

    // MARK: - Loading

    /// Whatever is on disk or in the bundle, decoded synchronously so the very
    /// first frame already has a full map on it.
    private func loadCached() {
        places = client.cached([Place].self, .restaurants) ?? []
        taxonomy = client.cached(Taxonomy.self, .taxonomy) ?? .empty
        deals = client.cached([Deal].self, .deals) ?? []
        radio = client.cached(RadioFeed.self, .radio)
        uiTable = client.cached([String: [String: String]].self, .ui) ?? [:]
        settleLanguage()
    }

    /// A language the site has stopped publishing must not leave the app showing
    /// bare keys.
    private func settleLanguage() {
        guard !uiTable.isEmpty, uiTable[lang] == nil else { return }
        lang = Strings.fallbackLang
    }

    /// Pull the current content from the site. Each document is independent: a
    /// failure on one leaves the others' updates in place, and a 304 leaves the
    /// value alone entirely.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let restaurants = fetch([Place].self, .restaurants)
        async let types = fetch(Taxonomy.self, .taxonomy)
        async let ui = fetch([String: [String: String]].self, .ui)
        async let offers = fetch([Deal].self, .deals)
        async let stations = fetch(RadioFeed.self, .radio)

        let (placesResult, typesResult, uiResult, dealsResult, radioResult) =
            await (restaurants, types, ui, offers, stations)

        // `.unchanged` is the common case and means what is on screen is already
        // current, so only `.updated` writes anything.
        if case .updated(let value) = placesResult, !value.isEmpty { places = value }
        if case .updated(let value) = typesResult { taxonomy = value }
        if case .updated(let value) = uiResult {
            uiTable = value
            settleLanguage()
        }
        if case .updated(let value) = dealsResult { deals = value }
        if case .updated(let value) = radioResult { radio = value }

        // Checked one by one rather than through an array: each result is a
        // different `Fetched<T>`, and there is no array that holds all five.
        let failed = placesResult.failed || typesResult.failed || uiResult.failed
            || dealsResult.failed || radioResult.failed
        if failed {
            lastError = strings("loadError")
        } else {
            lastSynced = Date()
            lastError = nil
        }
    }

    /// One document's outcome. Kept apart from a plain optional because "the
    /// server says nothing changed" and "the fetch failed" must not be confused:
    /// the first is success, the second has to surface.
    private enum Fetched<T> {
        case updated(T)
        case unchanged
        case failed

        var failed: Bool {
            if case .failed = self { return true }
            return false
        }
    }

    private func fetch<T: Decodable & Sendable>(
        _ type: T.Type,
        _ document: ContentSource.Document
    ) async -> Fetched<T> {
        do {
            if let value = try await client.fetch(type, document) { return .updated(value) }
            return .unchanged
        } catch {
            return .failed
        }
    }

    // MARK: - Derived

    /// The live discounts, keyed by place id. There are a handful at most, so
    /// this is cheaper to rebuild than to keep in step.
    var liveDeals: [String: Deal] {
        Dictionary(deals.filter(\.live).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func deal(for place: Place) -> Deal? { liveDeals[place.id] }

    /// The filter chips: the taxonomy types that at least one place uses, plus
    /// the discount chip when there is a live discount to filter to.
    var chips: [Chip] {
        let used = Set(places.flatMap(\.types))
        var result = taxonomy.types
            .filter { used.contains($0.id) }
            .map { Chip(id: $0.id, label: $0.label(in: lang)) }
        if !liveDeals.isEmpty {
            result.append(Chip(id: Self.dealFilter, label: strings("filterDiscount")))
        }
        return result
    }

    struct Chip: Identifiable, Hashable {
        let id: String
        let label: String
    }

    /// The list the map and the list screen both draw, in the reader's order.
    func visiblePlaces(near location: CLLocation? = nil) -> [Place] {
        let live = liveDeals
        let filtered = places.filter { place in
            guard place.matches(query, lang: lang) else { return false }
            guard !activeTypes.isEmpty else { return true }
            // OR semantics, matching the site: any selected chip is enough.
            if activeTypes.contains(Self.dealFilter), live[place.id] != nil { return true }
            return !activeTypes.isDisjoint(with: place.types)
        }
        return sorted(filtered, near: location)
    }

    /// Everything, ignoring the search box and the chips. The saved list is not
    /// the place to have a filter quietly applied to it.
    var allPlacesByName: [Place] {
        places.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func sorted(_ input: [Place], near location: CLLocation?) -> [Place] {
        switch sort {
        case .alphabetical:
            return input.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .newest:
            return byNewest(input)
        case .nearest:
            // No fix yet is not an error — fall back to the default order rather
            // than to an arbitrary one.
            guard let location else { return byNewest(input) }
            return input.sorted { distance(from: location, to: $0) < distance(from: location, to: $1) }
        }
    }

    /// Newest first, with an alphabetical tiebreak so places added on the same
    /// day do not shuffle between launches.
    private func byNewest(_ input: [Place]) -> [Place] {
        input.sorted {
            let left = $0.added ?? ""
            let right = $1.added ?? ""
            if left == right { return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return left > right
        }
    }

    func distance(from location: CLLocation, to place: Place) -> CLLocationDistance {
        CLLocation(latitude: place.lat, longitude: place.lng).distance(from: location)
    }

    func place(id: String) -> Place? {
        places.first { $0.id == id }
    }

    func typeLabels(for place: Place) -> [String] {
        place.types.compactMap { id in
            taxonomy.types.first { $0.id == id }?.label(in: lang)
        }
    }

    /// The site's dice button: one open place out of whatever is on screen.
    func randomPick(near location: CLLocation? = nil) -> Place? {
        visiblePlaces(near: location).filter { !$0.closed }.randomElement()
    }

    // MARK: - Language

    /// First launch picks up the phone's language when the site publishes it.
    /// The list is a starting guess only — the real set comes from `ui.json`,
    /// and `settleLanguage()` corrects anything the site does not have.
    private static func preferredLanguage() -> String {
        let offered = ["en", "et", "ru", "fi", "az", "pt", "es", "tr"]
        for preferred in Locale.preferredLanguages {
            let code = String(preferred.prefix(2)).lowercased()
            if offered.contains(code) { return code }
        }
        return Strings.fallbackLang
    }
}
