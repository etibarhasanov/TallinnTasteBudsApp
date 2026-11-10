import Foundation

/// A discount, as `data/deals.json` on the website writes it.
///
/// The offer is for everybody to read — it is what somebody is deciding on —
/// and the pass you hold up at the till is for members. A deal's `id` is a
/// place on the map, or Google's key for one that is not on it (a market that
/// agreed to a discount has not been eaten at and written up).
struct Deal: Identifiable, Decodable {
    let id: String
    let name: String
    let live: Bool
    let key: String
    let offer: [String: String]
    let terms: [String: String]
    /// "2026-09-01": the first and last days the pass is good, both optional.
    let from: String?
    let until: String?
    let roll: Roll?

    /// A rate that is drawn: `base − spread` up to `base + spread`, a `step`
    /// at a time. Each member is dealt one of them for the hour by the site.
    struct Roll: Decodable {
        let base: Int
        let spread: Int
        let step: Int
    }

    enum CodingKeys: String, CodingKey { case id, name, live, key, offer, terms, from, until, roll }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        key = try c.decode(String.self, forKey: .key)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        live = (try? c.decodeIfPresent(Bool.self, forKey: .live)) ?? false
        offer = (try? c.decodeIfPresent([String: String].self, forKey: .offer)) ?? [:]
        terms = (try? c.decodeIfPresent([String: String].self, forKey: .terms)) ?? [:]
        from = try? c.decodeIfPresent(String.self, forKey: .from)
        until = try? c.decodeIfPresent(String.self, forKey: .until)
        roll = try? c.decodeIfPresent(Roll.self, forKey: .roll)
    }

    /// Every deal that decodes; one that cannot is dropped on its own.
    static func decodeAll(_ data: Data) -> [Deal]? {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return nil }
        return raw.compactMap { item in
            guard let one = try? JSONSerialization.data(withJSONObject: item) else { return nil }
            return try? JSONDecoder().decode(Deal.self, from: one)
        }
    }

    /// The run of rates a rolled deal can land on, smallest first; nil for a
    /// deal with one fixed offer.
    var rates: [Int]? {
        guard let roll, roll.step > 0 else { return nil }
        return Array(stride(from: roll.base - roll.spread, through: roll.base + roll.spread, by: roll.step))
    }

    /// The offer in the reader's language. A rolled deal writes `{rate}` where
    /// the number goes: the drawn rate fills it on the pass, and before
    /// anything is drawn the run does — "5–25% off your order".
    func offerText(_ lang: String, rate: Int? = nil) -> String {
        let text = offer[lang] ?? offer["en"] ?? ""
        guard let run = rates, let first = run.first, let last = run.last else { return text }
        let shown = rate.map(String.init) ?? "\(first)–\(last)"
        return text.replacingOccurrences(of: "{rate}", with: shown)
    }

    func termsText(_ lang: String) -> String? {
        let text = terms[lang] ?? terms["en"]
        return (text?.isEmpty ?? true) ? nil : text
    }

    /// The pill beside a price: "−15%", taken from the offer line itself so
    /// Turkish keeps its sign in front ("−%15"), or nil for an offer with no
    /// percentage in it, where the word Discount stands in.
    func badge(_ lang: String) -> String? {
        let text = offerText(lang)
        let pattern = #"%\s*\d+(?:[.,]\d+)?(?:–\d+(?:[.,]\d+)?)?|\d+(?:[.,]\d+)?(?:–\d+(?:[.,]\d+)?)?\s*%"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return "−" + text[range].replacingOccurrences(of: " ", with: "")
    }

    enum Window { case notYet, open, ended }

    /// Whether today is inside the deal's dates, compared as the website does:
    /// as "yyyy-MM-dd" strings in the phone's own time zone.
    var window: Window {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())
        if let from, today < from { return .notYet }
        if let until, today > until { return .ended }
        return .open
    }

    /// Whether the map should show it at all.
    var shown: Bool { live && window != .ended }
}
