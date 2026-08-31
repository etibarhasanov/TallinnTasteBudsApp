import CoreLocation
import Foundation

/// One approved place, decoded straight from the website's `data/restaurants.json`.
///
/// The field names and their meanings are fixed by `data/schema.json` in the
/// website repo. Anything optional there is optional here, and an empty string
/// means the same thing as a missing key — the site treats them identically, so
/// the decoder below folds them together.
struct Place: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let address: String
    let lat: Double
    let lng: Double
    /// Cost band, 1 to 4 in steps of a half, rendered as up to four euro signs
     /// where a half step lights half a sign. Not a rating: the site has none.
    let price: Double
    /// Type ids that exist in `taxonomy.json`.
    let types: [String]
    /// The write-up, keyed by language code. The only per-place translated field.
    let blurb: [String: String]
    let mustOrder: [String]
    /// Instagram or TikTok permalink, or nil when there is not one yet.
    let reel: URL?
    /// Photo filenames inside `photos/<id>/`.
    let photos: [String]
    let website: URL?
    let phone: String?
    /// `YYYY-MM-DD`, the day the place was added to the map.
    let added: String?
    /// `YYYY-MM`, the month last eaten there.
    let visited: String?
    let closed: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var hasVideo: Bool { reel != nil }

    /// TikTok and Instagram get different wording on the site, so keep them apart.
    var isTikTok: Bool { reel?.host?.contains("tiktok") == true }

    /// The blurb in `lang`, falling back the same way the site does: the asked-for
    /// language, then English, then whatever translation exists.
    func blurb(in lang: String) -> String {
        blurb[lang] ?? blurb["en"] ?? blurb.values.first ?? ""
    }

    /// Free-text haystack for the search field: name, street and dishes, which is
    /// exactly what the site searches.
    func matches(_ query: String, lang: String) -> Bool {
        guard !query.isEmpty else { return true }
        let needle = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let haystack = ([name, address] + mustOrder + [blurb(in: lang)])
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return haystack.contains(needle)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, address, lat, lng, price, types, blurb, mustOrder
        case reel, photos, website, phone, added, visited, closed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        address = try c.decode(String.self, forKey: .address)
        lat = try c.decode(Double.self, forKey: .lat)
        lng = try c.decode(Double.self, forKey: .lng)
        price = try c.decode(Double.self, forKey: .price)
        types = try c.decodeIfPresent([String].self, forKey: .types) ?? []
        blurb = try c.decodeIfPresent([String: String].self, forKey: .blurb) ?? [:]
        mustOrder = try c.decodeIfPresent([String].self, forKey: .mustOrder) ?? []
        photos = try c.decodeIfPresent([String].self, forKey: .photos) ?? []
        closed = try c.decodeIfPresent(Bool.self, forKey: .closed) ?? false
        phone = Self.nonEmpty(try c.decodeIfPresent(String.self, forKey: .phone))
        added = Self.nonEmpty(try c.decodeIfPresent(String.self, forKey: .added))
        visited = Self.nonEmpty(try c.decodeIfPresent(String.self, forKey: .visited))
        reel = Self.nonEmpty(try c.decodeIfPresent(String.self, forKey: .reel)).flatMap(URL.init(string:))
        website = Self.nonEmpty(try c.decodeIfPresent(String.self, forKey: .website)).flatMap(URL.init(string:))
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }
}
