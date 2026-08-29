import SwiftUI

/// The website's two styles, to the value, from `assets/styles.css`.
///
/// The site calls them Red and Green; Red is the light one and Green is the
/// dark one, so the app maps them onto light and dark and offers the same
/// choice the rail on the site does — plus "System", which a phone needs and a
/// browser tab does not.
struct Theme {
    let ink: Color
    let muted: Color
    let paper: Color
    let wash: Color
    let hairline: Color
    let accent: Color
    let accentLit: Color
    let here: Color

    static let red = Theme(
        ink: Color(hex: 0x27141A),
        muted: Color(hex: 0x7D5754),
        paper: Color(hex: 0xFFF0EA),
        wash: Color(hex: 0xF7DDD4),
        hairline: Color(hex: 0xF0CEC3),
        accent: Color(hex: 0xA81E28),
        accentLit: Color(hex: 0xC9323D),
        here: Color(hex: 0x0B62C4)
    )

    static let green = Theme(
        ink: Color(hex: 0xE7F1EA),
        muted: Color(hex: 0xA2B7A9),
        paper: Color(hex: 0x1D2A23),
        wash: Color(hex: 0x101A15),
        hairline: Color(hex: 0x354740),
        accent: Color(hex: 0x6FD39A),
        accentLit: Color(hex: 0x93E7B7),
        here: Color(hex: 0xE0873A)
    )

    static func of(_ scheme: ColorScheme) -> Theme {
        scheme == .dark ? .green : .red
    }
}

/// The reader's choice of style, persisted. The same two the site offers, and
/// only those: a third option that follows the phone looks identical to
/// whichever of these the phone is already set to, which is a choice that
/// cannot be seen.
enum StylePreference: String, CaseIterable, Identifiable {
    case red, green
    var id: String { rawValue }

    var colorScheme: ColorScheme {
        self == .green ? .dark : .light
    }

    /// The label comes from `ui.json` so it is translated with everything else.
    func label(_ strings: Strings) -> String {
        self == .green ? strings("styleGreen") : strings("styleRed")
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.red
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension Font {
    /// The site sets display type in Familjen Grotesk and body in Literata.
    /// Neither ships with iOS, so the app uses the system faces at the same
    /// weights and keeps the serif for running text, which is the part of the
    /// site's voice that actually carries.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func running(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}
