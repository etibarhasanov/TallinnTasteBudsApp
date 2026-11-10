import Foundation
import CoreLocation

/// A place anywhere in Tallinn, from the website's roll at `/api/places`: the
/// map's own places merged over the eleven hundred venues behind them.
///
/// The app keeps the map's places from `data/map.json`, so what it wants from
/// the roll is the rest of the city — and, for a place of the map's own, what
/// it cooks, which is how a search for "korean" finds Ariran when its write-up
/// never says the word.
struct Venue: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let address: String
    let lat: Double
    let lng: Double
    /// True for one of the map's own places; its `id` is then the map's id.
    let map: Bool
    /// The map's own words for what kind of place it is.
    let types: [String]
    /// What it cooks, in the directory's cuisine ids ("japanese").
    let kitchens: [String]
    /// The export's own word for it, "Sushi Restaurant": searched, never shown.
    let category: String
    let price: Double?
    let rating: Double?
    let reviews: Int?

    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
    var location: CLLocation { .init(latitude: lat, longitude: lng) }

    enum CodingKeys: String, CodingKey {
        case id, name, address, lat, lng, map, types, kitchens, category, price, rating, reviews
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        lat = try c.decode(Double.self, forKey: .lat)
        lng = try c.decode(Double.self, forKey: .lng)
        address = (try? c.decodeIfPresent(String.self, forKey: .address)) ?? ""
        map = (try? c.decodeIfPresent(Bool.self, forKey: .map)) ?? false
        types = (try? c.decodeIfPresent([String].self, forKey: .types)) ?? []
        kitchens = (try? c.decodeIfPresent([String].self, forKey: .kitchens)) ?? []
        category = (try? c.decodeIfPresent(String.self, forKey: .category)) ?? ""
        price = try? c.decodeIfPresent(Double.self, forKey: .price)
        rating = try? c.decodeIfPresent(Double.self, forKey: .rating)
        reviews = try? c.decodeIfPresent(Int.self, forKey: .reviews)
    }

    /// Every row that decodes; one that cannot is dropped on its own.
    static func decodeAll(_ data: Data) -> [Venue]? {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return nil }
        return raw.compactMap { item in
            guard let one = try? JSONSerialization.data(withJSONObject: item) else { return nil }
            return try? JSONDecoder().decode(Venue.self, from: one)
        }
    }

    /// The same venue as a row a list could carry, which is what the page for
    /// a place off the map is drawn from.
    var asListItem: ListItem {
        ListItem(place: id, name: name, address: address, lat: lat, lng: lng, map: map,
                 types: types, rating: rating, reviews: reviews)
    }
}

/// The cuisines a kitchen id is said as, in every language, from the
/// website's `data/cuisines.json`.
enum Cuisines {
    static func decode(_ data: Data) -> [String: [String: String]] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["cuisines"] as? [[String: Any]] else { return [:] }
        var out: [String: [String: String]] = [:]
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            var names: [String: String] = [:]
            for (key, value) in row where key.count == 2 {
                if let s = value as? String { names[key] = s }
            }
            out[id] = names
        }
        return out
    }
}
