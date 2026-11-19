import SwiftUI
import MapKit

/// The round button at the bottom right of a map that shows where you are,
/// the way the website's locate button does.
///
/// One press centres the map on the blue dot and follows it. A second press,
/// while it follows, turns the map with the phone, so the dot's beam points
/// the way you are facing — the "which way am I going" a person standing on a
/// street corner is asking. A third lets go. Where the app has not been
/// allowed to know the location yet, the press is what asks.
///
/// It is drawn by hand rather than with MapKit's own button because MapKit
/// puts its controls in the top corner, where the search field covers them.
struct LocateButton: View {
    @Environment(ContentStore.self) private var content
    @Environment(LocationProvider.self) private var location
    @Binding var camera: MapCameraPosition

    var body: some View {
        Button {
            press()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(camera.followsUserLocation ? Theme.here : Theme.ink)
                .frame(width: 48, height: 48)
                .background(Theme.paper, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
        .accessibilityLabel(content.t("locate", "Show my location"))
    }

    private var icon: String {
        if camera.followsUserHeading { return "location.north.line.fill" }
        if camera.followsUserLocation { return "location.fill" }
        return "location"
    }

    private func press() {
        location.start()
        withAnimation(.easeInOut) {
            if camera.followsUserHeading {
                camera = .userLocation(fallback: .automatic)
            } else if camera.followsUserLocation {
                camera = .userLocation(followsHeading: true, fallback: .automatic)
            } else {
                camera = .userLocation(fallback: camera)
            }
        }
    }
}

/// Where a route goes: a place's name and its point.
struct RouteTarget: Identifiable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }

    init(id: String, name: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }
}

/// The way from here to a place, on our own map: on foot, by bike, by bus or
/// tram, or by car — the website's directions, drawn natively.
///
/// The route is the website's `/api/route`: walking, cycling and driving from
/// the OpenStreetMap routing service, the bus from peatus.ee, the national
/// journey planner, with every operator's timetable in Tallinn. Each way wears
/// its own colour, green to red by how green it is to travel that way — the
/// website's `--way-foot` to `--way-car` — on the line and on the tab that is
/// pressed, so the tab says what the line's colour means. A bus journey is
/// drawn with its walks dotted in a walk's green and its rides solid in amber,
/// and the bar says which line, when, and from which stop, with the other
/// departures under it to press. The mode pressed last is remembered, because
/// somebody who takes the bus takes it to the next place too.
///
/// A walk, a ride or a drive comes with up to three ways where the router
/// finds more than one — the first at the top level of the answer, the rest
/// under `others` — and the bar offers them as small buttons, "9 min ·
/// 2.1 km", as the website's bar does. The way chosen is solid and its
/// button wears the mode's colour; the others are faint lines in the same
/// colour, and pressing another makes it the solid one without moving the
/// map, since the frame holds all of them. The buttons say how long and how
/// far, never which is nicer: the router does not say.
///
/// By bike a way can also be a train: ride to a station, an Elron train with
/// the bike on it, ride on — `trains` in the website's `/api/v1/route`,
/// offered only where it is quicker counted from setting off. It is one more
/// button after the bike ways, "15 min · train 09:31", pressed in the bus's
/// amber; the rides are drawn in the bike's green and the rail in amber, and
/// the bar says when to leave and which train. `/api/v1/route` is asked
/// first and `/api/route` where it does not answer, which costs the trains
/// and nothing else, so this build reads a website from before them.
///
/// The way follows the dot: once the phone is sixty metres from where a walk,
/// a ride or a drive was asked from, it is asked for again, at most every
/// twenty seconds, and the line that is up stays until the new one arrives.
/// A bus journey is a timetable and is not asked again. Apple Maps stays a
/// small link at the foot, for turn-by-turn.
///
/// Directions draws the way and nothing else. The Bike tab carried Record a
/// ride and, under a bike way, every ride people had recorded near it, until
/// 2026-11-19: recording is Rattatee's, and somebody else's rides beside a
/// suggested way read as a map painted green and gave away where they ride
/// from — the website took them off its own map on 2026-11-18 for the same
/// reason (**Recorded rides** in its `docs/handbook.md`).
struct RouteView: View {
    @Environment(ContentStore.self) private var content
    @Environment(LocationProvider.self) private var location
    @Environment(\.dismiss) private var dismiss

    let target: RouteTarget

    enum Mode: String, CaseIterable {
        case foot, bike, bus, car

        /// The website's `--way-*` tokens, the night styles' brighter set on
        /// the two dark styles.
        var color: Color {
            switch (self, Theme.dark) {
            case (.foot, false): return Color(hex: 0x1a8f4c)
            case (.foot, true): return Color(hex: 0x4fd18a)
            case (.bike, false): return Color(hex: 0x7ab317)
            case (.bike, true): return Color(hex: 0xb5e04a)
            case (.bus, false): return Color(hex: 0xe08a1e)
            case (.bus, true): return Color(hex: 0xf2a640)
            case (.car, false): return Color(hex: 0xd23b3b)
            case (.car, true): return Color(hex: 0xff6b6b)
            }
        }
    }

    /// How far the dot moves, and how long it rests, before the way is asked
    /// for again — the website's ROUTE_MOVED and ROUTE_REST.
    private static let moved: CLLocationDistance = 60
    private static let rest: TimeInterval = 20

    @AppStorage("routeMode") private var modeName = Mode.foot.rawValue
    @State private var camera: MapCameraPosition = .automatic
    @State private var answer: RouteAnswer?
    @State private var trip = 0
    /// Which of the ways on offer is chosen: 0 the router's first.
    @State private var way = 0
    @State private var say = ""
    @State private var finding = false
    /// Where the way up now was asked from, and when.
    @State private var askedFrom: CLLocation?
    @State private var askedAt = Date.distantPast

    private var mode: Mode { Mode(rawValue: modeName) ?? .foot }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $camera) {
                UserAnnotation()
                Annotation(target.name, coordinate: target.coordinate, anchor: .bottom) {
                    PlacePin(selected: true)
                }
                ForEach(Array(stretches.enumerated()), id: \.offset) { _, stretch in
                    MapPolyline(coordinates: stretch.points)
                        .stroke(stretch.color, style: StrokeStyle(
                            lineWidth: stretch.walk || stretch.thin ? 4 : 6, lineCap: .round, lineJoin: .round,
                            dash: stretch.walk ? [1, 9] : []))
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            // The blue dot is the app's tint; left to the accent it drew you
            // in brick red, the colour of a pin, beside a blue route.
            .tint(Theme.here)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .trailing, spacing: 12) {
                    LocateButton(camera: $camera).padding(.trailing, 14)
                    bar
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").font(.headline)
                    .frame(width: 44, height: 44)
                    .background(Theme.paper, in: Circle())
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                    .foregroundStyle(Theme.ink)
            }
            .padding(.leading, 16).padding(.top, 8)
            .accessibilityLabel(content.t("close", "Close"))
        }
        .task(id: modeName) { await find() }
        // The sentence is written when the answer lands; a language that
        // arrives after it — a first launch in Russian — writes it again.
        .onChange(of: content.ui) { _, _ in if answer != nil { describe() } }
        .onChange(of: location.location) { _, now in
            guard mode != .bus, !finding, let now, let from = askedFrom,
                  now.distance(from: from) >= Self.moved,
                  Date().timeIntervalSince(askedAt) >= Self.rest else { return }
            Task { await find(again: true) }
        }
    }

    // MARK: The bar

    private var bar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(target.name).font(.headline).foregroundStyle(Theme.ink).lineLimit(1)
            // Four tabs fit a phone in English and not in Russian or Turkish,
            // so the row slides sideways rather than squeezing a word.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    tab(.foot, content.t("routeModeWalk", "Walk"))
                    tab(.bike, content.t("routeModeBike", "Bike"))
                    tab(.bus, content.t("routeModeBus", "Bus"))
                    tab(.car, content.t("routeModeCar", "Car"))
                }
            }
            .accessibilityLabel(content.t("routeModes", "How to get there"))

            HStack(spacing: 8) {
                if finding { ProgressView() }
                Text(say).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if mode != .bus, let ways = answer?.ways, ways.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(ways.enumerated()), id: \.offset) { i, other in
                            Button {
                                way = i
                                describe()
                            } label: {
                                Text(chip(other))
                                .font(.footnote.weight(.semibold))
                                .monospacedDigit()
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(i == way ? (other.train == nil ? mode.color : Mode.bus.color) : Theme.wash, in: Capsule())
                                .foregroundStyle(i == way ? Theme.paper : Theme.ink)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(i == way ? .isSelected : [])
                        }
                    }
                }
                .accessibilityLabel(content.t("routeWays", "Ways there"))
            }

            if mode == .bus, let trips = answer?.trips, trips.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(trips.enumerated()), id: \.offset) { i, other in
                            Button {
                                trip = i
                                describe()
                                fit()
                            } label: {
                                Text("\(other.rides.first?.at ?? "") · \(other.lines)")
                                    .font(.footnote.weight(.semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(i == trip ? Theme.accent : Theme.wash, in: Capsule())
                                    .foregroundStyle(i == trip ? Theme.onAccent : Theme.ink)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Button(content.t("appOpenAppleMaps", "Open in Apple Maps")) { openInMaps() }
                .font(.footnote)
        }
        .padding(16)
        .background(Theme.paper)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))
        .shadow(color: .black.opacity(0.12), radius: 10, y: -2)
    }

    /// A way's button: how long and how far, or for a train how long and
    /// when it goes, which is what a way by train hangs on.
    private func chip(_ other: RouteAnswer.Way) -> String {
        let min = "\(max(1, Int((other.seconds / 60).rounded())))"
        if let rail = other.train?.rail {
            return content.t("routeTrainWay", "{min} min · train {at}", ["min": min, "at": rail.at ?? ""])
        }
        return content.t("routeWay", "{min} min · {dist}", ["min": min, "dist": distanceText(other.meters)])
    }

    private func tab(_ which: Mode, _ label: String) -> some View {
        let on = mode == which
        return Button { modeName = which.rawValue } label: {
            Text(label)
                .font(.subheadline.weight(on ? .semibold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(on ? which.color : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(on ? which.color : Theme.hairline))
                .foregroundStyle(on ? Theme.paper : Theme.ink)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: What is drawn

    private struct Stretch {
        let points: [CLLocationCoordinate2D]
        let color: Color
        let walk: Bool
        /// A way on offer and not chosen.
        var thin = false
    }

    private var stretches: [Stretch] {
        guard let answer else { return [] }
        if mode == .bus {
            guard let trips = answer.trips, trips.indices.contains(trip) else { return [] }
            return trips[trip].legs.compactMap { leg in
                let points = leg.coordinates
                guard points.count > 1 else { return nil }
                let walk = leg.name == nil
                return Stretch(points: points, color: walk ? Mode.foot.color : Mode.bus.color, walk: walk)
            }
        }
        // The ways not chosen first and faint, so the chosen one is drawn
        // over them.
        let ways = answer.ways
        guard ways.indices.contains(way) else { return [] }
        let faint = ways.enumerated().filter { $0.offset != way }.flatMap { drawn($0.element, faint: true) }
        return faint + drawn(ways[way], faint: false)
    }

    /// One way as its stretches: the line in the mode's colour, or a way by
    /// train leg by leg, the rides in the bike's green and the rail amber.
    private func drawn(_ way: RouteAnswer.Way, faint: Bool) -> [Stretch] {
        let legs: [([CLLocationCoordinate2D], Color)] = way.train?.legs.map { ($0.coordinates, $0.kind == "train" ? Mode.bus.color : Mode.bike.color) }
            ?? [(way.coordinates, mode.color)]
        return legs.filter { $0.0.count > 1 }.map {
            Stretch(points: $0.0, color: faint ? $0.1.opacity(0.38) : $0.1, walk: false, thin: faint)
        }
    }

    // MARK: Asking

    /// Ask for the way. Asked again because the dot moved, the line and the
    /// sentence that are up stay until the new answer replaces them, the map
    /// is not refitted under a thumb, and no answer leaves the old way up.
    private func find(again: Bool = false) async {
        if !again {
            answer = nil
            trip = 0
            way = 0
            say = content.t("routeFinding", "Finding the way…")
        }
        finding = true
        defer { finding = false }

        location.start()
        // A first fix can take a moment after the permission is given.
        for _ in 0..<16 where location.location == nil {
            try? await Task.sleep(for: .milliseconds(250))
        }
        guard let here = location.location else {
            if again { return }
            say = content.t("routeLocate", "Share your location to see the way.")
            camera = .region(MKCoordinateRegion(center: target.coordinate, latitudinalMeters: 1200, longitudinalMeters: 1200))
            return
        }
        let query = [
            "mode": mode.rawValue,
            "from": String(format: "%.5f,%.5f", here.coordinate.latitude, here.coordinate.longitude),
            "to": String(format: "%.5f,%.5f", target.latitude, target.longitude)
        ]
        askedFrom = here
        askedAt = Date()
        let asked = mode
        do {
            let got = try await route(query)
            // A quiet ask the dot started is not cancelled by a tab pressed
            // while it was out, so its answer is checked against the tab.
            if Task.isCancelled || mode != asked { return }
            answer = got
            // An answer after the dot moved comes back on the first way:
            // the ways from the new place are not the ones a button was
            // pressed among.
            way = 0
            describe()
            if !again { fit() }
        } catch {
            if Task.isCancelled || again || mode != asked { return }
            say = noRoute
        }
    }

    /// The versioned route first, for the trains, then the one every build
    /// has always read. A refusal from the first is asked again of the
    /// second, which answers it in the same word.
    private func route(_ query: [String: String]) async throws -> RouteAnswer {
        if let got = try? await API.get(RouteAnswer.self, "api/v1/route", query), got.version != nil { return got }
        return try await API.get(RouteAnswer.self, "api/route", query)
    }

    private var noRoute: String {
        switch mode {
        case .foot: return content.t("routeNone", "Couldn't find a walking route.")
        case .bike: return content.t("routeNoBike", "Couldn't find a bike route.")
        case .bus: return content.t("routeNoBus", "No bus or tram found right now.")
        case .car: return content.t("routeNoCar", "Couldn't find a driving route.")
        }
    }

    /// The sentence in the bar, in the website's words.
    private func describe() {
        guard let answer else { return }
        if mode == .bus {
            guard let trips = answer.trips, trips.indices.contains(trip), let first = trips[trip].rides.first else {
                say = noRoute
                return
            }
            say = content.t("routeBus", "{lines} at {time} from {stop} · {min} min in all", [
                "lines": trips[trip].lines,
                "time": first.at ?? "",
                "stop": first.from ?? "",
                "min": "\(max(1, Int((trips[trip].seconds / 60).rounded())))"
            ])
            return
        }
        let ways = answer.ways
        guard ways.indices.contains(way) else {
            say = noRoute
            return
        }
        let seconds = ways[way].seconds
        if let train = ways[way].train, let rail = train.rail {
            say = content.t("routeTrain", "Leave at {leave}: ride to {from}, the {line} at {at} to {to}, ride on · {min} min", [
                "leave": train.leave, "from": rail.from ?? "", "line": rail.name ?? "", "at": rail.at ?? "",
                "to": rail.to ?? "", "min": "\(max(1, Int((seconds / 60).rounded())))"
            ])
            return
        }
        let distance = distanceText(ways[way].meters)
        let (key, english): (String, String)
        switch mode {
        case .bike: (key, english) = ("routeBike", "{min} min by bike · {dist}")
        case .car: (key, english) = ("routeCar", "{min} min by car · {dist}")
        default: (key, english) = ("routeWalk", "{min} min on foot · {dist}")
        }
        say = content.t(key, english, ["min": "\(max(1, Int((seconds / 60).rounded())))", "dist": distance])
    }

    private func distanceText(_ meters: Double) -> String {
        meters < 1000
            ? content.t("askMetres", "{n} m", ["n": "\(max(10, Int((meters / 10).rounded()) * 10))"])
            : content.t("askKm", "{n} km", ["n": String(format: "%.1f", meters / 1000)])
    }

    /// Frame the whole way, with the bar's height of room at the bottom.
    private func fit() {
        var points = stretches.flatMap(\.points)
        points.append(target.coordinate)
        if let here = location.location?.coordinate { points.append(here) }
        let rect = points.reduce(MKMapRect.null) { rect, point in
            rect.union(MKMapRect(origin: MKMapPoint(point), size: MKMapSize(width: 1, height: 1)))
        }
        let padX = rect.size.width * 0.2 + 400
        let padY = rect.size.height * 0.2 + 400
        let padded = MKMapRect(x: rect.origin.x - padX, y: rect.origin.y - padY,
                               width: rect.size.width + padX * 2, height: rect.size.height + padY * 3)
        withAnimation(.easeInOut) { camera = .rect(padded) }
    }

    private func openInMaps() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: target.coordinate))
        item.name = target.name
        let launch: String
        switch mode {
        // Apple Maps has a cycling mode only from iOS 18's SDK on; walking
        // is the nearer of what every phone has.
        case .foot, .bike: launch = MKLaunchOptionsDirectionsModeWalking
        case .bus: launch = MKLaunchOptionsDirectionsModeTransit
        case .car: launch = MKLaunchOptionsDirectionsModeDriving
        }
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: launch])
    }
}

/// What `/api/route` answers: a walk, a ride or a drive as one line with its
/// length and time and up to two more ways under `others`, or a bus journey
/// as up to three trips of legs.
struct RouteAnswer: Decodable {
    let meters: Double?
    let seconds: Double?
    let line: [[Double]]?
    /// Absent on an answer from before the website offered more than one.
    let others: [Way]?
    let trips: [Trip]?
    /// 1 on an answer from /api/v1/route, absent on one from /api/route.
    let version: Int?
    /// By bike, from /api/v1/route only: the ways by train.
    let trains: [Train]?

    var coordinates: [CLLocationCoordinate2D] { RouteAnswer.points(line ?? []) }

    /// The first way, then the others: every way on offer that has a line.
    var ways: [Way] {
        var all: [Way] = []
        if let meters, let seconds, let line { all.append(Way(meters: meters, seconds: seconds, line: line)) }
        all += others ?? []
        all += (trains ?? []).map { Way(meters: $0.meters, seconds: $0.seconds, line: $0.legs.flatMap(\.line), train: $0) }
        return all.filter { $0.coordinates.count > 1 }
    }

    struct Way: Decodable {
        let meters: Double
        let seconds: Double
        let line: [[Double]]
        /// Set where the way is a train, never decoded: a way of `others`
        /// has no such field.
        var train: Train? = nil

        var coordinates: [CLLocationCoordinate2D] { RouteAnswer.points(line) }

        private enum CodingKeys: String, CodingKey { case meters, seconds, line }
    }

    /// A way by train: when to set off, and its legs — a ride (`bike`) or
    /// the train, which carries its name, its two stations and its time.
    struct Train: Decodable {
        let seconds: Double
        let meters: Double
        let leave: String
        let legs: [TrainLeg]

        var rail: TrainLeg? { legs.first { $0.kind == "train" } }
    }

    struct TrainLeg: Decodable {
        let kind: String
        let line: [[Double]]
        let name: String?
        let from: String?
        let to: String?
        let at: String?

        var coordinates: [CLLocationCoordinate2D] { RouteAnswer.points(line) }
    }

    struct Trip: Decodable {
        let seconds: Double
        let legs: [Leg]

        /// The legs that are rides; a walk carries no line name.
        var rides: [Leg] { legs.filter { $0.name != nil } }
        /// "T4 → 17", the lines in the order they are taken.
        var lines: String { rides.map { $0.name ?? "?" }.joined(separator: " → ") }
    }

    struct Leg: Decodable {
        let line: [[Double]]
        let name: String?
        let from: String?
        let at: String?

        var coordinates: [CLLocationCoordinate2D] { RouteAnswer.points(line) }
    }

    static func points(_ pairs: [[Double]]) -> [CLLocationCoordinate2D] {
        pairs.compactMap { $0.count >= 2 ? CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) : nil }
    }
}
