import Foundation

/// `data/deals.json`. The rotating code itself is never computed here — the app
/// links out to the website's own discount page, so the one implementation of
/// the code stays where the staff verifier can be sure of it.
struct Deal: Identifiable, Hashable, Decodable {
    /// Matches a `Place.id`.
    let id: String
    let live: Bool
    /// The offer text per language, e.g. "15% off your order".
    let offer: [String: String]

    func offer(in lang: String) -> String {
        offer[lang] ?? offer["en"] ?? offer.values.first ?? ""
    }

    private enum CodingKeys: String, CodingKey { case id, live, offer }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        live = try c.decodeIfPresent(Bool.self, forKey: .live) ?? false
        offer = try c.decodeIfPresent([String: String].self, forKey: .offer) ?? [:]
    }
}
