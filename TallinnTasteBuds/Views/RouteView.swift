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
/// The way follows the dot: once the phone is sixty metres from where a walk,
/// a ride or a drive was asked from, it is asked for again, at most every
/// twenty seconds, and the line that is up stays until the new one arrives.
/// A bus journey is a timetable and is not asked again. Apple Maps stays a
/// small link at the foot, for turn-by-turn.
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
                            lineWidth: stretch.walk ? 4 : 6, lineCap: .round, lineJoin: .round,
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
            Button { dismiss() } label: {
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
        let points = answer.coordinates
        return points.count > 1 ? [Stretch(points: points, color: mode.color, walk: false)] : []
    }

    // MARK: Asking

    /// Ask for the way. Asked again because the dot moved, the line and the
    /// sentence that are up stay until the new answer replaces them, the map
    /// is not refitted under a thumb, and no answer leaves the old way up.
    private func find(again: Bool = false) async {
        if !again {
            answer = nil
            trip = 0
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
            let got = try await API.get(RouteAnswer.self, "api/route", query)
            // A quiet ask the dot started is not cancelled by a tab pressed
            // while it was out, so its answer is checked against the tab.
            if Task.isCancelled || mode != asked { return }
            answer = got
            describe()
            if !again { fit() }
        } catch {
            if Task.isCancelled || again || mode != asked { return }
            say = noRoute
        }
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
        guard let meters = answer.meters, let seconds = answer.seconds, answer.coordinates.count > 1 else {
            say = noRoute
            return
        }
        let distance = meters < 1000
            ? content.t("askMetres", "{n} m", ["n": "\(max(10, Int((meters / 10).rounded()) * 10))"])
            : content.t("askKm", "{n} km", ["n": String(format: "%.1f", meters / 1000)])
        let (key, english): (String, String)
        switch mode {
        case .bike: (key, english) = ("routeBike", "{min} min by bike · {dist}")
        case .car: (key, english) = ("routeCar", "{min} min by car · {dist}")
        default: (key, english) = ("routeWalk", "{min} min on foot · {dist}")
        }
        say = content.t(key, english, ["min": "\(max(1, Int((seconds / 60).rounded())))", "dist": distance])
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

/// What `/api/route` answers: a walk or a drive as one line with its length
/// and time, or a bus journey as up to three trips of legs.
struct RouteAnswer: Decodable {
    let meters: Double?
    let seconds: Double?
    let line: [[Double]]?
    let trips: [Trip]?

    var coordinates: [CLLocationCoordinate2D] { RouteAnswer.points(line ?? []) }

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
