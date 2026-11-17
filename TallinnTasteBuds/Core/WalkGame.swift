import Foundation
import CoreLocation
import Observation

/// Going round a list: the website's `assets/walk.js`, as one object the
/// list's Route view and its map both read, so the map keeps no copy of what
/// is checked or of a comment half typed.
///
/// A member starts a walk on any list they can read, goes to each place and
/// presses Check in while standing there. The phone's position goes to
/// `/api/walk` with the press and nowhere else; the server checks whichever
/// unchecked place is nearest if it is within its radius, so the places can
/// be walked in any order, over as many days as it takes, and keeps the
/// place and the time — never the coordinates. Whoever finishes is on the
/// list's board, fastest first.
///
/// The order is a suggestion worked out here, `WalkMath.shortest`, from the
/// list's first place or from where Start from where I am was pressed; it is
/// stored with the walk so it follows the walker to the website. The one
/// thing the app leaves out for now is dragging the order by hand.
@MainActor
@Observable
final class WalkGame {
    let list: ListDetail

    private(set) var answer: WalkAnswer?
    private(set) var loaded = false
    /// What the last press said: a check that landed, or why it did not.
    private(set) var message: (text: String, bad: Bool)?
    private(set) var busy: Busy?
    /// The walker's own order, by place; nil is the shortest.
    private(set) var own: [String]?
    /// Where Start from where I am was pressed; the order starts nearest it.
    private(set) var from: CLLocationCoordinate2D?
    /// The order was just made again from where the walker stood.
    private(set) var replanned = false
    /// What a comment is being written on: a place, "" for the whole of a
    /// finished walk, or nil.
    var noting: String?
    /// The walk just finished was offered its comment once already.
    var asked = false
    /// Start again is being asked about.
    var asking = false

    enum Busy { case here, start, check, mode, note, again }

    init(list: ListDetail) { self.list = list }

    // MARK: Reading

    var started: Bool { answer?.walk != nil }
    var finished: Bool { answer?.walk?.finished != nil }
    var ready: Bool { answer?.ready ?? false }
    var signedIn: Bool { answer?.user != nil }
    var radius: Double { answer?.radius ?? 75 }

    /// The places somebody can stand at.
    var doors: [ListItem] { list.items.filter { $0.coordinate != nil } }

    func check(_ place: String) -> WalkAnswer.Check? { answer?.checks.first { $0.place == place } }

    /// The places in the order on screen.
    var stops: [ListItem] {
        if let own { return ordered(own) }
        return shortOrder
    }

    private var shortOrder: [ListItem] {
        let all = doors
        guard !all.isEmpty else { return [] }
        var start = 0
        if let from {
            for (i, item) in all.enumerated()
            where WalkMath.metres(from, item.coordinate!) < WalkMath.metres(from, all[start].coordinate!) { start = i }
        }
        return WalkMath.shortest(all.map { $0.coordinate! }, from: start).map { all[$0] }
    }

    /// An order held to the list as it is now: a place that has left drops
    /// out and one that has joined goes on the end.
    private func ordered(_ places: [String]) -> [ListItem] {
        let all = doors
        var out: [ListItem] = []
        for place in places {
            if let item = all.first(where: { $0.place == place }), !out.contains(item) { out.append(item) }
        }
        return out + all.filter { !out.contains($0) }
    }

    /// Metres from the first stop to each, the last being the whole.
    var sofar: [Double] {
        var out: [Double] = []
        var total = 0.0
        for (i, item) in stops.enumerated() {
            if i > 0 { total += WalkMath.metres(stops[i - 1].coordinate!, item.coordinate!) }
            out.append(total)
        }
        return out
    }

    var total: Double { sofar.last ?? 0 }

    /// How much longer the walker's own order is than the shortest.
    var longerBy: Double {
        own == nil ? 0 : total - WalkMath.length(shortOrder.map { $0.coordinate! })
    }

    var left: [ListItem] { stops.filter { check($0.place) == nil } }

    /// The next place in the order, which the rail rings.
    var next: ListItem? { started && !finished ? left.first : nil }

    /// The nearest place left from `here`, and how far, as the crow flies.
    func nearest(to here: CLLocation?) -> (item: ListItem, metres: Double)? {
        guard let here else { return nil }
        return doors.filter { check($0.place) == nil }
            .map { ($0, WalkMath.crow(here.coordinate, $0.coordinate!)) }
            .min { $0.1 < $1.1 }
    }

    // MARK: The server

    func load() async {
        do {
            let got = try await API.get(WalkAnswer.self, "api/walk", ["list": list.id])
            land(got)
        } catch {
            loaded = true
        }
    }

    private func land(_ got: WalkAnswer) {
        answer = got
        loaded = true
        if let order = got.walk?.order, !order.isEmpty { own = order }
    }

    private func send(_ body: [String: Any]) async throws -> WalkAnswer {
        var body = body
        body["list"] = list.id
        let object = try await API.post("api/walk", body)
        let data = try JSONSerialization.data(withJSONObject: object)
        return try API.decoder.decode(WalkAnswer.self, from: data)
    }

    // MARK: The presses

    func fromMe(_ here: CLLocation?, words: WalkWords) {
        guard let here else { message = (words.t("walkNoLocation", "A check needs your location. Allow it in the browser and press again."), true); return }
        from = here.coordinate
        own = nil
        message = nil
    }

    /// Shortest from here: the places checked to the top in the order they
    /// were checked, and the ones left under them in the shortest order from
    /// the phone. A press and never the watch, or every place would be
    /// renumbered as its walker moved.
    func replan(_ here: CLLocation?, words: WalkWords) async {
        guard let here else { message = (words.t("walkNoLocation", "A check needs your location. Allow it in the browser and press again."), true); return }
        let left = self.left
        let done = doors.filter { check($0.place) != nil }.sorted { (check($0.place)?.at ?? 0) < (check($1.place)?.at ?? 0) }
        let order = WalkMath.shortest([here.coordinate] + left.map { $0.coordinate! }, from: 0).dropFirst().map { left[$0 - 1] }
        own = (done + order).map(\.place)
        replanned = true
        message = nil
        await keepOrder()
    }

    func shortestAgain() async {
        own = nil
        from = nil
        await keepOrder()
    }

    private func keepOrder() async {
        guard started else { return }
        if let got = try? await send(["action": "order", "order": own ?? []]) { land(got) }
    }

    func start(words: WalkWords) async {
        busy = .start
        defer { busy = nil }
        do {
            let got = try await send(["action": "start", "order": own ?? []])
            land(got)
            message = nil
        } catch {
            message = (words.t("walkErr", "That did not go through. Try again."), true)
        }
    }

    func checkIn(at here: CLLocation?, words: WalkWords) async {
        noting = nil
        message = nil
        guard let here else {
            message = (words.t("walkNoLocation", "A check needs your location. Allow it in the browser and press again."), true)
            return
        }
        busy = .check
        defer { busy = nil }
        do {
            let got = try await send(["action": "check", "lat": here.coordinate.latitude, "lng": here.coordinate.longitude])
            if let place = got.checked {
                let name = doors.first { $0.place == place }?.name ?? ""
                message = (words.t("walkCheckedAt", "Checked in at {place} · {n} of {total}",
                                   ["place": name, "n": "\(got.checks.count)", "total": "\(doors.count)"]), false)
                noting = place
                replanned = false
            }
            land(got)
        } catch let refusal as API.Refusal where refusal.code == "far" {
            message = (far(refusal, words), true)
        } catch {
            message = (words.t("walkErr", "That did not go through. Try again."), true)
        }
    }

    /// "You are 140 m from Koht, the nearest place left. Come within 75 m."
    private func far(_ refusal: API.Refusal, _ words: WalkWords) -> String {
        let r = "\(Int(radius))"
        if let place = refusal.place, let item = doors.first(where: { $0.place == place }),
           let metres = refusal.meters {
            return words.t("walkFar", "You are {distance} from {place}, the nearest place left. Come within {radius} m.",
                           ["distance": words.distance(metres), "place": item.name, "radius": r])
        }
        return words.t("walkFarAway", "You are not near any place on this list. Come within {radius} m of one.", ["radius": r])
    }

    /// How they went round, once it is finished.
    func setMode(_ mode: String, words: WalkWords) async {
        guard busy == nil, mode != answer?.walk?.mode else { return }
        busy = .mode
        defer { busy = nil }
        do {
            let got = try await send(["action": "mode", "mode": mode])
            land(got)
        } catch {
            message = (words.t("walkErr", "That did not go through. Try again."), true)
        }
    }

    /// A comment on a place checked in at, or with "" on the whole walk.
    func saveNote(_ place: String, _ text: String, words: WalkWords) async {
        if place.isEmpty { asked = true }
        busy = .note
        defer { busy = nil }
        do {
            let got = try await send(["action": "note", "place": place, "note": String(text.prefix(280))])
            land(got)
            noting = nil
            message = nil
        } catch {
            message = (words.t("walkErr", "That did not go through. Try again."), true)
        }
    }

    func skipNote() {
        if noting == "" { asked = true }
        noting = nil
        message = nil
    }

    /// Throws the walk away — its checks, comments and time on the board.
    func again(words: WalkWords) async {
        busy = .again
        defer { busy = nil }
        do {
            let got = try await send(["action": "again"])
            asking = false
            asked = false
            noting = nil
            replanned = false
            message = nil
            own = nil
            land(got)
        } catch {
            message = (words.t("walkErr", "That did not go through. Try again."), true)
        }
    }

    /// What the band would offer to write on, if anything: a comment on the
    /// place just checked, or — once — on the whole of a walk just finished.
    var writingOn: String? {
        if let noting { return noting }
        if finished, answer?.walk?.note.isEmpty ?? true, !asked { return "" }
        return nil
    }
}

/// The words a walk is said in, the website's `distance()`, `minutes()`,
/// `took()` and `day()`, in the reader's language.
@MainActor
struct WalkWords {
    let content: ContentStore

    func t(_ key: String, _ english: String, _ args: [String: String] = [:]) -> String {
        content.t(key, english, args)
    }

    func distance(_ m: Double) -> String {
        if m < 1000 { return t("walkMetres", "{n} m", ["n": "\(max(10, Int((m / 10).rounded()) * 10))"]) }
        let km = (m / 100).rounded() / 10
        let said = km.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: content.lang)))
        return t("walkKm", "{n} km", ["n": said])
    }

    func minutes(_ n: Double) -> String {
        let n = max(1, Int(n.rounded()))
        if n < 60 { return t("walkMin", "{n} min", ["n": "\(n)"]) }
        return t("walkHours", "{h} h {m} min", ["h": "\(n / 60)", "m": "\(n % 60)"])
    }

    func took(_ ms: Double) -> String {
        let days = Int(ms / 86_400_000)
        if days < 1 { return minutes(ms / 60_000) }
        let hours = Int(ms.truncatingRemainder(dividingBy: 86_400_000) / 3_600_000)
        let said = days == 1 ? t("walkDayOne", "1 day") : t("walkDays", "{n} days", ["n": "\(days)"])
        return hours > 0 ? said + " " + t("walkHoursOnly", "{h} h", ["h": "\(hours)"]) : said
    }

    /// "7 November", and with `clock` "7 November, 18:42".
    func day(_ ms: Double, clock: Bool = false) -> String {
        let date = Date(timeIntervalSince1970: ms / 1000)
        let f = DateFormatter()
        f.locale = Locale(identifier: content.lang)
        f.setLocalizedDateFormatFromTemplate(clock ? "dMMMMHHmm" : "dMMMM")
        return f.string(from: date)
    }

    /// The word for how somebody went round, or nil for nobody said.
    func went(_ mode: String) -> String? {
        switch mode {
        case "foot": return t("walkFoot", "On foot")
        case "bike": return t("walkBike", "By bike")
        case "car": return t("walkCar", "By car")
        case "mixed": return t("walkMixed", "Mixed")
        default: return nil
        }
    }
}
