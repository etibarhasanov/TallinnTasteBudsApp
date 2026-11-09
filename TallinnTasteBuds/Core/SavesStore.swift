import Foundation
import Observation

/// The places this phone saved.
///
/// Kept on the phone for now, which is what the website does for somebody who
/// has not signed in: their saves live in the browser. Sending a save to the
/// site is the next step and not this one — `/api/saves` asks a browser to
/// pass a Cloudflare Turnstile check before it writes, and an app cannot show
/// one, so the route needs a door for the app first. Until then nothing here
/// leaves the phone.
@MainActor
@Observable
final class SavesStore {
    private static let key = "saved-places"

    /// Newest first: the order they were pressed in is the order worth keeping.
    private(set) var ids: [String]

    init() {
        ids = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
    }

    func isSaved(_ id: String) -> Bool { ids.contains(id) }

    /// The places the account has saved on the website, folded in on sign-in
    /// so a reader finds them here too. One way only, for the reason above.
    func adopt(_ account: [String]) {
        let missing = account.filter { !ids.contains($0) }
        guard !missing.isEmpty else { return }
        ids += missing
        UserDefaults.standard.set(ids, forKey: Self.key)
    }

    func toggle(_ id: String) {
        if let at = ids.firstIndex(of: id) {
            ids.remove(at: at)
        } else {
            ids.insert(id, at: 0)
        }
        UserDefaults.standard.set(ids, forKey: Self.key)
    }
}
