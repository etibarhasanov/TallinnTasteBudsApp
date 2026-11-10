import SwiftUI

/// The last tab: the account, the language, and the way out to the website
/// and Instagram.
struct MeTab: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account
    @Environment(\.openURL) private var openURL
    @State private var path = NavigationPath(LaunchScript.routes(tab: 3))
    @State private var deleting = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                accountSection

                Section {
                    Picker(content.t("language", "Language"), selection: Binding(
                        get: { content.lang },
                        set: { code in Task { await content.setLanguage(code) } }
                    )) {
                        ForEach(content.languages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                }
                .listRowBackground(Theme.card)

                if !content.liveDeals.isEmpty {
                    Section {
                        NavigationLink(value: Route.discounts) {
                            HStack {
                                Label(content.t("appDiscounts", "Discounts"), systemImage: "tag")
                                Spacer()
                                Text("\(content.liveDeals.count)").foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .listRowBackground(Theme.card)
                }

                Section {
                    NavigationLink(value: Route.profile("tallinntastebuds")) {
                        Label(content.t("appAbout", "About Tallinn Tastebuds"), systemImage: "info.circle")
                    }
                    link(content.t("appWebsite", "tallinntastebuds.ee"), "globe", API.base)
                    link("Instagram", "camera", URL(string: "https://www.instagram.com/tallinntastebuds")!)
                    link(content.t("appPrivacy", "Privacy"), "hand.raised", API.url("privacy"))
                }
                .listRowBackground(Theme.card)

                if account.signedIn {
                    Section {
                        Button(content.t("accountDelete", "Delete account"), role: .destructive) { deleting = true }
                    }
                    .listRowBackground(Theme.card)
                }

                Section {
                    Text(version).font(.footnote).foregroundStyle(Theme.muted)
                }
                .listRowBackground(Color.clear)
            }
            .paperBackground()
            .navigationTitle(content.t("appTabMe", "Me"))
            .withRoutes()
            .sheet(isPresented: $deleting) { DeleteAccountView() }
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        if let user = account.user {
            Section {
                NavigationLink(value: Route.profile(user)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(content.t("accountSignedIn", "Signed in as {name}", ["name": user]))
                            .font(.headline).foregroundStyle(Theme.ink)
                        Text(content.t("appYourProfile", "Your profile, as everybody sees it"))
                            .font(.subheadline).foregroundStyle(Theme.muted)
                    }
                }
                Button(content.t("accountSignOut", "Sign out")) { Task { await account.signOut() } }
            }
            .listRowBackground(Theme.card)
        } else if account.checked {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(content.t("accountTitle", "Your account")).font(.headline).foregroundStyle(Theme.ink)
                    Text(content.t("appAccountWhy", "Sign in to make lists of your own, save other people’s, and find the places you saved on the website."))
                        .font(.subheadline).foregroundStyle(Theme.muted)
                    SignInButton()
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Theme.wash)
        }
    }

    private func link(_ title: String, _ icon: String, _ url: URL) -> some View {
        Button { openURL(url) } label: {
            HStack {
                Label(title, systemImage: icon).foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "arrow.up.right").font(.footnote).foregroundStyle(Theme.muted)
            }
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "Tallinn Taste Buds \(v) (\(b))"
    }
}

/// Deleting the account, which App Review asks every app that makes accounts
/// to offer. The site asks for the password once more before it does it.
struct DeleteAccountView: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var confirmation = ""
    @State private var working = false
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(content.t("accountDeleteCosts", "There is no undo. Links to your profile and lists stop working straight away."))
                        .foregroundStyle(Theme.ink)
                }
                Section {
                    SecureField(content.t("accountCurrentPassword", "Current password"), text: $confirmation)
                        .textContentType(.password)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(content.t("appDeleteNoPassword", "An account made with Google and no password: type your username instead."))
                        if let problem { Text(problem).foregroundStyle(Theme.accent) }
                    }
                }
                Section {
                    Button(role: .destructive) {
                        Task { await go() }
                    } label: {
                        HStack {
                            Text(content.t("accountDeleteGo", "Delete for good")).fontWeight(.semibold)
                            if working { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(confirmation.isEmpty || working)
                }
            }
            .paperBackground()
            .navigationTitle(content.t("accountDelete", "Delete account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(content.t("close", "Close")) { dismiss() } }
            }
        }
    }

    private func go() async {
        working = true
        defer { working = false }
        do {
            try await account.delete(confirmation: confirmation)
            dismiss()
        } catch {
            problem = content.say(error)
        }
    }
}
