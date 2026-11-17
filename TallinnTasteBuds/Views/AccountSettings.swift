import SwiftUI

// The three things the website's account page lets a member change that the
// app could not: the password, the username, and the page under their name —
// the name they go by, their line, and their Instagram, TikTok and Facebook.
// Each sends the same action the website's page does to `/api/account`, in
// the website's words. The page's other parts — the line in other languages,
// the languages they speak and the page of links — stay on the website's
// editor, which the page screen links to.

/// Change password: the one in use now (empty on an account that signed up
/// through Google and has none yet), and the new one.
struct ChangePasswordView: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var next = ""
    @State private var busy = false
    @State private var problem: String?
    @State private var done = false

    var body: some View {
        Form {
            Section {
                SecureField(content.t("accountCurrentPassword", "Current password"), text: $current)
                    .textContentType(.password)
                SecureField(content.t("accountNewPassword", "New password"), text: $next)
                    .textContentType(.newPassword)
            } footer: {
                Text(content.t("accountChangeWhy", "You will need the password you use now.") + " "
                     + content.t("accountChangeSignsOut", "Changing it signs out every other device. This one stays signed in."))
            }
            if let problem { Text(problem).foregroundStyle(Theme.accent) }
            if done {
                Text(content.t("accountChangeDone", "Password changed. Every other device has been signed out."))
                    .foregroundStyle(RouteView.Mode.foot.color)
            }
            Button(busy ? content.t("accountWorking", "Working…") : content.t("accountChangeGo", "Save the new one")) {
                Task {
                    busy = true
                    problem = nil
                    defer { busy = false }
                    do {
                        try await account.changePassword(current: current, to: next)
                        done = true
                        current = ""
                        next = ""
                    } catch {
                        problem = content.say(error)
                    }
                }
            }
            .disabled(busy || next.count < 8)
        }
        .scrollContentBackground(.hidden)
        .paperBackground()
        .navigationTitle(content.t("accountChange", "Change password"))
    }
}

/// Change username: the new one and, on an account with a password, that
/// password.
struct ChangeUsernameView: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account
    @State private var name = ""
    @State private var current = ""
    @State private var busy = false
    @State private var problem: String?
    @State private var done: String?

    var body: some View {
        Form {
            Section {
                TextField(content.t("accountNewUsername", "New username"), text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                SecureField(content.t("accountCurrentPassword", "Current password"), text: $current)
                    .textContentType(.password)
            } header: {
                Text(content.t("accountNameWhy", "You are {name} today. Everything you saved, wrote and kept comes with you.",
                               ["name": account.user ?? ""]))
                    .textCase(nil)
            } footer: {
                Text(content.t("accountUsernameHint", "3–24 letters or numbers. Shown on lists you share.") + " "
                     + content.t("accountNameCosts", "Links to your old profile stop working. That name stays yours for thirty days, then anybody can take it."))
            }
            if let problem { Text(problem).foregroundStyle(Theme.accent) }
            if let done {
                Text(content.t("accountNameDone", "You are {name} now.", ["name": done]))
                    .foregroundStyle(RouteView.Mode.foot.color)
            }
            Button(busy ? content.t("accountWorking", "Working…") : content.t("accountNameGo", "Take the new name")) {
                Task {
                    busy = true
                    problem = nil
                    defer { busy = false }
                    do {
                        try await account.changeUsername(to: name, current: current)
                        done = account.user
                        current = ""
                    } catch {
                        problem = content.say(error)
                    }
                }
            }
            .disabled(busy || name.trimmingCharacters(in: .whitespaces).count < 3)
        }
        .scrollContentBackground(.hidden)
        .paperBackground()
        .navigationTitle(content.t("accountName", "Change username"))
    }
}

/// The page under your name: the name you go by, your line, and your handles
/// on the three networks the website knows. Read from your own profile and
/// saved part by part, only the parts that changed, as the website's editor
/// does.
struct EditPageView: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account
    @Environment(\.openURL) private var openURL

    /// The three the website's `assets/links.js` knows, by their own names.
    private static let networks = [("instagram", "Instagram"), ("tiktok", "TikTok"), ("facebook", "Facebook")]
    /// The server's MAX_ABOUT.
    private static let maxAbout = 200

    @State private var loaded = false
    @State private var display = ""
    @State private var about = ""
    @State private var handles: [String: String] = [:]
    @State private var was: (display: String, about: String, handles: [String: String]) = ("", "", [:])
    @State private var busy = false
    @State private var problem: String?
    @State private var saved = false

    private var dirty: Bool { display != was.display || about != was.about || handles != was.handles }

    var body: some View {
        Form {
            if !loaded {
                ProgressView()
            } else {
                Section {
                    TextField(content.t("accountDisplay", "The name you go by"), text: $display)
                } footer: {
                    Text(content.t("accountDisplayHint", "Shown over your line on your profile"))
                }
                Section {
                    TextField(content.t("editLine", "Your line"), text: $about, axis: .vertical)
                        .lineLimit(2...5)
                        .onChange(of: about) { _, text in
                            if text.count > Self.maxAbout { about = String(text.prefix(Self.maxAbout)) }
                        }
                } footer: {
                    Text(content.t("accountAboutHint", "A line about you, shown on your public profile."))
                }
                Section {
                    ForEach(Self.networks, id: \.0) { id, label in
                        HStack {
                            Text(label).foregroundStyle(Theme.ink)
                            TextField("@", text: Binding(get: { handles[id] ?? "" }, set: { handles[id] = $0 }))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                if let problem { Text(problem).foregroundStyle(Theme.accent) }
                if saved && !dirty {
                    Text(content.t("listsSaved", "Saved.")).foregroundStyle(RouteView.Mode.foot.color)
                }
                Button(busy ? content.t("accountWorking", "Working…") : content.t("listsSave", "Save")) {
                    Task { await save() }
                }
                .disabled(busy || !dirty)
                Section {
                    Button(content.t("editDoor", "Build your page")) {
                        openURL(API.base.appendingPathComponent("edit.html"))
                    }
                } footer: {
                    Text(content.t("editLinksWhy", "What stands under your name, in this order. Drag a row by its handle to move it."))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .paperBackground()
        .navigationTitle(content.t("editTitle", "Your page"))
        .task { await load() }
    }

    private func load() async {
        guard let name = account.user,
              let profile = (try? await API.get(ProfileEnvelope.self, "api/profile", ["name": name]))?.profile else {
            loaded = true
            return
        }
        display = profile.display ?? ""
        about = profile.about ?? ""
        handles = profile.links.filter { key, _ in Self.networks.contains { $0.0 == key } }
        was = (display, about, handles)
        loaded = true
    }

    private func save() async {
        busy = true
        problem = nil
        saved = false
        defer { busy = false }
        do {
            if display != was.display { try await account.savePage(["action": "display", "display": display]) }
            if about != was.about { try await account.savePage(["action": "about", "about": about]) }
            if handles != was.handles {
                var body: [String: Any] = ["action": "links"]
                for (id, _) in Self.networks { body[id] = handles[id] ?? "" }
                do {
                    try await account.savePage(body)
                } catch let refusal as API.Refusal where refusal.code == "bad-link" {
                    let label = Self.networks.first { $0.0 == refusal.network }?.1 ?? ""
                    problem = content.t("accountErrLink", "{name} — that doesn't look like a handle.", ["name": label])
                    return
                }
            }
            was = (display, about, handles)
            saved = true
        } catch {
            problem = content.say(error)
        }
    }
}
