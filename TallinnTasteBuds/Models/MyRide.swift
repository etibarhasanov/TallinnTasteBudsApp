import Foundation
import CoreLocation

/// The rides the signed-in person recorded, as `GET /api/rides` answers them
/// with no query: newest first, names and numbers, no lines. The website's
/// `functions/api/rides.js`, `mine()`.
struct MyRides: Decodable {
    let user: String?
    let rides: [MyRide]

    enum CodingKeys: String, CodingKey { case user, rides }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user = try? c.decodeIfPresent(String.self, forKey: .user)
        rides = (try? c.decodeIfPresent([MyRide].self, forKey: .rides)) ?? []
    }
}

struct MyRide: Decodable, Identifiable, Hashable {
    let id: String
    var name: String
    let meters: Double
    let seconds: Double
    /// Milliseconds since 1970, the site's `created_at`.
    let at: Double
    /// Whether the ride has the times its speeds are made of.
    let timed: Bool

    var date: Date { Date(timeIntervalSince1970: at / 1000) }

    enum CodingKeys: String, CodingKey { case id, name, meters, seconds, at, timed }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        meters = (try? c.decodeIfPresent(Double.self, forKey: .meters)) ?? 0
        seconds = (try? c.decodeIfPresent(Double.self, forKey: .seconds)) ?? 0
        at = (try? c.decodeIfPresent(Double.self, forKey: .at)) ?? 0
        timed = (try? c.decodeIfPresent(Bool.self, forKey: .timed)) ?? false
    }
}

/// One ride whole, `GET /api/rides/<id>`: its line and what the site worked
/// out of it — `functions/api/_rides.js`, `rideInsight()`. Everything past the
/// average is there only when `timed`.
struct RideDetail: Decodable {
    let id: String
    var name: String
    let meters: Double
    let seconds: Double
    let at: Double
    let line: [[Double]]
    let insight: Insight

    var date: Date { Date(timeIntervalSince1970: at / 1000) }
    var coordinates: [CLLocationCoordinate2D] { RouteAnswer.points(line) }

    struct Insight: Decodable {
        let average: Double?
        let timed: Bool
        let top: Double?
        let stopped: Double?
        let fastest: Split?
        let splits: [Split]
        let speed: [Speed]

        enum CodingKeys: String, CodingKey { case average, timed, top, stopped, fastest, splits, speed }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            average = try? c.decodeIfPresent(Double.self, forKey: .average)
            timed = (try? c.decodeIfPresent(Bool.self, forKey: .timed)) ?? false
            top = try? c.decodeIfPresent(Double.self, forKey: .top)
            stopped = try? c.decodeIfPresent(Double.self, forKey: .stopped)
            fastest = try? c.decodeIfPresent(Split.self, forKey: .fastest)
            splits = (try? c.decodeIfPresent([Split].self, forKey: .splits)) ?? []
            speed = (try? c.decodeIfPresent([Speed].self, forKey: .speed)) ?? []
        }
    }

    /// One kilometre's moving time; the last one is however long it is.
    /// `fastest` carries no `meters`, being a whole kilometre by definition.
    struct Split: Decodable, Hashable {
        let km: Int
        let meters: Double?
        let seconds: Double
        var kmh: Double { seconds > 0 ? (meters ?? 1000) / seconds * 3.6 : 0 }
    }

    /// The speed over the stretch ending `at` metres along.
    struct Speed: Decodable, Hashable {
        let at: Double
        let kmh: Double
    }
}

/// The answer `RideDetail` comes in.
struct RideAnswer: Decodable {
    let ride: RideDetail
}

/// How the ride pages say a distance, a time and a speed — the website's
/// `askKm`, `askMetres` and `walkMin`, so they read the same in every
/// language the site speaks.
@MainActor
enum RideWords {
    static func distance(_ meters: Double, _ content: ContentStore) -> String {
        meters < 1000
            ? content.t("askMetres", "{n} m", ["n": String(Int((meters / 10).rounded()) * 10)])
            : content.t("askKm", "{n} km", ["n": String(format: "%.1f", meters / 1000)])
    }

    /// Minutes under an hour, then "1 h 12".
    static func time(_ seconds: Double, _ content: ContentStore) -> String {
        let minutes = max(1, Int((seconds / 60).rounded()))
        return minutes < 60
            ? content.t("walkMin", "{n} min", ["n": String(minutes)])
            : "\(minutes / 60) h \(String(format: "%02d", minutes % 60))"
    }

    /// A split's time, "3:05".
    static func clock(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    static func speed(_ kmh: Double, _ content: ContentStore) -> String {
        content.t("rideKmh", "{n} km/h", ["n": String(format: "%.1f", kmh)])
    }

    /// "18 Nov", in the site's month names.
    static func day(_ date: Date, _ content: ContentStore) -> String {
        let parts = Calendar.current.dateComponents([.day, .month], from: date)
        let months = content.t("months", "January|February|March|April|May|June|July|August|September|October|November|December")
            .split(separator: "|").map(String.init)
        let month = months.indices.contains((parts.month ?? 1) - 1) ? months[(parts.month ?? 1) - 1] : ""
        return "\(parts.day ?? 1) \(month.prefix(3))"
    }
}
