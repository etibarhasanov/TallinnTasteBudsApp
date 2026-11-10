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
/// Google and Apple are the other two ways in, and end in the same cookie:
/// `SocialSignIn` says how. The buttons are drawn only where the site says it
/// can answer them (`appGoogle` and `appApple` on `GET /api/account`), so an
/// app that reaches a copy of the site without those routes shows the two
/// fields and nothing that leads nowhere.
@MainActor
@Observable
final class AccountStore {
    private(set) var user: String?
    /// Whether the site has said yet who this is — before it has, the screens
    /// show neither the signed-in nor the signed-out version.
    private(set) var checked = false
    private(set) var mine: [ListSummary] = []
    private(set) var kept: [ListSummary] = []

    /// Whether the site can finish a Google or an Apple sign-in for an app.
    #if DEBUG
    private(set) var googleOffered = LaunchScript.doors
    private(set) var appleOffered = LaunchScript.doors
    #else
    private(set) var googleOffered = false
    private(set) var appleOffered = false
    #endif

    var signedIn: Bool { user != nil }

    /// Ask the site who this cookie belongs to, and fetch their lists.
    func refresh(saves: SavesStore) async {
        do {
            let data = try await API.data("api/account")
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            user = object["user"] as? String
            googleOffered = object["appGoogle"] as? Bool ?? false
            appleOffered = object["appApple"] as? Bool ?? false
            #if DEBUG
            if LaunchScript.doors { googleOffered = true; appleOffered = true }
            #endif
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

    /// Sign in through Google, making the account if this Google account has
    /// never been here. Throws `SocialSignIn.Cancelled` for a closed sheet.
    func enterWithGoogle(saves: SavesStore) async throws {
        let trip = try await SocialSignIn.shared.google()
        let answer = try await API.post("api/account", [
            "action": "ticket",
            "ticket": trip.ticket,
            "verifier": trip.verifier
        ])
        adopt(answer, saves: saves)
        await refreshLists()
    }

    /// The same through Apple.
    func enterWithApple(saves: SavesStore) async throws {
        let proof = try await SocialSignIn.shared.apple()
        let answer = try await API.post("api/apple", ["token": proof.token, "nonce": proof.nonce])
        adopt(answer, saves: saves)
        await refreshLists()
    }

    private func adopt(_ answer: [String: Any], saves: SavesStore) {
        user = answer["user"] as? String
        if let saved = answer["saved"] as? [String] { saves.adopt(saved) }
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
        case "google", "ticket": return t("accountErrGoogle", "Google sign-in did not finish. Try again.")
        case "apple": return t("appErrApple", "Apple sign-in did not finish. Try again.")
        case "slow-down": return t("accountErrSlow", "Too many tries. Wait a few minutes.")
        case "current": return t("accountErrCurrent", "That is not the password you use now.")
        case "confirm": return t("accountErrDeleteConfirm", "Type your username exactly as it is.")
        case "signed-out": return t("accountErrSignedOut", "You have been signed out. Sign in again.")
        case "title": return t("listsErrTitle", "A list needs a name.")
        case "too-many": return t("listsErrTooMany", "That is as many lists as one account can hold.")
        case "full": return t("listsErrFull", "That is as many places as one list can hold.")
        default: return t("accountErrGeneric", "Something went wrong. Try again.")
        }
    }
}
