import SwiftUI

/// The logo: the mark beside the name, the way the site's header carries it.
///
/// The site's reasoning for putting the two together, kept. Stacked, the mark
/// was a picture parked in a corner with half a line of nothing beside it,
/// which reads as something left there rather than as the logo. Beside the
/// name it has a job. On a phone the site has since taken the card off the
/// pair entirely and gone round with the crop, which is what this does.
///
/// A navigation bar is one line tall, so the name does not break after
/// "Tallinn" here the way it does on the site — but the lockup is the same
/// lockup, and it is what the app was missing: the header said the name and
/// showed nothing, on the map and over the list both.
struct BrandMark: View {
    /// How tall the painting is drawn. The wordmark is set against it.
    var height: CGFloat = 26

    @Environment(ContentStore.self) private var store
    @Environment(MarkImage.self) private var mark
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            painting
            Text(store.strings("wordmark"))
                .font(.display(17, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(store.strings("wordmark"))
        .accessibilityAddTraits(.isHeader)
    }

    /// Round, and the square crop rather than the wide one — the site's own
    /// change. This is not a picture on a page, it is the account's face at the
    /// top of a map, in the position and at the size a profile picture
    /// occupies; round is what that position means, and the mouth fills a
    /// circle where the wide crop would have to be cut again to fit one.
    ///
    /// Nothing is drawn until there is something to draw: the space is held so
    /// the wordmark does not jump sideways when the picture arrives.
    @ViewBuilder
    private var painting: some View {
        Group {
            if let face = mark.pin {
                face.resizable().aspectRatio(contentMode: .fill)
            } else {
                Color.clear
            }
        }
        .frame(width: height, height: height)
        .clipShape(Circle())
    }
}
