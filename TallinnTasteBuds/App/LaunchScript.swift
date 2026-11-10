import Foundation

/// Opens the app on a given tab and screen, for the screenshots CI takes.
///
/// Nobody can look at a simulator from a cloud session, so the build workflow
/// launches the app several times with launch arguments and photographs what
/// it draws — `-ttbTab 1 -ttbOpen list:top-bars-hxzz7m` opens the Lists tab
/// with that list pushed. Launch arguments land in UserDefaults' argument
/// domain, so nothing is stored and nothing here runs for a reader, who never
/// launches the app with arguments.
enum LaunchScript {
    static var tab: Int { UserDefaults.standard.integer(forKey: "ttbTab") }

    /// The screens to push onto the given tab's stack at launch.
    static func routes(tab index: Int) -> [Route] {
        guard index == tab, let open = UserDefaults.standard.string(forKey: "ttbOpen") else { return [] }
        return open.split(separator: ",").compactMap { part in
            let bits = part.split(separator: ":", maxSplits: 1).map(String.init)
            guard bits.count == 2 else { return nil }
            switch bits[0] {
            case "place": return .place(bits[1])
            case "list": return .list(bits[1])
            case "profile": return .profile(bits[1])
            case "screen" where bits[1] == "discounts": return .discounts
            default: return nil
            }
        }
    }

    /// `-ttbRoute <place id>` opens the way to that place over the first
    /// screen; `-routeMode bus` chooses the bus, as a press of Bus would.
    static var route: String? { UserDefaults.standard.string(forKey: "ttbRoute") }
    /// `-ttbListFocus <place id>` opens a list's map on that place, as a press
    /// on the list's page does.
    static var listFocus: String? { UserDefaults.standard.string(forKey: "ttbListFocus") }
    /// `-ttbListMap YES` shows a list as its map rather than its page.
    static var listMap: Bool { UserDefaults.standard.bool(forKey: "ttbListMap") }
    /// `-ttbSheet signin` opens the sign-in sheet over the first screen.
    static var sheet: String? { UserDefaults.standard.string(forKey: "ttbSheet") }
    /// `-ttbEdit <list id>` opens that list's editor once it has loaded, so the
    /// editor can be photographed on a public list. Nothing is sent unless
    /// Save is pressed, and a script never presses it.
    static var edit: String? { UserDefaults.standard.string(forKey: "ttbEdit") }
    /// `-ttbPass <place id>` opens that place's discount pass over the first
    /// screen. Signed out, which a script always is, it shows the sign-in card.
    static var pass: String? { UserDefaults.standard.string(forKey: "ttbPass") }
    /// `-ttbPassPreview YES` draws the pass without asking the site, so the QR
    /// can be photographed by a script that has no account. Debug builds
    /// only: a release build has no such door past the member check.
    #if DEBUG
    static var passPreview: Bool { UserDefaults.standard.bool(forKey: "ttbPassPreview") }
    #endif
    /// `-ttbDoors YES` draws the Apple and Google buttons on the sign-in sheet
    /// whatever the site says it offers, so they can be photographed. Debug
    /// builds only; pressing one still asks the site, which answers as it does.
    #if DEBUG
    static var doors: Bool { UserDefaults.standard.bool(forKey: "ttbDoors") }
    #endif
    /// `-ttbType <chip id>` presses a filter chip on the map tab.
    static var type: String? { UserDefaults.standard.string(forKey: "ttbType") }
    /// `-ttbSelect <id>` presses a pin on the map tab.
    static var select: String? { UserDefaults.standard.string(forKey: "ttbSelect") }
    /// `-ttbQuery <words>` types into the map's search and presses Search, so
    /// the results are drawn; with `-ttbTyping YES` it stays in the field
    /// instead, with the suggestions under it.
    static var query: String? { UserDefaults.standard.string(forKey: "ttbQuery") }
    static var typing: Bool { UserDefaults.standard.bool(forKey: "ttbTyping") }
}
