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

    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
    var location: CLLocation { .init(latitude: lat, longitude: lng) }

    var photoURLs: [URL] { photos.map { API.photo(id, $0) } }

    /// "€€", the band rounded to whole signs; nil when the site gives none.
    var priceText: String? {
        guard let price, price > 0 else { return nil }
        return String(repeating: "€", count: max(1, min(4, Int(price.rounded()))))
    }

    enum CodingKeys: String, CodingKey {
        case id, name, address, lat, lng, price, types, mustOrder, reel, photos, website, phone, closed
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
