import SwiftUI

/// The logo: the painting beside the name, the way the site's header card
/// carries it.
///
/// The site's reasoning for putting the two together, kept. Stacked, the mark
/// was a picture parked in a corner with half a line of nothing beside it,
/// which reads as something left there rather than as the logo. Beside the
/// name it has a job.
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

    /// The crop is 82 by 64 on the site, and the aspect ratio is fixed here so
    /// the lockup does not resize under the wordmark when the fetched copy
    /// lands on top of the bundled one.
    private static let aspect: CGFloat = 82.0 / 64.0

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

    /// Nothing is drawn until there is something to draw: the space is held so
    /// the wordmark does not jump sideways when the picture arrives.
    @ViewBuilder
    private var painting: some View {
        Group {
            if let brand = mark.brand {
                brand.resizable().aspectRatio(contentMode: .fill)
            } else {
                Color.clear
            }
        }
        .frame(width: height * Self.aspect, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}
