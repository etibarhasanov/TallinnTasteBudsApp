import SwiftUI

/// The app's two styles.
///
/// Red is the site's own light palette, to the value, from `assets/styles.css`.
/// The dark one is the app's: the site's dark style is a mint green, and this
/// is pink, built on the same seven roles so that every screen keeps working
/// without knowing which style it is drawing.
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

    /// Plum paper under a pink accent. `here` goes cyan for the same reason it
    /// goes orange in the site's green: the dot showing where you are has to be
    /// the one thing on the map that is not the accent colour.
    static let pink = Theme(
        ink: Color(hex: 0xF6E8EE),
        muted: Color(hex: 0xBFA2AE),
        paper: Color(hex: 0x2A1B22),
        wash: Color(hex: 0x170E13),
        hairline: Color(hex: 0x443039),
        accent: Color(hex: 0xF59AC0),
        accentLit: Color(hex: 0xFFBCD7),
        here: Color(hex: 0x56C8E0)
    )

    static func of(_ scheme: ColorScheme) -> Theme {
        scheme == .dark ? .pink : .red
    }
}

/// The reader's choice of style, persisted. Two, and only two: a third option
/// that follows the phone looks identical to whichever of these the phone is
/// already set to, which is a choice that cannot be seen.
enum StylePreference: String, CaseIterable, Identifiable {
    case red, pink
    var id: String { rawValue }

    var colorScheme: ColorScheme {
        self == .pink ? .dark : .light
    }

    /// Named in the app's own strings rather than in `ui.json`. The site names
    /// its dark style Green, and this one is not that.
    var labelKey: AppStrings.Key {
        self == .pink ? .stylePink : .styleRed
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
