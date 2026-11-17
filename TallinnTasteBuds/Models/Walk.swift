import Foundation
import CoreLocation

/// What `/api/walk?list=<id>` answers, and every POST to it answers the same:
/// whether the tables are there, who is asking, how near a door counts, the
/// reader's own walk and checks, everybody who finished it, and everybody's
/// comments. `functions/api/walk.js` on the website is the whole of it.
struct WalkAnswer: Decodable {
    let ready: Bool
    let user: String?
    let radius: Double
    let walk: Walk?
    let checks: [Check]
    let board: [Finisher]
    let notes: [Note]
    /// The place a check just checked, on the answer to a check.
    let checked: String?

    struct Walk: Decodable {
        let started: Double
        let finished: Double?
        let mode: String
        let note: String
        let order: [String]

        enum CodingKeys: String, CodingKey { case started, finished, mode, note, order }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            started = (try? c.decode(Double.self, forKey: .started)) ?? 0
            finished = try? c.decodeIfPresent(Double.self, forKey: .finished)
            mode = (try? c.decodeIfPresent(String.self, forKey: .mode)) ?? ""
            note = (try? c.decodeIfPresent(String.self, forKey: .note)) ?? ""
            order = (try? c.decodeIfPresent([String].self, forKey: .order)) ?? []
        }
    }

    struct Check: Decodable {
        let place: String
        let at: Double
        let note: String

        enum CodingKeys: String, CodingKey { case place, at, note }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            place = try c.decode(String.self, forKey: .place)
            at = (try? c.decode(Double.self, forKey: .at)) ?? 0
            note = (try? c.decodeIfPresent(String.self, forKey: .note)) ?? ""
        }
    }

    struct Finisher: Decodable, Identifiable {
        let name: String
        let started: Double
        let finished: Double
        let mode: String
        let note: String
        var id: String { name }

        enum CodingKeys: String, CodingKey { case name, started, finished, mode, note }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = (try? c.decode(String.self, forKey: .name)) ?? ""
            started = (try? c.decode(Double.self, forKey: .started)) ?? 0
            finished = (try? c.decode(Double.self, forKey: .finished)) ?? 0
            mode = (try? c.decodeIfPresent(String.self, forKey: .mode)) ?? ""
            note = (try? c.decodeIfPresent(String.self, forKey: .note)) ?? ""
        }
    }

    struct Note: Decodable {
        let place: String
        let name: String
        let note: String
    }

    enum CodingKeys: String, CodingKey { case ready, user, radius, walk, checks, board, notes, checked }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ready = (try? c.decodeIfPresent(Bool.self, forKey: .ready)) ?? false
        user = try? c.decodeIfPresent(String.self, forKey: .user)
        radius = (try? c.decodeIfPresent(Double.self, forKey: .radius)) ?? 75
        walk = try? c.decodeIfPresent(Walk.self, forKey: .walk)
        checks = (try? c.decodeIfPresent([Check].self, forKey: .checks)) ?? []
        board = (try? c.decodeIfPresent([Finisher].self, forKey: .board)) ?? []
        notes = (try? c.decodeIfPresent([Note].self, forKey: .notes)) ?? []
        checked = try? c.decodeIfPresent(String.self, forKey: .checked)
    }
}

/// The reader's own walks still going, from `/api/walk?mine=1`, for the front
/// of Discover's Play card.
struct MyWalks: Decodable {
    let walks: [Going]

    struct Going: Decodable, Identifiable {
        let id: String
        let title: String
        let pin: String?
        let checked: Int
        let total: Int
    }

    enum CodingKeys: String, CodingKey { case walks }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        walks = (try? c.decodeIfPresent([Going].self, forKey: .walks)) ?? []
    }
}

/// The arithmetic of a walk, the website's `assets/walk.js` to the number:
/// a straight line stretched by 1.3 for the streets, the true shortest order
/// up to twelve places (Held–Karp, start fixed, end free) and nearest-next
/// with crossed legs uncrossed past that, and the three paces the card
/// estimates with.
enum WalkMath {
    static let detour = 1.3
    /// Metres a minute.
    static let foot = 80.0, bike = 250.0, car = 400.0
    static let exactUpTo = 12

    /// The straight line, which is what a check is measured by.
    static func crow(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let rad = Double.pi / 180
        let dLat = (b.latitude - a.latitude) * rad
        let dLng = (b.longitude - a.longitude) * rad
        let s = sin(dLat / 2) * sin(dLat / 2) +
            cos(a.latitude * rad) * cos(b.latitude * rad) * sin(dLng / 2) * sin(dLng / 2)
        return 2 * 6_371_000 * asin(sqrt(s))
    }

    /// The walk between two points, as near as a straight line can say.
    static func metres(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double { crow(a, b) * detour }

    static func length(_ points: [CLLocationCoordinate2D]) -> Double {
        zip(points, points.dropFirst()).reduce(0) { $0 + metres($1.0, $1.1) }
    }

    /// The points in the shortest order from `start`, as indexes into them.
    static func shortest(_ points: [CLLocationCoordinate2D], from start: Int) -> [Int] {
        if points.count < 3 {
            return [start] + points.indices.filter { $0 != start }
        }
        let index = [start] + points.indices.filter { $0 != start }
        let d = index.map { a in index.map { b in metres(points[a], points[b]) } }
        let order = points.count <= exactUpTo ? exact(d) : near(d)
        return order.map { index[$0] }
    }

    private static func exact(_ d: [[Double]]) -> [Int] {
        let n = d.count - 1
        let full = (1 << n) - 1
        var best = Array(repeating: Array(repeating: Double.infinity, count: n), count: full + 1)
        var from = Array(repeating: Array(repeating: -1, count: n), count: full + 1)
        for j in 0..<n { best[1 << j][j] = d[0][j + 1] }
        for set in 1...full {
            for j in 0..<n where set & (1 << j) != 0 && best[set][j] < .infinity {
                for k in 0..<n where set & (1 << k) == 0 {
                    let was = set | (1 << k)
                    let cost = best[set][j] + d[j + 1][k + 1]
                    if cost < best[was][k] {
                        best[was][k] = cost
                        from[was][k] = j
                    }
                }
            }
        }
        var end = 0
        for j in 1..<n where best[full][j] < best[full][end] { end = j }
        var order: [Int] = []
        var set = full
        while end != -1 {
            order.insert(end + 1, at: 0)
            let k = from[set][end]
            set &= ~(1 << end)
            end = k
        }
        return [0] + order
    }

    private static func near(_ d: [[Double]]) -> [Int] {
        let n = d.count
        var order = [0]
        var left = Array(1..<n)
        while !left.isEmpty {
            let at = order.last!
            var pick = 0
            for i in 1..<left.count where d[at][left[i]] < d[at][left[pick]] { pick = i }
            order.append(left.remove(at: pick))
        }
        var moved = true
        while moved {
            moved = false
            for i in 1..<(n - 1) {
                for j in (i + 1)..<n {
                    let a = d[order[i - 1]][order[i]] + (j + 1 < n ? d[order[j]][order[j + 1]] : 0)
                    let b = d[order[i - 1]][order[j]] + (j + 1 < n ? d[order[i]][order[j + 1]] : 0)
                    if a - b > 0.5 {
                        order.replaceSubrange(i...j, with: order[i...j].reversed())
                        moved = true
                    }
                }
            }
        }
        return order
    }
}
