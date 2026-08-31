import CoreLocation
import Foundation

/// Grouping pins that would otherwise land on top of each other.
///
/// The rule is the site's: places whose dots come within a set number of screen
/// points of a seed share that seed's dot, greedily, in list order. Past a
/// close-enough zoom nothing is grouped at all — by then you are looking at one
/// street, and two dots forty points apart are two perfectly tappable dots.
///
/// Screen distance is what matters, not real distance, so the threshold is
/// converted into degrees using the span currently on screen and the width the
/// map is drawn at. Longitude maps straight to x; a degree of latitude covers
/// more x than a degree of longitude does, by 1/cos(latitude), so it is scaled
/// before the two are compared.
enum PinCluster {
    /// The site's CLUSTER_PX: exactly as wide as a pin and its halo, and not a
    /// point wider. A pin is 22 across with a 2.5 rim on each side, so two of
    /// them 32 apart are two separate circles with daylight between them —
    /// nothing to merge. Anything closer and one dot is sitting on the other,
    /// which is the only thing grouping is here to fix.
    ///
    /// It used to be 52, a fingertip's width, on the theory that two pins you
    /// cannot comfortably tap apart may as well be one. That grouped pairs the
    /// eye could plainly see as two, and it fed the size ramp: a longer
    /// distance groups more places, more places make bigger dots. Tapping is
    /// not the problem the dots were solving — overlap is.
    static let spacing: Double = 32

    /// The site's CLUSTER_ZOOM_MAX of 17, in the units MapKit reports. Zoom 14
    /// is about 0.034 degrees across on a phone, and each level halves it.
    static let closestClusteredSpan: Double = 0.034 / 8

    struct Group: Identifiable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let places: [Place]

        var isCluster: Bool { places.count > 1 }
        var place: Place? { places.count == 1 ? places[0] : nil }
    }

    static func groups(for places: [Place], span: Double, width: Double) -> [Group] {
        guard span > closestClusteredSpan, width > 0, places.count > 1 else {
            return places.map {
                Group(id: $0.id, coordinate: $0.coordinate, places: [$0])
            }
        }

        let threshold = spacing * span / width
        // Everything is compared in "longitude-equivalent" degrees.
        let stretch = 1 / max(cos(centreLatitude(of: places) * .pi / 180), 0.1)

        var taken = [Bool](repeating: false, count: places.count)
        var result: [Group] = []

        for i in places.indices where !taken[i] {
            taken[i] = true
            var members = [places[i]]
            for j in places.indices where j > i && !taken[j] {
                if distance(places[i], places[j], stretch: stretch) < threshold {
                    taken[j] = true
                    members.append(places[j])
                }
            }
            // A cluster sits on its seed, as on the site: the dot does not
            // drift to a centroid that is not any of the places in it.
            result.append(Group(
                id: members.count == 1 ? members[0].id : "cluster:\(members[0].id)",
                coordinate: members[0].coordinate,
                places: members
            ))
        }
        return result
    }

    /// The span that pulls a group apart: every member is within `spacing` of
    /// the seed by construction, so tightening the view until the widest pair
    /// exceeds that distance always splits it.
    static func spanThatSplits(_ group: Group, width: Double) -> Double {
        let stretch = 1 / max(cos(group.coordinate.latitude * .pi / 180), 0.1)
        var widest = 0.0
        for place in group.places {
            widest = max(widest, distance(group.places[0], place, stretch: stretch))
        }
        guard widest > 0 else { return closestClusteredSpan }
        // Tighter than the exact split point, so one tap clears it rather than
        // landing on the boundary.
        return max(widest * width / spacing * 0.8, closestClusteredSpan * 0.5)
    }

    private static func distance(_ a: Place, _ b: Place, stretch: Double) -> Double {
        let dx = a.lng - b.lng
        let dy = (a.lat - b.lat) * stretch
        return (dx * dx + dy * dy).squareRoot()
    }

    private static func centreLatitude(of places: [Place]) -> Double {
        guard !places.isEmpty else { return 59.437 }
        return places.reduce(0) { $0 + $1.lat } / Double(places.count)
    }

    // MARK: - How big the dot is, and what it says

    /// Past ten places the dot stops growing with every one of them and steps
    /// instead, and the count stops being a number anybody counts: it says
    /// "10+".
    ///
    /// The widths step by six and stop at 58. They used to run to 94, which is
    /// most of a phone's width in one circle: a cluster of thirty stopped being
    /// a mark on the map and became a hole in it, covering the streets you were
    /// reading to decide whether to zoom in. A dot only has to be big enough to
    /// hold its number and to rank against its neighbours, and 58 does both.
    private static let tiers: [(over: Int, label: Int, diameter: Double)] = [
        (over: 50, label: 50, diameter: 58),
        (over: 30, label: 30, diameter: 52),
        (over: 20, label: 20, diameter: 46),
        (over: 10, label: 10, diameter: 40)
    ]

    /// Two is 32, the width of a pin and its halo — the smallest a cluster can
    /// be and still not be mistaken for the one place it is standing in front
    /// of — and every further place adds half a point of radius, so ten is 40.
    /// The ramp is deliberately shallow: a cluster is a signpost, not a bar
    /// chart. It has to say "more here than there" and stay out of the way of
    /// the map underneath, and a dot that doubles its width by ten places does
    /// neither. The first tier picks up at exactly the width ten left off at,
    /// so 10 and 10+ are the same circle wearing different words.
    static func dotDiameter(_ count: Int) -> Double {
        tier(count)?.diameter ?? 30 + Double(count)
    }

    static func shownCount(_ count: Int) -> String {
        tier(count).map { "\($0.label)+" } ?? String(count)
    }

    private static func tier(_ count: Int) -> (over: Int, label: Int, diameter: Double)? {
        tiers.first { count > $0.over }
    }
}
