import Foundation
import CoreLocation

/// A list as a row in a directory: everybody's lists on `/api/lists?all=1`,
/// and the ones on a profile.
struct ListSummary: Identifiable, Hashable, Decodable {
    let id: String
    let title: String
    let by: String?
    let keeps: Int
    let pin: String?
    /// The names of the first few places, which is what a row says it is about.
    let taste: [String]
    /// Where its places are, as [lat, lng] pairs — drawn as a little map.
    let dots: [[Double]]
    let n: Int?
    /// Only on your own lists: whether anybody with the link can read it.
    let isPublic: Bool?

    enum CodingKeys: String, CodingKey { case id, title, by, keeps, pin, taste, dots, n, isPublic = "public" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        by = try? c.decodeIfPresent(String.self, forKey: .by)
        keeps = (try? c.decodeIfPresent(Int.self, forKey: .keeps)) ?? 0
        pin = try? c.decodeIfPresent(String.self, forKey: .pin)
        taste = (try? c.decodeIfPresent([String].self, forKey: .taste)) ?? []
        dots = (try? c.decodeIfPresent([[Double]].self, forKey: .dots)) ?? []
        n = try? c.decodeIfPresent(Int.self, forKey: .n)
        isPublic = try? c.decodeIfPresent(Bool.self, forKey: .isPublic)
    }
}

/// Your own lists and the ones you saved, from `/api/lists` signed in.
struct MyLists: Decodable {
    let lists: [ListSummary]
    let kept: [ListSummary]

    enum CodingKeys: String, CodingKey { case lists, kept }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lists = (try? c.decodeIfPresent([ListSummary].self, forKey: .lists)) ?? []
        kept = (try? c.decodeIfPresent([ListSummary].self, forKey: .kept)) ?? []
    }
}

/// A place in the search a list's places are picked from: the map's own and
/// Google's, from `/api/places?q=`.
struct CatalogueHit: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let address: String
    let map: Bool

    enum CodingKeys: String, CodingKey { case id, name, address, map }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        address = (try? c.decodeIfPresent(String.self, forKey: .address)) ?? ""
        map = (try? c.decodeIfPresent(Bool.self, forKey: .map)) ?? false
    }
}

/// One page of everybody's lists. `next` is the cursor for the page after it,
/// empty or absent on the last one.
struct ListsPage: Decodable {
    let all: [ListSummary]
    let next: String?

    enum CodingKeys: String, CodingKey { case all, next }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        all = (try? c.decodeIfPresent([ListSummary].self, forKey: .all)) ?? []
        // The cursor has been a string; take a number too rather than lose
        // every page after the first if it ever changes.
        if let s = try? c.decodeIfPresent(String.self, forKey: .next) {
            next = s.isEmpty ? nil : s
        } else if let n = try? c.decodeIfPresent(Double.self, forKey: .next) {
            next = String(format: "%.0f", n)
        } else {
            next = nil
        }
    }
}

/// A list read whole, from `/api/lists?id=<id>`.
struct ListDetail: Identifiable, Decodable {
    let id: String
    let title: String
    let intro: String
    let by: String?
    let mine: Bool
    let pin: String?
    let keeps: Int
    let kept: Bool
    let isPublic: Bool
    let items: [ListItem]

    enum CodingKeys: String, CodingKey { case id, title, intro, by, mine, pin, keeps, kept, items, isPublic = "public" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        intro = (try? c.decodeIfPresent(String.self, forKey: .intro)) ?? ""
        by = try? c.decodeIfPresent(String.self, forKey: .by)
        mine = (try? c.decodeIfPresent(Bool.self, forKey: .mine)) ?? false
        pin = try? c.decodeIfPresent(String.self, forKey: .pin)
        keeps = (try? c.decodeIfPresent(Int.self, forKey: .keeps)) ?? 0
        kept = (try? c.decodeIfPresent(Bool.self, forKey: .kept)) ?? false
        isPublic = (try? c.decodeIfPresent(Bool.self, forKey: .isPublic)) ?? true
        items = (try? c.decodeIfPresent([ListItem].self, forKey: .items)) ?? []
    }
}

struct ListEnvelope: Decodable { let list: ListDetail? }

/// One place on a list: the author's note about it, and enough about the place
/// to draw it even when it is not on the map — a Google venue or one somebody
/// typed in by hand.
struct ListItem: Identifiable, Hashable, Decodable {
    /// The map's id for a place on the map; Google's place id otherwise.
    let place: String
    let name: String
    let address: String
    let lat: Double?
    let lng: Double?
    /// True when this is one of the places on the map.
    let map: Bool
    let google: Bool
    let types: [String]
    let rating: Double?
    let reviews: Int?
    let phone: String
    let website: String
    /// Seven entries, Sunday first, "12:00-00:00" or null for closed.
    let hours: [String?]
    let mapsUrl: String
    /// What the author wrote about it.
    let say: String
    let mustOrder: String

    var id: String { place }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return .init(latitude: lat, longitude: lng)
    }

    /// A row made here rather than read: a venue found by the search, drawn
    /// with the same page a list's place off the map gets.
    init(place: String, name: String, address: String, lat: Double?, lng: Double?, map: Bool,
         types: [String], rating: Double?, reviews: Int?) {
        self.place = place
        self.name = name
        self.address = address
        self.lat = lat
        self.lng = lng
        self.map = map
        self.google = !map
        self.types = types
        self.rating = rating
        self.reviews = reviews
        phone = ""
        website = ""
        hours = []
        mapsUrl = ""
        say = ""
        mustOrder = ""
    }

    enum CodingKeys: String, CodingKey {
        case place, name, address, lat, lng, map, google, types, rating, reviews, phone, website, hours, mapsUrl, say, mustOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        place = try c.decode(String.self, forKey: .place)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        address = (try? c.decodeIfPresent(String.self, forKey: .address)) ?? ""
        lat = try? c.decodeIfPresent(Double.self, forKey: .lat)
        lng = try? c.decodeIfPresent(Double.self, forKey: .lng)
        map = (try? c.decodeIfPresent(Bool.self, forKey: .map)) ?? false
        google = (try? c.decodeIfPresent(Bool.self, forKey: .google)) ?? false
        types = (try? c.decodeIfPresent([String].self, forKey: .types)) ?? []
        rating = try? c.decodeIfPresent(Double.self, forKey: .rating)
        reviews = try? c.decodeIfPresent(Int.self, forKey: .reviews)
        phone = (try? c.decodeIfPresent(String.self, forKey: .phone)) ?? ""
        website = (try? c.decodeIfPresent(String.self, forKey: .website)) ?? ""
        hours = (try? c.decodeIfPresent([String?].self, forKey: .hours)) ?? []
        mapsUrl = (try? c.decodeIfPresent(String.self, forKey: .mapsUrl)) ?? ""
        say = (try? c.decodeIfPresent(String.self, forKey: .say)) ?? ""
        mustOrder = (try? c.decodeIfPresent(String.self, forKey: .mustOrder)) ?? ""
    }
}

/// Somebody's page, `/u/<name>`: who they are, where else they are, and the
/// lists they published.
struct Profile: Decodable {
    let name: String
    let display: String?
    let face: String?
    let about: String?
    /// The about line in other languages, by code.
    let lines: [String: String]
    /// Handles on other sites: "instagram": "tallinntastebuds".
    let links: [String: String]
    let lists: [ListSummary]
    let rows: [ProfileRow]

    enum CodingKeys: String, CodingKey { case name, display, face, about, lines, links, lists, rows }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        display = try? c.decodeIfPresent(String.self, forKey: .display)
        face = try? c.decodeIfPresent(String.self, forKey: .face)
        about = try? c.decodeIfPresent(String.self, forKey: .about)
        lines = (try? c.decodeIfPresent([String: String].self, forKey: .lines)) ?? [:]
        links = (try? c.decodeIfPresent([String: String].self, forKey: .links)) ?? [:]
        lists = (try? c.decodeIfPresent([ListSummary].self, forKey: .lists)) ?? []
        rows = (try? c.decodeIfPresent([ProfileRow].self, forKey: .rows)) ?? []
    }

    func aboutLine(_ lang: String) -> String? {
        let line = lines[lang] ?? about
        return (line?.isEmpty ?? true) ? nil : line
    }
}

struct ProfileEnvelope: Decodable { let profile: Profile? }

/// A row on a profile's page of links: a heading, a note, or a link.
struct ProfileRow: Hashable, Decodable {
    let title: String
    let note: String
    let url: String

    enum CodingKeys: String, CodingKey { case title, note, url }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        note = (try? c.decodeIfPresent(String.self, forKey: .note)) ?? ""
        url = (try? c.decodeIfPresent(String.self, forKey: .url)) ?? ""
    }
}

/// The marker a list chose for its places, by the name the site stores.
/// The same forty as `assets/pins.js`; anything unknown is the map pin.
enum Pins {
    static let emoji: [String: String] = [
        "pin": "📍", "flag": "🚩", "flame": "🔥", "sun": "☀️", "heart": "❤️",
        "blossom": "🌸", "gem": "💎", "balloon": "🎈", "laptop": "💻", "star": "⭐️",
        "rainbow": "🌈", "cat": "🐱", "bow": "🎀", "sparkles": "✨", "music": "🎵",
        "moon": "🌙", "dog": "🐶", "unicorn": "🦄", "bunny": "🐰", "bear": "🐻",
        "panda": "🐼", "fox": "🦊", "frog": "🐸", "chick": "🐥", "penguin": "🐧",
        "octopus": "🐙", "whale": "🐳", "ladybird": "🐞", "sunflower": "🌻", "tulip": "🌷",
        "cactus": "🌵", "snowflake": "❄️", "cloud": "☁️", "gift": "🎁", "camera": "📷",
        "books": "📚", "teddy": "🧸", "ghost": "👻", "turtle": "🐢", "hedgehog": "🦔"
    ]

    /// The picker's order, which is the website's grid read left to right.
    static let order = [
        "pin", "flag", "flame", "sun", "heart", "blossom", "gem", "balloon", "laptop", "star",
        "rainbow", "cat", "bow", "sparkles", "music", "moon", "dog", "unicorn", "bunny", "bear",
        "panda", "fox", "frog", "chick", "penguin", "octopus", "whale", "ladybird", "sunflower", "tulip",
        "cactus", "snowflake", "cloud", "gift", "camera", "books", "teddy", "ghost", "turtle", "hedgehog"
    ]

    static func of(_ name: String?) -> String {
        guard let name, let e = emoji[name] else { return "📍" }
        return e
    }
}
