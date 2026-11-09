import Foundation
import Observation

/// Who is signed in, and the lists that belong to them.
///
/// An account here is the website's account and nothing else: a username and
/// a password, checked by `/api/account`, and a session the site hands back as
/// its HttpOnly cookie. `URLSession`'s shared cookie store keeps that cookie
/// across launches the way a browser would, so the app needs no token of its
/// own and the server needed no change to let it in.
///
/// Google sign-in is not offered here yet. It needs the system's sign-in
/// sheet rather than a web view, and once a third-party sign-in is offered
/// App Review asks for Sign in with Apple beside it; both are server work.
/// Somebody who made their account with Google can set a password for it on
/// the website and sign in with that.
@MainActor
@Observable
final class AccountStore {
    private(set) var user: String?
    /// Whether the site has said yet who this is — before it has, the screens
    /// show neither the signed-in nor the signed-out version.
    private(set) var checked = false
    private(set) var mine: [ListSummary] = []
    private(set) var kept: [ListSummary] = []

    var signedIn: Bool { user != nil }

    /// Ask the site who this cookie belongs to, and fetch their lists.
    func refresh(saves: SavesStore) async {
        do {
            let data = try await API.data("api/account")
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            user = object["user"] as? String
            if let saved = object["saved"] as? [String] { saves.adopt(saved) }
            checked = true
            await refreshLists()
        } catch {
            // Offline: keep whatever we believed, so a signed-in reader on a
            // train is not shown a sign-in form.
            checked = true
        }
    }

    func refreshLists() async {
        guard signedIn else { mine = []; kept = []; return }
        if let answer = try? await API.get(MyLists.self, "api/lists") {
            mine = answer.lists
            kept = answer.kept
        }
    }

    /// Sign in, or make the account first. Throws the route's refusal.
    func enter(username: String, password: String, create: Bool, saves: SavesStore) async throws {
        let answer = try await API.post("api/account", [
            "action": create ? "create" : "login",
            "username": username,
            "password": password
        ])
        user = answer["user"] as? String
        if let saved = answer["saved"] as? [String] { saves.adopt(saved) }
        await refreshLists()
    }

    func signOut() async {
        _ = try? await API.post("api/account", ["action": "logout"])
        clear()
    }

    /// Delete the account for good. The site asks for the password again, or,
    /// for an account that never had one, the username typed out.
    func delete(confirmation: String) async throws {
        try await API.post("api/account", ["action": "delete", "current": confirmation, "username": confirmation])
        clear()
    }

    private func clear() {
        user = nil
        mine = []
        kept = []
        if let cookies = HTTPCookieStorage.shared.cookies(for: API.base) {
            for cookie in cookies where cookie.name == "ttb_s" { HTTPCookieStorage.shared.deleteCookie(cookie) }
        }
    }

    // MARK: Lists

    /// A new list, empty, and its id.
    func createList(title: String, intro: String = "") async throws -> String {
        let answer = try await API.post("api/lists", ["action": "create", "title": title, "intro": intro])
        await refreshLists()
        guard let id = answer["id"] as? String else { throw API.Refusal(code: "generic", status: 500) }
        return id
    }

    func addPlace(_ place: String, to list: String) async throws {
        try await API.post("api/lists", ["action": "add", "id": list, "place": place])
    }

    func drop(_ place: String, from list: String) async throws {
        try await API.post("api/lists", ["action": "drop", "id": list, "place": place])
    }

    func deleteList(_ id: String) async throws {
        try await API.post("api/lists", ["action": "delete", "id": id])
        await refreshLists()
    }

    /// Save somebody else's list, or let it go. Answers the new count.
    func keep(_ id: String, _ on: Bool) async throws -> Int {
        let answer = try await API.post("api/lists", ["action": on ? "keep" : "unkeep", "id": id])
        await refreshLists()
        return answer["keeps"] as? Int ?? 0
    }

    func isKept(_ id: String) -> Bool { kept.contains { $0.id == id } }
}

/// The website's own sentence for a refusal, in the reader's language.
extension ContentStore {
    func say(_ error: Error) -> String {
        guard let refusal = error as? API.Refusal else {
            return t("appOffline", "Couldn’t reach tallinntastebuds.ee.")
        }
        switch refusal.code {
        case "username": return t("accountErrUsername", "Use 3 to 24 letters, numbers, dots, dashes or underscores.")
        case "password": return t("accountErrPassword", "Password must be at least 8 characters.")
        case "taken": return t("accountErrTaken", "That username is taken.")
        case "no-match": return t("accountErrNoMatch", "Wrong username or password.")
        case "slow-down": return t("accountErrSlow", "Too many tries. Wait a few minutes.")
        case "current": return t("accountErrCurrent", "That is not the password you use now.")
        case "confirm": return t("accountErrDeleteConfirm", "Type your username exactly as it is.")
        case "signed-out": return t("accountErrSignedOut", "You have been signed out. Sign in again.")
        case "title": return t("appErrTitle", "A list needs a name.")
        case "too-many": return t("appErrTooMany", "That is as many as one account can have.")
        case "full": return t("appErrFull", "A list holds fifty places at most.")
        default: return t("accountErrGeneric", "Something went wrong. Try again.")
        }
    }
}
