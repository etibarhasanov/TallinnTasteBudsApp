import SwiftUI

/// The app's two styles, both sampled out of the painting the map is named for.
///
/// The mark was measured rather than guessed at: its paper is a warm cream
/// around #E7DCC1, the red in the gap of the mouth is #6F2326, the teeth carry
/// an olive shadow near #928A70, and the inside of the mouth is a plum-black
/// close to #130F17. Those four values are the whole system.
///
/// Paper is the painting from outside — its cream ground, its red. Mouth is
/// the same painting from inside, and not a recolouring of Paper.
struct Theme {
    let ink: Color
    let muted: Color
    let paper: Color
    let wash: Color
    let hairline: Color
    let accent: Color
    let accentLit: Color
    let here: Color

    /// Cream ground, oxblood accent, plum-black type.
    ///
    /// The accent is lifted a little off the painting's own #6F2326: at the
    /// size a chip label is set, the value straight off the canvas reads brown
    /// rather than red, and red is the half of it that matters.
    static let paper = Theme(
        ink: Color(hex: 0x241A22),
        muted: Color(hex: 0x7E6F5F),
        paper: Color(hex: 0xFAF4E6),
        wash: Color(hex: 0xEFE6CE),
        hairline: Color(hex: 0xDED0B2),
        accent: Color(hex: 0x8E2630),
        accentLit: Color(hex: 0xB03A42),
        here: Color(hex: 0x17629E)
    )

    /// The inside of the mouth: plum-black ground, cream type, and the red
    /// carried up to where it can be read against the dark.
    ///
    /// `here` is cyan for the reason the site turns it orange against green —
    /// the one dot on the map that is not a recommendation has to be the one
    /// thing that is never the accent colour.
    static let mouth = Theme(
        ink: Color(hex: 0xEDE4CE),
        muted: Color(hex: 0x9D9080),
        paper: Color(hex: 0x241D26),
        wash: Color(hex: 0x130F17),
        hairline: Color(hex: 0x3A303C),
        accent: Color(hex: 0xD9636B),
        accentLit: Color(hex: 0xF08C93),
        here: Color(hex: 0x56C8E0)
    )

    static func of(_ scheme: ColorScheme) -> Theme {
        scheme == .dark ? .mouth : .paper
    }
}

/// The reader's choice of style, persisted. Two, and only two: a third option
/// that follows the phone looks identical to whichever of these the phone is
/// already set to, which is a choice that cannot be seen.
enum StylePreference: String, CaseIterable, Identifiable {
    case paper, mouth
    var id: String { rawValue }

    var colorScheme: ColorScheme {
        self == .mouth ? .dark : .light
    }

    /// Named in the app's own strings. These two are the app's styles, not the
    /// site's, and the site's names for its own pair do not describe them.
    var labelKey: AppStrings.Key {
        self == .mouth ? .styleMouth : .stylePaper
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.paper
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
