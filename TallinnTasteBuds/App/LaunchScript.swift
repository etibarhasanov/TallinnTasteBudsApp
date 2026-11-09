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
            default: return nil
            }
        }
    }

    /// `-ttbListMap YES` shows a list as its map rather than its page.
    static var listMap: Bool { UserDefaults.standard.bool(forKey: "ttbListMap") }
    /// `-ttbSheet signin` opens the sign-in sheet over the first screen.
    static var sheet: String? { UserDefaults.standard.string(forKey: "ttbSheet") }
    /// `-ttbEdit <list id>` opens that list's editor once it has loaded, so the
    /// editor can be photographed on a public list. Nothing is sent unless
    /// Save is pressed, and a script never presses it.
    static var edit: String? { UserDefaults.standard.string(forKey: "ttbEdit") }
    /// `-ttbSelect <id>` presses a pin on the map tab.
    static var select: String? { UserDefaults.standard.string(forKey: "ttbSelect") }
}
