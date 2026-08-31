import CoreLocation
import SwiftUI

/// One line in the list: the name, the price band, what it is good for, and the
/// marks the site uses to say whether there is a reel or photos behind it.
struct PlaceRow: View {
    let place: Place
    var distance: CLLocationDistance?

    @Environment(ContentStore.self) private var store
    @Environment(Favourites.self) private var favourites
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(place.name)
                        .font(.display(16))
                        .foregroundStyle(place.closed ? theme.muted : theme.ink)
                        .lineLimit(2)
                    if favourites.contains(place) {
                        Image(systemName: "bookmark.fill")
                            .font(.caption2)
                            .foregroundStyle(theme.accent)
                            .accessibilityLabel(store.app(.saved))
                    }
                }

                HStack(spacing: 6) {
                    PriceGauge(price: place.price, dimmed: place.closed)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.mono(11))
                            .foregroundStyle(theme.muted)
                            .lineLimit(1)
                    }
                }

                if let deal = store.deal(for: place) {
                    Text(deal.offer(in: store.lang))
                        .font(.mono(11))
                        .foregroundStyle(theme.accent)
                        .lineLimit(1)
                }

                if place.closed {
                    Text(store.strings("closed"))
                        .font(.mono(11))
                        .foregroundStyle(theme.muted)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var thumbnail: some View {
        Group {
            if let file = place.photos.first {
                RemoteImage(url: ContentSource.photoURL(placeID: place.id, file: file))
            } else {
                Rectangle()
                    .fill(theme.hairline)
                    .overlay {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 15))
                            .foregroundStyle(theme.muted)
                    }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .opacity(place.closed ? 0.5 : 1)
    }

    /// What follows the gauge: "Coffee, Laptop friendly · 400 m"
    private var detail: String {
        var parts: [String] = []
        let types = store.typeLabels(for: place)
        if !types.isEmpty { parts.append(types.prefix(2).joined(separator: ", ")) }
        if let distance { parts.append(Self.format(distance)) }
        return parts.joined(separator: " · ")
    }

    static func format(_ metres: CLLocationDistance) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = metres < 1000 ? 0 : 1
        return formatter.string(from: Measurement(value: metres, unit: UnitLength.meters))
    }
}
