import SwiftUI

/// The website's colours, to the value: the tokens at the top of
/// `assets/styles.css` in the website repo. Brick on a warm paper.
enum Theme {
    static let ink = Color(hex: 0x27141A)
    static let muted = Color(hex: 0x7D5754)
    static let paper = Color(hex: 0xFFF0EA)
    static let wash = Color(hex: 0xF7DDD4)
    static let hairline = Color(hex: 0xF0CEC3)
    static let accent = Color(hex: 0xA81E28)
    static let here = Color(hex: 0x0B62C4)
    static let card = Color.white

    static let radius: CGFloat = 14
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// A rounded white card on the paper, with the hairline the site draws.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.hairline))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }

    /// The page's paper behind a scroll view or a list.
    func paperBackground() -> some View {
        self.scrollContentBackground(.hidden).background(Theme.paper.ignoresSafeArea())
    }
}

/// A small pill: a kind of place, a dish.
struct Tag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.wash, in: Capsule())
            .foregroundStyle(Theme.ink)
    }
}

/// A heading over a group, in the site's small capitals.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1)
            .foregroundStyle(Theme.muted)
    }
}

/// Wraps tags onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += line + spacing; line = 0 }
            x += size.width + spacing
            line = max(line, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, width), height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { x = bounds.minX; y += line + spacing; line = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            line = max(line, size.height)
        }
    }
}

/// A photo from the site, or the paper-coloured square it would sit in.
struct Photo: View {
    let url: URL?
    var body: some View {
        Rectangle()
            .fill(Theme.wash)
            .overlay {
                if let url {
                    AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.clear
                        }
                    }
                }
            }
            .clipped()
    }
}

/// The painting the website marks its own places with, in a circle.
struct Mark: View {
    var size: CGFloat = 30

    private static let image: UIImage? = {
        guard let url = Disk.bundled("mark-round", "webp") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }()

    var body: some View {
        Group {
            if let image = Self.image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.accent
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// A full-width message for a screen with nothing to show yet.
struct EmptyNote: View {
    let title: String
    let text: String
    var systemImage: String = "tray"

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(text)
        }
        .foregroundStyle(Theme.muted)
    }
}
