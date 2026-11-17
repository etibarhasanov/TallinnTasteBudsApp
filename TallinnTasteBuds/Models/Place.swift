import Foundation
import CoreLocation

/// A place on the map, as `data/map.json` writes it: the website's own
/// catalogue without the write-ups, which come per language from
/// `data/lang/<code>.json` instead.
///
/// Decoding is lenient on purpose. A key the site adds tomorrow is ignored, a
/// key it drops falls back to empty, and a place that cannot be read at all is
/// skipped by `Place.decodeAll` rather than taking the other seventy-eight down
/// with it.
struct Place: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let address: String
    let lat: Double
    let lng: Double
    let price: Double?
    let types: [String]
    let mustOrder: [String]
    let reel: String
    let photos: [String]
    let website: String
    let phone: String
    let closed: Bool
    /// Words of the write-up that open somewhere on the site — "@tallinnbits",
    /// "their list of new cafés" — in `data/map.json`'s `links`.
    let links: [BlurbLink]
    /// The day it went on the map, "2026-11-13", for New on the map;
    /// empty for the places older than the field.
    let added: String

    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
    var location: CLLocation { .init(latitude: lat, longitude: lng) }

    var photoURLs: [URL] { photos.map { API.photo(id, $0) } }

    /// "€€", the band rounded to whole signs; nil when the site gives none.
    var priceText: String? {
        guard let price, price > 0 else { return nil }
        return String(repeating: "€", count: max(1, min(4, Int(price.rounded()))))
    }

    enum CodingKeys: String, CodingKey {
        case id, name, address, lat, lng, price, types, mustOrder, reel, photos, website, phone, closed, links, added
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        lat = try c.decode(Double.self, forKey: .lat)
        lng = try c.decode(Double.self, forKey: .lng)
        address = (try? c.decodeIfPresent(String.self, forKey: .address)) ?? ""
        price = try? c.decodeIfPresent(Double.self, forKey: .price)
        types = (try? c.decodeIfPresent([String].self, forKey: .types)) ?? []
        mustOrder = (try? c.decodeIfPresent([String].self, forKey: .mustOrder)) ?? []
        reel = (try? c.decodeIfPresent(String.self, forKey: .reel)) ?? ""
        photos = (try? c.decodeIfPresent([String].self, forKey: .photos)) ?? []
        website = (try? c.decodeIfPresent(String.self, forKey: .website)) ?? ""
        phone = (try? c.decodeIfPresent(String.self, forKey: .phone)) ?? ""
        closed = (try? c.decodeIfPresent(Bool.self, forKey: .closed)) ?? false
        links = (try? c.decodeIfPresent([BlurbLink].self, forKey: .links)) ?? []
        added = (try? c.decodeIfPresent(String.self, forKey: .added)) ?? ""
    }

    /// Every place that decodes; the ones that do not are dropped one by one.
    static func decodeAll(_ data: Data) -> [Place]? {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return nil }
        return raw.compactMap { item in
            guard let one = try? JSONSerialization.data(withJSONObject: item) else { return nil }
            return try? JSONDecoder().decode(Place.self, from: one)
        }
    }
}

/// A phrase of a write-up that is a link: an address on the site, and the
/// words it is drawn on — one string where every language says the same thing
/// (an @name), or one per language where it does not. The write-up itself
/// stays plain text, the way the website keeps it.
struct BlurbLink: Hashable, Decodable {
    let href: String
    let words: [String: String]

    enum CodingKeys: String, CodingKey { case href, text }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        href = try c.decode(String.self, forKey: .href)
        if let one = try? c.decode(String.self, forKey: .text) {
            words = ["": one]
        } else {
            words = try c.decode([String: String].self, forKey: .text)
        }
    }

    func text(_ lang: String) -> String? { words[""] ?? words[lang] }

    /// Where it goes in the app: a profile or a list opens here, anything
    /// else on the website.
    var route: Route? {
        guard let url = URL(string: href, relativeTo: API.base) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        if parts.count == 2, parts[0] == "u" { return .profile(parts[1]) }
        if parts.count == 2, parts[0] == "list" { return .list(parts[1]) }
        if let list = URLComponents(url: url, resolvingAgainstBaseURL: true)?
            .queryItems?.first(where: { $0.name == "list" })?.value { return .list(list) }
        return nil
    }
}

/// One kind of place — Coffee, Bakery, Hidden gem — with its name in every
/// language, from `data/taxonomy.json`.
struct PlaceType: Identifiable, Hashable {
    let id: String
    let names: [String: String]
    /// The site keeps some types off the chip row (Tea is searched for, not
    /// pressed). The same rule holds here.
    let chip: Bool
    /// Extra words a search for this type should also match, slash-separated
    /// on the site: "espresso/cappuccino/latte…".
    let words: [String]

    func name(_ lang: String) -> String { names[lang] ?? names["en"] ?? id }

    static func decodeAll(_ data: Data) -> [PlaceType]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let types = root["types"] as? [[String: Any]] else { return nil }
        return types.compactMap { t in
            guard let id = t["id"] as? String else { return nil }
            var names: [String: String] = [:]
            for (key, value) in t where key.count == 2 {
                if let s = value as? String { names[key] = s }
            }
            let words = (t["words"] as? String)?.split(separator: "/").map(String.init) ?? []
            return PlaceType(id: id, names: names, chip: (t["chip"] as? Bool) ?? true, words: words)
        }
    }
}
