import SwiftUI

/// The site's filter row: "All" plus one chip per type in use, OR semantics, and
/// the discount chip on the end when there is a live discount.
struct FilterChips: View {
    @Environment(ContentStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: store.strings("filterAll"), selected: store.activeTypes.isEmpty) {
                    store.activeTypes.removeAll()
                }
                ForEach(store.chips) { item in
                    chip(label: item.label, selected: store.activeTypes.contains(item.id)) {
                        if store.activeTypes.contains(item.id) {
                            store.activeTypes.remove(item.id)
                        } else {
                            store.activeTypes.insert(item.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(theme.wash)
        .accessibilityLabel(store.strings("filters"))
    }

    private func chip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.display(13, weight: selected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? theme.accent : theme.paper)
                .foregroundStyle(selected ? theme.paper : theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(selected ? Color.clear : theme.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
