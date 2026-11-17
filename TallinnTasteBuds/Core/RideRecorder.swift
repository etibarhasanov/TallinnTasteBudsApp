import Foundation
import CoreLocation
import Observation
import UIKit

/// Recording a bike ride, the website's `assets/ride.js` drawn natively: the
/// Bike tab of Directions carries Record a ride, the phone's position is
/// kept while the app is open and the screen is on, and on Finish the ride
/// can be saved to `/api/rides`, where it becomes a confirmed bike route
/// drawn faintly under everybody's Bike tab.
///
/// The server takes 200 m off each end before it stores anything and never
/// answers whose ride a line is — `functions/api/rides.js`, NOBODY'S NAME IS
/// ON A RIDE. The app keeps the rule the website keeps about the rest: it
/// records only while it is looked at. The screen is kept awake while
/// recording, and leaving the app pauses the ride outright rather than
/// drawing a straight line across what was ridden unseen. The ride waits on
/// the phone until it is saved or thrown away, so a closed app or a failed
/// save comes back to it, paused.
@MainActor
@Observable
final class RideRecorder {
    static let shared = RideRecorder()

    /// A point is kept once the phone has moved this far from the last, and
    /// only from a fix this sure of itself.
    static let step = 12.0
    static let sure = 30.0
    /// Faster than this between two fixes is the phone guessing — 60 km/h.
    static let jump = 60 / 3.6
    /// The shortest ride worth saving: the server's 300 m once its two
    /// 200 m ends are off.
    static let minMetres = 700.0
    static let maxName = 60
    private static let draftKey = "ride"

    enum Stage { case ready, waiting, recording, paused, short, finished, saving, saved }

    /// Whether the card is up in place of the route's bar.
    var shown = false
    private(set) var stage: Stage = .ready
    private(set) var points: [CLLocationCoordinate2D] = []
    /// The ride's summary once saved, for the card that says so.
    private(set) var saved: String?
    /// The site's word for why the save did not go: signed-out, often,
    /// fast, short, or anything else.
    private(set) var problem: String?

    private var before: TimeInterval = 0
    private var since: Date?
    private var lastFix: Date?

    private init() {
        if let draft = UserDefaults.standard.dictionary(forKey: Self.draftKey),
           let raw = draft["points"] as? [[Double]], raw.count > 0 {
            points = raw.compactMap { $0.count == 2 ? CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) : nil }
            before = draft["seconds"] as? Double ?? 0
            stage = .paused
            shown = true
        }
        if LaunchScript.ride { shown = true }
    }

    var recording: Bool { since != nil }

    var seconds: TimeInterval { before + (since.map { Date().timeIntervalSince($0) } ?? 0) }

    var metres: Double {
        zip(points, points.dropFirst()).reduce(0) { $0 + WalkMath.crow($1.0, $1.1) }
    }

    // MARK: Recording

    func start(_ location: LocationProvider) {
        since = Date()
        lastFix = nil
        stage = points.isEmpty ? .waiting : .recording
        problem = nil
        location.precise(true)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    /// One reading from the phone, kept if it is sure, far enough from the
    /// last and not faster than a bike.
    func fix(_ reading: CLLocation) {
        guard since != nil, reading.horizontalAccuracy >= 0, reading.horizontalAccuracy <= Self.sure else { return }
        let at = CLLocationCoordinate2D(latitude: (reading.coordinate.latitude * 1e5).rounded() / 1e5,
                                        longitude: (reading.coordinate.longitude * 1e5).rounded() / 1e5)
        if let last = points.last {
            let d = WalkMath.crow(last, at)
            if d < Self.step { return }
            if let lastFix, d / max(1, reading.timestamp.timeIntervalSince(lastFix)) > Self.jump { return }
        }
        points.append(at)
        lastFix = reading.timestamp
        if stage == .waiting { stage = .recording }
        if points.count % 10 == 0 { keep() }
    }

    private func stop(_ location: LocationProvider) {
        if let since {
            before += Date().timeIntervalSince(since)
            self.since = nil
            location.precise(false)
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func pause(_ location: LocationProvider) {
        guard recording else { return }
        stop(location)
        keep()
        stage = .paused
    }

    func finish(_ location: LocationProvider) {
        stop(location)
        keep()
        problem = nil
        stage = metres < Self.minMetres ? .short : .finished
    }

    func throwAway(_ location: LocationProvider) {
        stop(location)
        points = []
        before = 0
        forget()
        stage = .ready
        shown = false
    }

    /// Put the card away; never while recording.
    func hide() {
        guard !recording else { return }
        shown = false
        if stage == .saved { stage = .ready; saved = nil }
    }

    func save(name: String, summary: String) async {
        stage = .saving
        let body: [String: Any] = [
            "action": "save",
            "name": String(name.prefix(Self.maxName)),
            "seconds": Int(seconds.rounded()),
            "line": points.map { [$0.latitude, $0.longitude] }
        ]
        do {
            try await API.post("api/rides", body)
            saved = summary
            points = []
            before = 0
            forget()
            stage = .saved
        } catch let refusal as API.Refusal {
            problem = refusal.code
            stage = .finished
        } catch {
            problem = "failed"
            stage = .finished
        }
    }

    // MARK: The phone's copy

    private func keep() {
        UserDefaults.standard.set(["points": points.map { [$0.latitude, $0.longitude] }, "seconds": seconds],
                                  forKey: Self.draftKey)
    }

    private func forget() { UserDefaults.standard.removeObject(forKey: Self.draftKey) }
}

/// What `/api/rides?bbox=` answers: the rides whose box meets the one asked
/// about, as lines and nothing else.
struct RidesNear: Decodable {
    let rides: [Ride]

    struct Ride: Decodable {
        let line: [[Double]]
        var coordinates: [CLLocationCoordinate2D] { RouteAnswer.points(line) }
    }

    enum CodingKeys: String, CodingKey { case rides }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rides = (try? c.decodeIfPresent([Ride].self, forKey: .rides)) ?? []
    }

    /// Within this many metres of a ride, a stretch of a way counts as ridden.
    static let along = 20.0

    /// How many metres of `way` run within `along` of any of the rides — the
    /// website's along(), on flat metres around the way's own latitude.
    static func ridden(_ way: [CLLocationCoordinate2D], by rides: [[CLLocationCoordinate2D]]) -> Double {
        guard let first = way.first else { return 0 }
        let rad = Double.pi / 180
        let kx = cos(first.latitude * rad) * rad * 6_371_000
        let ky = rad * 6_371_000
        func flat(_ p: CLLocationCoordinate2D) -> (Double, Double) { (p.longitude * kx, p.latitude * ky) }
        var segs: [((Double, Double), (Double, Double))] = []
        for ride in rides { for (a, b) in zip(ride, ride.dropFirst()) { segs.append((flat(a), flat(b))) } }
        func near(_ p: (Double, Double)) -> Bool {
            for (a, b) in segs {
                let dx = b.0 - a.0, dy = b.1 - a.1
                let len = dx * dx + dy * dy
                let k = len > 0 ? max(0, min(1, ((p.0 - a.0) * dx + (p.1 - a.1) * dy) / len)) : 0
                let x = a.0 + k * dx - p.0, y = a.1 + k * dy - p.1
                if x * x + y * y <= along * along { return true }
            }
            return false
        }
        var total = 0.0
        for (pa, pb) in zip(way, way.dropFirst()) {
            let a = flat(pa), b = flat(pb)
            let len = ((b.0 - a.0) * (b.0 - a.0) + (b.1 - a.1) * (b.1 - a.1)).squareRoot()
            let steps = max(1, Int((len / 5).rounded(.up)))
            for j in 0..<steps {
                let k = (Double(j) + 0.5) / Double(steps)
                if near((a.0 + k * (b.0 - a.0), a.1 + k * (b.1 - a.1))) { total += len / Double(steps) }
            }
        }
        return total
    }
}
