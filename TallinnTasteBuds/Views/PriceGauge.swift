import SwiftUI

/// The site's price gauge: four slots, always four.
///
/// A band can land on a half step — 2.5 sits between the cheap end and the
/// middle — so a slot has three states rather than two. The half slot is a
/// ghosted sign with a second copy of the same glyph laid exactly over it and
/// masked to its left half, which keeps the glyph whole and keeps the row of
/// four the same width whatever the band is. That is how the site draws it,
/// and for the same reason.
///
/// It is a cost band, not a rating. Nothing on this map is rated.
struct PriceGauge: View {
    let price: Double
    /// Closed places grey out, as they do on the site.
    var dimmed = false

    @Environment(ContentStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...4, id: \.self) { slot in
                sign(fill: price - Double(slot) + 1)
            }
        }
        .font(.mono(13))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(store.strings("priceOf", ["n": Self.format(price, lang: store.lang)]))
    }

    private var lit: Color { dimmed ? theme.muted : theme.accent }

    @ViewBuilder
    private func sign(fill: Double) -> some View {
        if fill >= 1 {
            Text(verbatim: "€").foregroundStyle(lit)
        } else if fill >= 0.5 {
            ZStack {
                Text(verbatim: "€").foregroundStyle(theme.hairline)
                Text(verbatim: "€")
                    .foregroundStyle(lit)
                    .mask {
                        // Two flexible halves: the left one paints, the right
                        // one does not. Exactly half the glyph, at any size.
                        HStack(spacing: 0) {
                            Rectangle()
                            Color.clear
                        }
                    }
            }
        } else {
            Text(verbatim: "€").foregroundStyle(theme.hairline)
        }
    }

    /// The band as it reads out loud: whole numbers stay whole, half steps keep
    /// the one decimal they need, in the reading language's own decimal mark —
    /// so Estonian hears "2,5" where English hears "2.5".
    static func format(_ price: Double, lang: String) -> String {
        let whole = price.truncatingRemainder(dividingBy: 1) == 0
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: lang)
        formatter.minimumFractionDigits = whole ? 0 : 1
        formatter.maximumFractionDigits = whole ? 0 : 1
        return formatter.string(from: NSNumber(value: price)) ?? String(price)
    }
}
