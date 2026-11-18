import SwiftUI
import MapKit
import Charts

/// One of your rides, opened from Your rides: where it went, how far, how
/// long and how fast, and — where the ride has the times each point was
/// passed — the speed along the way and each kilometre's time.
/// `GET /api/rides/<id>`, whose numbers the site works out
/// (`functions/api/_rides.js`), so the app draws them and adds nothing.
///
/// The line is the stored one, with the first and last 200 m already off,
/// which the speed card says under its line. Rename and delete are the
/// site's `POST /api/rides` `rename` and `drop`; a deleted ride is gone from
/// the Bike tab under everybody's way too, which the question before it says.
struct RideDetailView: View {
    @Environment(ContentStore.self) private var content
    @Environment(\.dismiss) private var dismiss
    let id: String

    @State private var ride: RideDetail?
    @State private var failed = false
    @State private var gone = false
    @State private var renaming = false
    @State private var newName = ""
    @State private var deleting = false
    @State private var problem: String?

    private static let maxName = 60

    var body: some View {
        Group {
            if let ride {
                page(ride)
            } else if gone {
                EmptyNote(title: content.t("rideUnnamed", "Bike ride"),
                          text: content.t("appRideGone", "This ride is not one of yours, or it was deleted."),
                          systemImage: "bicycle")
            } else if failed {
                VStack(spacing: 10) {
                    Text(content.t("appOffline", "Couldn’t reach tallinntastebuds.ee.")).foregroundStyle(Theme.muted)
                    Button(content.t("appRetry", "Try again")) { Task { await load() } }
                }
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task { if ride == nil { await load() } }
        .alert(content.t("appRideRename", "Rename"), isPresented: $renaming) {
            TextField(content.t("rideName", "Name (optional)"), text: $newName)
            Button(content.t("listsSave", "Save")) { Task { await rename() } }
            Button(content.t("close", "Close"), role: .cancel) {}
        }
        .confirmationDialog(content.t("appRideDeleteSure", "Delete this ride? It goes from the map too, and there is no undo."),
                            isPresented: $deleting, titleVisibility: .visible) {
            Button(content.t("appRideDelete", "Delete this ride"), role: .destructive) { Task { await drop() } }
        }
    }

    private func load() async {
        do {
            ride = try await API.get(RideAnswer.self, "api/rides/\(id)").ride
            failed = false
        } catch API.Failure.notFound {
            gone = true
        } catch {
            failed = true
        }
    }

    private func rename() async {
        let name = String(newName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxName))
        do {
            try await API.post("api/rides", ["action": "rename", "id": id, "name": name])
            ride?.name = name
            problem = nil
        } catch {
            problem = content.t("appOffline", "Couldn’t reach tallinntastebuds.ee.")
        }
    }

    private func drop() async {
        do {
            try await API.post("api/rides", ["action": "drop", "id": id])
            dismiss()
        } catch let refusal as API.Refusal where refusal.code == "not-found" {
            dismiss()
        } catch {
            problem = content.t("appOffline", "Couldn’t reach tallinntastebuds.ee.")
        }
    }

    // MARK: The page

    private func page(_ ride: RideDetail) -> some View {
        let insight = ride.insight
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ride.name.isEmpty ? content.t("rideUnnamed", "Bike ride") : ride.name)
                        .font(.title2.bold()).foregroundStyle(Theme.ink)
                    Text(ride.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                        .font(.subheadline.monospacedDigit()).foregroundStyle(Theme.muted)
                }

                map(ride)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 10) {
                        figure(content.t("rideDistance", "distance"), RideWords.distance(ride.meters, content))
                        figure(content.t("rideTime", "time"), RideWords.time(ride.seconds, content))
                        figure(content.t("rideAverage", "average"), insight.average.map { RideWords.speed($0, content) } ?? "–")
                    }
                    if insight.timed {
                        HStack(alignment: .top, spacing: 10) {
                            figure(content.t("appRideFastestKm", "Fastest km"),
                                   insight.fastest.map { RideWords.clock($0.seconds) } ?? "–",
                                   insight.fastest.map { RideWords.speed($0.kmh, content) })
                            figure(content.t("appRideTop", "Top speed"), insight.top.map { RideWords.speed($0, content) } ?? "–")
                            figure(content.t("appRideStopped", "Stopped"),
                                   insight.stopped.map { $0 < 60 ? "0" : RideWords.time($0, content) } ?? "–")
                        }
                    } else {
                        Text(content.t("appRideUntimed", "This ride was saved before the app kept when each point was passed, so it has no speeds or kilometres."))
                            .font(.footnote).foregroundStyle(Theme.muted)
                    }
                }
                .card()

                if insight.timed, insight.speed.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: content.t("appRideSpeed", "Speed"))
                        speedChart(insight.speed)
                        Text(content.t("appRideEnds", "The first and last 200 m are not kept, so they are not here either."))
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    .card()
                }

                if insight.timed, !insight.splits.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionLabel(text: content.t("appRideSplits", "Each kilometre")).padding(.bottom, 8)
                        splits(insight.splits)
                    }
                    .card()
                }

                if let problem {
                    Text(problem).font(.footnote).foregroundStyle(Theme.accent)
                }

                HStack(spacing: 10) {
                    Button(content.t("appRideRename", "Rename")) {
                        newName = ride.name
                        renaming = true
                    }
                    .buttonStyle(.bordered)
                    Button(content.t("appRideDelete", "Delete this ride"), role: .destructive) { deleting = true }
                        .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
    }

    private func figure(_ label: String, _ value: String, _ under: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.capitalized(with: nil)).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6).lineLimit(1)
            if let under { Text(under).font(.caption2).foregroundStyle(Theme.muted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The line on Apple's map, framed to fit, with a ring where it starts
    /// and a dot where it ends. Not to be panned about: it is a picture of
    /// the ride, and the page scrolls under the thumb.
    private func map(_ ride: RideDetail) -> some View {
        let line = ride.coordinates
        return Map(initialPosition: .rect(Self.frame(line)), interactionModes: [.zoom]) {
            MapPolyline(coordinates: line)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            if let first = line.first {
                Annotation("", coordinate: first) {
                    Circle().fill(.white).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Theme.accent, lineWidth: 3))
                }
            }
            if let last = line.last {
                Annotation("", coordinate: last) {
                    Circle().fill(Theme.accent).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.hairline))
    }

    /// The box round the line, with a margin so its ends are not on the edge.
    /// Your rides frames every ride of a range with it too.
    static func frame(_ line: [CLLocationCoordinate2D]) -> MKMapRect {
        let rect = line.reduce(MKMapRect.null) { box, c in
            box.union(MKMapRect(origin: MKMapPoint(c), size: MKMapSize(width: 1, height: 1)))
        }
        guard !rect.isNull else {
            let middle = MKMapPoint(MapTab.tallinn.center)
            return MKMapRect(x: middle.x - 5000, y: middle.y - 5000, width: 10000, height: 10000)
        }
        let pad = max(rect.width, rect.height) * 0.15 + 200
        return rect.insetBy(dx: -pad, dy: -pad)
    }

    private func speedChart(_ speed: [RideDetail.Speed]) -> some View {
        Chart(speed, id: \.at) { point in
            LineMark(x: .value("km", point.at / 1000), y: .value("km/h", point.kmh))
                .foregroundStyle(Theme.accent)
            if speed.count <= 40 {
                PointMark(x: .value("km", point.at / 1000), y: .value("km/h", point.kmh))
                    .foregroundStyle(Theme.accent)
                    .symbolSize(14)
            }
        }
        .chartYAxisLabel("km/h")
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel {
                    if let km = value.as(Double.self) { Text("\(km.formatted(.number.precision(.fractionLength(0...1)))) km").font(.caption2) }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel {
                    if let kmh = value.as(Double.self) { Text(kmh.formatted(.number.precision(.fractionLength(0)))).font(.caption2) }
                }
            }
        }
        .frame(height: 160)
    }

    /// Each kilometre's time, with a bar for its speed against the ride's
    /// slowest and fastest, so the quick ones stand out without a colour.
    private func splits(_ splits: [RideDetail.Split]) -> some View {
        let speeds = splits.map(\.kmh)
        let low = (speeds.min() ?? 0) * 0.85
        let high = max(speeds.max() ?? 1, low + 1)
        return VStack(spacing: 0) {
            ForEach(splits, id: \.km) { split in
                HStack(spacing: 10) {
                    Text(String(split.km)).font(.subheadline.monospacedDigit()).foregroundStyle(Theme.muted)
                        .frame(width: 26, alignment: .leading)
                    GeometryReader { box in
                        Capsule().fill(Theme.accent.opacity(0.75))
                            .frame(width: max(6, box.size.width * (split.kmh - low) / (high - low)), height: 8)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(height: 20)
                    Text(RideWords.clock(split.seconds)).font(.subheadline.monospacedDigit()).foregroundStyle(Theme.ink)
                        .frame(width: 48, alignment: .trailing)
                    Text(String(format: "%.1f", split.kmh)).font(.subheadline.monospacedDigit()).foregroundStyle(Theme.muted)
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                if split.km != splits.last?.km { Divider().overlay(Theme.hairline) }
            }
        }
    }
}
