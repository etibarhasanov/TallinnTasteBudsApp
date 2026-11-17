import Foundation
import Observation

/// The places this phone saved, and — signed in — the account's.
///
/// Signed out they live on the phone, the way a signed-out reader's live in
/// the browser. Signed in, every press goes to `/api/saves` as well, under the
/// session, so the save is on the account and on every device it signs in
/// on; and signing in sends the account whatever this phone saved before it
/// was signed in, and folds in what the account saved elsewhere. The phone's
/// copy is kept either way, so a press works offline and a refusal from the
/// site costs nothing on screen.
///
/// `/api/saves` can ask for a Cloudflare Turnstile check before it writes,
/// which an app cannot show. It is switched off on the site today (the key
/// in `index.html` is empty); if it is ever switched on, the site refuses
/// the app's saves with `challenge` and they stay on the phone, as they all
/// did before.
@MainActor
@Observable
final class SavesStore {
    private static let key = "saved-places"

    /// Newest first: the order they were pressed in is the order worth keeping.
    private(set) var ids: [String]
    /// Set by `AccountStore`: whether a press also goes to the account.
    var signedIn = false

    init() {
        ids = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
    }

    func isSaved(_ id: String) -> Bool { ids.contains(id) }

    /// The places the account has saved, on sign-in: the account's are
    /// folded in here, and this phone's that the account lacks are sent to it.
    func adopt(_ account: [String]) {
        signedIn = true
        let theirs = Set(account)
        let mineOnly = ids.filter { !theirs.contains($0) }
        let missing = account.filter { !ids.contains($0) }
        if !missing.isEmpty {
            ids += missing
            UserDefaults.standard.set(ids, forKey: Self.key)
        }
        Task { for id in mineOnly { await send(id, on: true) } }
    }

    func toggle(_ id: String) {
        let on: Bool
        if let at = ids.firstIndex(of: id) {
            ids.remove(at: at)
            on = false
        } else {
            ids.insert(id, at: 0)
            on = true
        }
        UserDefaults.standard.set(ids, forKey: Self.key)
        if signedIn { Task { await send(id, on: on) } }
    }

    /// One save or unsave on the account. A refusal — a place the site does
    /// not know, a cap, a check it wants — leaves the phone's copy as it is.
    private func send(_ id: String, on: Bool) async {
        _ = try? await API.post("api/saves", ["place": id, "on": on])
    }
}
