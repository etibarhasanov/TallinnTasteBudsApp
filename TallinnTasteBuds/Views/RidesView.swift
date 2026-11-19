import SwiftUI
import Charts
import MapKit

/// Your rides: every bike ride you saved under your account, with how far,
/// how long and how often over a range, and each ride a row that opens it —
/// `GET /api/rides`. The website lists the same rides on its account page;
/// opening one is the app's.
///
/// The figures are worked out here from the list rather than asked for, since
/// the list is every ride the site keeps for you (up to `MINE`, two hundred)
/// and a range is three sums over it. Each is set against the same length of
/// time just before, in the words the website's Insights uses.
///
/// Where you rode is the one part asked for separately: the same list with
/// `lines=1`, each ride's way thinned by the site, drawn together on one map
/// so the streets ridden show. It is a second request because the lines are
/// the heavy half, and the figures and the rows should not wait on them or
/// go when they fail.
struct RidesView: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account

    @State private var rides: [MyRide]?
    @State private var failed = false
    /// Each ride's thinned line by its id, once `lines=1` has answered.
    @State private var lines: [String: [CLLocationCoordinate2D]]?
    @State private var linesFailed = false
    /// Days back, or 0 for all of it — the website's Insights ranges.
    @State private var span = 28

    private static let spans = [7, 28, 90, 0]

    var body: some View {
        Group {
            if !account.signedIn {
                EmptyNote(title: content.t("ridesYours", "Your rides"),
                          text: content.t("appRidesSignIn", "Your rides are the ones saved under your account, so they need one."),
                          systemImage: "bicycle")
            } else if let rides {
                if rides.isEmpty {
                    EmptyNote(title: content.t("ridesYours", "Your rides"),
                              text: content.t("appRidesNoneSite", "No rides yet. Record one on tallinntastebuds.ee, and it is here once it is saved."),
                              systemImage: "bicycle")
                } else {
                    page(rides)
                }
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
        .navigationTitle(content.t("ridesYours", "Your rides"))
        .navigationBarTitleDisplayMode(.inline)
        // Again each time it is shown, so a ride renamed or deleted on its
        // own page is right here on the way back: a `.task` starts again on
        // every appearance, so it is the one call. An `.onAppear` beside it
        // used to load a second time on every way back — four requests where
        // two do, each the site's rows read.
        .task(id: account.user) { await load() }
    }

    private func load() async {
        guard account.signedIn else { return }
        do {
            rides = try await API.get(MyRides.self, "api/rides").rides
            failed = false
        } catch {
            if rides == nil { failed = true }
        }
        await loadLines()
    }

    /// The lines Where you rode draws. Kept through a failed reload, so a
    /// map already drawn is not swapped for a sentence on the way back.
    private func loadLines() async {
        guard account.signedIn else { return }
        do {
            let withLines = try await API.get(MyRides.self, "api/rides", ["mine": "1", "lines": "1"]).rides
            lines = Dictionary(withLines.map { ($0.id, $0.coordinates) }, uniquingKeysWith: { first, _ in first })
            linesFailed = false
        } catch {
            if lines == nil { linesFailed = true }
        }
    }

    // MARK: The page

    private func page(_ rides: [MyRide]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(content.t("ridesWhat", "The bike rides you recorded. Each one is a confirmed bike route on the map, without your name on it."))
                        .font(.subheadline).foregroundStyle(Theme.muted)
                    chips.padding(.top, 10)
                    figures(rides).padding(.top, 8)
                    chart(rides).padding(.top, 6)
                }
                .card()

                whereYouRode(rides)

                SectionLabel(text: content.t("appRidesAll", "All rides")).padding(.top, 4)
                ForEach(rides) { ride in
                    NavigationLink(value: Route.ride(ride.id)) { row(ride) }
                        .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    private var chips: some View {
        HStack(spacing: 6) {
            ForEach(Self.spans, id: \.self) { days in
                let on = days == span
                Button { span = days } label: {
                    Text(days == 0 ? content.t("insightsAll", "All time") : content.t("insightsDays", "{n} days", ["n": String(days)]))
                        .font(.subheadline)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(on ? Theme.accent : Theme.paper, in: Capsule())
                        .overlay(Capsule().stroke(on ? Color.clear : Theme.hairline))
                        .foregroundStyle(on ? Theme.onAccent : Theme.ink)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(content.t("insightsRange", "Range"))
    }

    private func row(_ ride: MyRide) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ride.name.isEmpty ? content.t("rideUnnamed", "Bike ride") : ride.name)
                    .font(.headline).foregroundStyle(Theme.ink)
                Text([RideWords.distance(ride.meters, content), RideWords.time(ride.seconds, content),
                      RideWords.day(ride.date, content)].joined(separator: " · "))
                    .font(.subheadline.monospacedDigit()).foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
        }
        .card()
    }

    // MARK: Where you rode

    /// Every ride of the range on one map, each a see-through line, so a
    /// street ridden more than once comes out darker. It follows the chips.
    private func whereYouRode(_ rides: [MyRide]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content.t("appRidesWhere", "Where you rode")).font(.headline).foregroundStyle(Theme.ink)
            if let lines {
                let ridden = within(rides).compactMap { lines[$0.id] }.filter { $0.count > 1 }
                if ridden.isEmpty {
                    note(span > 0
                         ? content.t("appRidesWhereNone", "No rides in these {n} days.", ["n": String(span)])
                         : content.t("appRidesWhereNothing", "Nothing to draw yet."))
                } else {
                    coverage(ridden)
                    Text(content.t("appRidesWhereDarker", "A street you rode more than once is drawn darker."))
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            } else if linesFailed {
                VStack(spacing: 8) {
                    Text(content.t("appOffline", "Couldn’t reach tallinntastebuds.ee."))
                        .font(.subheadline).foregroundStyle(Theme.muted)
                    Button(content.t("appRetry", "Try again")) { Task { await loadLines() } }
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .card()
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.subheadline).foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 120)
    }

    /// The lines on Apple's map, framed to fit them all. Zoomed and not
    /// panned, as one ride's map is, so the page scrolls under the thumb;
    /// made again for each range, since the frame is set once.
    private func coverage(_ ridden: [[CLLocationCoordinate2D]]) -> some View {
        Map(initialPosition: .rect(RideDetailView.frame(ridden.flatMap { $0 })), interactionModes: [.zoom]) {
            ForEach(Array(ridden.enumerated()), id: \.offset) { _, line in
                MapPolyline(coordinates: line)
                    .stroke(Theme.accent.opacity(0.45), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.hairline))
        .id("\(span)-\(ridden.count)")
        .accessibilityLabel(content.t("appRidesWhere", "Where you rode"))
    }

    // MARK: The figures

    /// The rides inside a range ending now, or `back` ranges before it.
    private func within(_ rides: [MyRide], back: Int = 0) -> [MyRide] {
        guard span > 0 else { return back == 0 ? rides : [] }
        let now = Date()
        let length = TimeInterval(span) * 86_400
        let end = now.addingTimeInterval(-length * Double(back))
        let start = end.addingTimeInterval(-length)
        return rides.filter { $0.date > start && $0.date <= end }
    }

    private func figures(_ rides: [MyRide]) -> some View {
        let now = within(rides)
        let was = within(rides, back: 1)
        let meters = now.reduce(0) { $0 + $1.meters }
        let seconds = now.reduce(0) { $0 + $1.seconds }
        let wasMeters = was.reduce(0) { $0 + $1.meters }
        let wasSeconds = was.reduce(0) { $0 + $1.seconds }
        return HStack(alignment: .top, spacing: 10) {
            figure(content.t("rideDistance", "distance"), RideWords.distance(meters, content),
                   against(meters, wasMeters) { RideWords.distance($0, content) })
            figure(content.t("rideTime", "time"), seconds > 0 ? RideWords.time(seconds, content) : "0",
                   against(seconds, wasSeconds) { RideWords.time($0, content) })
            figure(content.t("appRidesRides", "Rides"), String(now.count),
                   against(Double(now.count), Double(was.count)) { String(Int($0)) })
        }
    }

    /// The change on the range before, as the website's Insights says it, or
    /// nothing for all time, which has no range before it.
    private func against(_ now: Double, _ was: Double, _ say: (Double) -> String) -> String? {
        guard span > 0 else { return nil }
        let diff = now - was
        let days = String(span)
        if abs(diff) < 0.5 { return content.t("insightsSame", "Same as the {days} days before", ["days": days]) }
        return diff > 0
            ? content.t("insightsMore", "+{n} on the {days} days before", ["n": say(diff), "days": days])
            : content.t("insightsFewer", "−{n} on the {days} days before", ["n": say(-diff), "days": days])
    }

    private func figure(_ label: String, _ value: String, _ under: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.capitalized(with: nil)).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.7).lineLimit(1)
            if let under {
                Text(under).font(.caption2).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: The line

    /// Kilometres a day over 7 and 28 days, a week over 90, and a month over
    /// all of it from the month of the first ride — the website's Insights'
    /// steps, so ninety points are not a smear on a phone.
    private struct Bucket: Identifiable {
        let start: Date
        let km: Double
        var id: Date { start }
    }

    private func buckets(_ rides: [MyRide]) -> [Bucket] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let unit: Calendar.Component
        let first: Date
        switch span {
        case 7, 28:
            unit = .day
            first = calendar.date(byAdding: .day, value: 1 - span, to: today)!
        case 90:
            unit = .weekOfYear
            first = calendar.dateInterval(of: .weekOfYear, for: calendar.date(byAdding: .day, value: -89, to: today)!)!.start
        default:
            unit = .month
            let oldest = rides.map(\.date).min() ?? today
            first = calendar.dateInterval(of: .month, for: oldest)!.start
        }
        var out: [Bucket] = []
        var start = first
        while start <= today {
            let end = calendar.date(byAdding: unit, value: 1, to: start)!
            let km = rides.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.meters } / 1000
            out.append(Bucket(start: start, km: km))
            start = end
        }
        return out
    }

    private func chart(_ rides: [MyRide]) -> some View {
        let points = buckets(rides)
        return Chart(points) { point in
            LineMark(x: .value("Day", point.start), y: .value("km", point.km))
                .foregroundStyle(Theme.accent)
                .interpolationMethod(.linear)
            if points.count <= 31 {
                PointMark(x: .value("Day", point.start), y: .value("km", point.km))
                    .foregroundStyle(Theme.accent)
                    .symbolSize(18)
            }
        }
        .chartYAxisLabel("km")
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel {
                    if let date = value.as(Date.self) { Text(RideWords.day(date, content)).font(.caption2) }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel {
                    if let km = value.as(Double.self) { Text(km.formatted(.number.precision(.fractionLength(0)))).font(.caption2) }
                }
            }
        }
        .frame(height: 150)
    }
}
