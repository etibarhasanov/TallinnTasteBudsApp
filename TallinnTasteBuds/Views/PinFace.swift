import SwiftUI

/// A pin: the painting, in a collar that says how much of the place there is.
///
/// The site's reasoning, kept: the mark cannot change — that is the whole point
/// of putting it on every pin — so the collar carries what the fill of a plain
/// dot used to. Filmed is a solid collar; photographed is a paper gap and then
/// a ring, which is a different silhouette rather than a paler version of the
/// same one; the write-up alone is smaller and quieter. Told apart at a glance
/// at the size the map actually draws them.
struct PinFace: View {
    let place: Place
    var selected = false

    @Environment(MarkImage.self) private var mark
    @Environment(\.theme) private var theme

    /// The site's diameters, to the pixel.
    static let diameter: CGFloat = 22
    static let diameterWords: CGFloat = 17
    static let diameterSelected: CGFloat = 34

    private var size: CGFloat {
        if selected { return Self.diameterSelected }
        return place.depth == .words ? Self.diameterWords : Self.diameter
    }

    /// Shut for good drains the paint out of the mark and greys the collar.
    private var tone: Color {
        place.closed ? theme.muted : (selected ? theme.accentLit : theme.accent)
    }

    var body: some View {
        face
            .frame(width: size, height: size)
            .clipShape(Circle())
            .grayscale(place.closed ? 1 : 0)
            .opacity(place.depth == .words && !selected ? 0.8 : 1)
            .overlay { collar }
            .overlay { if place.closed { shutRing } }
            .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
            // The whole 44pt box is the target, but only the mark is drawn:
            // a tap lands on the picture, never on the empty corners.
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }

    @ViewBuilder
    private var face: some View {
        if let image = mark.pin {
            image.resizable().aspectRatio(contentMode: .fill)
        } else {
            Circle().fill(tone)
        }
    }

    /// Three readings, drawn as concentric strokes. A stroke sits centred on
    /// the path, so each radius is offset by half its own width to sit outside
    /// the face rather than over it.
    @ViewBuilder
    private var collar: some View {
        switch place.depth {
        case .reel:
            Circle().stroke(tone, lineWidth: 2.5).padding(-1.25)
        case .photos:
            ZStack {
                Circle().stroke(theme.paper, lineWidth: 2.5).padding(-1.25)
                Circle().stroke(tone, lineWidth: 1.7).padding(-3.35)
            }
        case .words:
            ZStack {
                Circle().stroke(theme.paper, lineWidth: 2).padding(-1)
                Circle().stroke(tone, lineWidth: 1).padding(-2.5)
            }
        }
    }

    /// The broken circle. It says the same thing the word "Closed" says in the
    /// list, in the same shape, so the map needs no key printed beside it.
    private var shutRing: some View {
        Circle()
            .stroke(theme.muted, style: StrokeStyle(lineWidth: 1.5, dash: [2.6, 2.6]))
            .padding(-6)
    }
}

/// The count on a cluster: several places sharing one dot because at this zoom
/// they would otherwise be a smear.
///
/// The site's reasoning, kept. It is the same mark every pin is, at the same
/// full strength — the places it stands for are places — with the count written
/// straight onto it in the style's own accent. It still never reads as a place:
/// a pin wears the accent as a collar, a cluster is ringed in paper instead and
/// wears the accent as the number, and it is bigger than any pin at every
/// count.
struct ClusterFace: View {
    let count: Int

    @Environment(MarkImage.self) private var mark
    @Environment(\.theme) private var theme

    private var diameter: CGFloat { CGFloat(PinCluster.dotDiameter(count)) }

    /// Two places under one dot is barely a crowd — it is the pair of doors you
    /// could not tell apart at this zoom — and it keeps the quiet paper rim.
    /// Past two the rim takes the style's own colour, the same red the number
    /// inside it is written in, so the dots worth pressing are the ones the map
    /// says something with.
    private var many: Bool { count > 2 }

    var body: some View {
        face
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .overlay { rim }
            .overlay { number }
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            .frame(width: max(diameter, 44), height: max(diameter, 44))
            .contentShape(Circle())
    }

    @ViewBuilder
    private var face: some View {
        if let image = mark.pin {
            image.resizable().aspectRatio(contentMode: .fill)
        } else {
            Circle().fill(theme.paper)
        }
    }

    /// A stroke sits centred on its path, so half of it is pushed back out to
    /// sit outside the face rather than over it.
    private var rim: some View {
        let width: CGFloat = many ? 3 : 2.5
        return Circle()
            .stroke(many ? theme.accent : theme.paper, lineWidth: width)
            .padding(-width / 2)
    }

    /// The site's ring of eight, in ems of the number's own size, so the casing
    /// thickens with the digits instead of thinning out under the big ones.
    private static let casing: [CGPoint] = [
        CGPoint(x: 0.09, y: 0.09), CGPoint(x: -0.09, y: 0.09),
        CGPoint(x: 0.09, y: -0.09), CGPoint(x: -0.09, y: -0.09),
        CGPoint(x: 0.12, y: 0), CGPoint(x: -0.12, y: 0),
        CGPoint(x: 0, y: 0.12), CGPoint(x: 0, y: -0.12)
    ]

    /// The count grows with the dot it sits in — a third of the width, so ten
    /// places carry a 14 point number where two carry a 12 point one. A fixed
    /// size was the whole reason the digits were hard to find: it read as a
    /// caption on a picture rather than as the thing the picture is there to
    /// count.
    ///
    /// The casing is the other half. Nothing is laid over the mark, so the
    /// digits sit straight on a photograph that runs from near-black in the gap
    /// of the mouth to near-white on the teeth, and the accent alone disappears
    /// against the dark half of it. A ring of paper around the glyphs, the way
    /// a map label has always cased itself, carries them across both: it leaves
    /// the picture untouched everywhere the letters are not.
    ///
    /// Drawn as eight offset copies, as on the site, rather than as stacked
    /// shadows. A shadow is an offscreen pass per layer, and these are views
    /// the map redraws on every frame of a pinch.
    private var number: some View {
        let size = diameter * 0.36
        let glyphs = Text(PinCluster.shownCount(count)).font(.mono(size))
        return ZStack {
            ForEach(Self.casing.indices, id: \.self) { index in
                glyphs
                    .foregroundStyle(theme.paper)
                    .offset(x: Self.casing[index].x * size, y: Self.casing[index].y * size)
            }
            glyphs.foregroundStyle(theme.accent)
        }
    }
}

/// The pin's collar, drawn small, beside a name in the list. Echoing the pin is
/// the one thing the badge can do that the word cannot: it makes every row a
/// key to the map, so the three kinds of pin stop needing to be guessed at.
struct DepthMark: View {
    let place: Place

    @Environment(ContentStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            glyph
            Text(store.strings(place.closed ? "closed" : place.depthMarkKey))
        }
        .font(.mono(10))
        .foregroundStyle(place.closed ? theme.muted : tone)
    }

    private var tone: Color {
        place.depth == .words ? theme.muted : theme.accent
    }

    /// Solid, a ring, a speck — and a broken circle for a place that has shut.
    @ViewBuilder
    private var glyph: some View {
        Group {
            if place.closed {
                Circle().stroke(theme.muted, style: StrokeStyle(lineWidth: 1.2, dash: [1.7, 1.7]))
            } else {
                switch place.depth {
                case .reel:   Circle().fill(tone)
                case .photos: Circle().strokeBorder(tone, lineWidth: 2)
                case .words:  Circle().fill(tone).padding(2.2)
                }
            }
        }
        .frame(width: 9, height: 9)
    }
}
