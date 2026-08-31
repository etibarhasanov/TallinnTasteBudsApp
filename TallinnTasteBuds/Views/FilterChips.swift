import SwiftUI

/// The site's filter row: "All" plus one chip per type in use, OR semantics, and
/// the discount chip on the end when there is a live discount.
///
/// Two shapes, as on the site. Flat, which is what the list screen wants —
/// there is no map behind it to hide and the answer should not be a press away.
/// And folded into a drawer, which is what the map wants, for the site's own
/// reason and for one of the app's.
///
/// The site's reason: the whole type vocabulary laid flat is a dozen words in
/// front of Tallinn before the visitor has looked at it, and on a phone
/// thirteen of them are off the right edge besides.
///
/// The app's reason: a horizontal scroller lying across the top of a map claims
/// every gesture that starts inside it, and a pinch is a gesture that starts
/// inside it. The chip row spanned the full width, so a pinch aimed at Tallinn
/// scrolled the chips sideways and the map sat still — not a rare miss but most
/// pinches, because that strip is exactly where a hand comes down. Shut, the
/// row is one pill wide and the rest of the map is map again.

// MARK: - The pill

/// A chip, drawn: mono, paper until it is pressed and the accent after. The
/// site's values, to the pixel and the letter-spacing.
private struct ChipLabel: View {
    let text: String
    var selected = false
    /// Not a filter — the button the drawer opens by, which is a chip like the
    /// ones it opens but never says the map is filtered.
    var open = false
    var icon: String? = nil

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 7) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .rotationEffect(.degrees(open ? 90 : 0))
            }
            Text(text)
                .font(.mono(11))
                .tracking(0.66)   // the site's .06em, at 11px
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .foregroundStyle(selected ? theme.paper : (open ? theme.ink : theme.muted))
        .background(selected ? theme.accent : theme.paper)
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(
                selected ? theme.accent : (open ? theme.muted : theme.hairline),
                lineWidth: 1
            )
        }
        .shadow(color: .black.opacity(0.14), radius: 7, y: 2)
    }
}

/// One filter, pressed on and off.
struct FilterChip: View {
    let label: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ChipLabel(text: label, selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

// MARK: - The chips themselves

/// "All" first, then the site's order: the discount, then the types in use.
private struct ChipRow: View {
    @Environment(ContentStore.self) private var store

    var body: some View {
        HStack(spacing: 6) {
            FilterChip(label: store.strings("filterAll"), selected: store.activeTypes.isEmpty) {
                store.activeTypes.removeAll()
            }
            ForEach(store.chips) { item in
                FilterChip(label: item.label, selected: store.activeTypes.contains(item.id)) {
                    if store.activeTypes.contains(item.id) {
                        store.activeTypes.remove(item.id)
                    } else {
                        store.activeTypes.insert(item.id)
                    }
                }
            }
        }
        // Room for the pills' own shadows, which a scroll view cuts off at its
        // edges otherwise.
        .padding(.horizontal, 3)
        .padding(.vertical, 6)
    }
}

// MARK: - Flat, for the list

struct FilterChips: View {
    @Environment(ContentStore.self) private var store

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ChipRow().padding(.horizontal, 13)
        }
        .accessibilityLabel(store.strings("filters"))
    }
}

// MARK: - Folded, for the map

/// Shut, it is one chip that says Filters. Pressed, the row unrolls to the
/// right out of that button, which is the direction it scrolls in.
///
/// Shut is also "All", because no chip pressed has always meant every place
/// showing: a shut drawer can never be a filtered map, so nothing on the button
/// has to warn you that it is one. That costs the filter you had picked, which
/// is why a press on the map does not shut it — the button is the only way out
/// of the row, and pressing it is a deliberate act.
struct FilterDrawer: View {
    @Binding var open: Bool

    @Environment(ContentStore.self) private var store
    @State private var rowWidth: CGFloat = 0

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            toggle
            if open { scroller }
            // Everything to the right of the chips is map, and stays map.
            Spacer(minLength: 0)
        }
        .animation(.easeOut(duration: 0.3), value: open)
        // A filter can be set on the list screen, where there is no drawer.
        // Coming back to a shut button in front of a filtered map would be the
        // one state this design says cannot exist, so the row arrives open,
        // showing what is doing the filtering.
        .onAppear(perform: followFilters)
        .onChange(of: store.activeTypes) { _, _ in followFilters() }
    }

    private var toggle: some View {
        Button { set(open: !open) } label: {
            ChipLabel(
                text: store.strings("filtersButton"),
                open: open,
                icon: "line.3.horizontal.decrease"
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.strings("filtersButton"))
        .accessibilityHint(store.strings("filters"))
        .accessibilityAddTraits(open ? [.isSelected] : [])
    }

    private var scroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ChipRow()
                // How wide the chips actually are. A GeometryReader behind them
                // rather than onGeometryChange, which arrived in iOS 18 and this
                // app runs from 17.
                .background {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { rowWidth = geo.size.width }
                            .onChange(of: geo.size.width) { _, width in rowWidth = width }
                    }
                }
        }
        // Only as wide as its chips, so a short vocabulary leaves the rest of
        // the strip live map — the site's `flex: 0 1 auto`. The frame is a
        // ceiling rather than a width, so a long vocabulary still stops at the
        // edge of the screen and scrolls, which is its `max-width: 100%`.
        .frame(maxWidth: rowWidth > 0 ? rowWidth : .infinity)
        .transition(.move(edge: .leading).combined(with: .opacity))
        .accessibilityLabel(store.strings("filters"))
    }

    private func set(open value: Bool) {
        guard value != open else { return }
        open = value
        // Exactly what pressing All does, because shutting the row is the same
        // answer said a different way.
        if !value { store.activeTypes.removeAll() }
    }

    private func followFilters() {
        if !store.activeTypes.isEmpty, !open { open = true }
    }
}
