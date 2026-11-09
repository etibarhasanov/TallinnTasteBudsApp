import SwiftUI

/// Signing in, or making an account: a username and a password, the same two
/// fields the website asks for and nothing more.
struct SignInView: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account
    @Environment(SavesStore.self) private var saves
    @Environment(\.dismiss) private var dismiss

    /// What the sheet was opened for, said over the form: "Sign in to save this list".
    var reason: String?

    @State private var creating = false
    @State private var username = ""
    @State private var password = ""
    @State private var working = false
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            Form {
                if let reason {
                    Section { Text(reason).font(.subheadline).foregroundStyle(Theme.ink) }
                        .listRowBackground(Theme.wash)
                }
                Section {
                    Picker("", selection: $creating) {
                        Text(content.t("accountSignIn", "Sign in")).tag(false)
                        Text(content.t("accountCreate", "Create account")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    TextField(content.t("accountUsername", "Username"), text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField(content.t("accountPassword", "Password"), text: $password)
                        .textContentType(creating ? .newPassword : .password)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if creating {
                            Text(content.t("accountUsernameHint", "3–24 letters or numbers. Shown on lists you share."))
                            Text(content.t("appNoReset", "There’s no reset — let your iPhone save the password."))
                        }
                        if let problem {
                            Text(problem).foregroundStyle(Theme.accent).padding(.top, 2)
                        }
                    }
                }
                Section {
                    Button {
                        Task { await go() }
                    } label: {
                        HStack {
                            Spacer()
                            if working { ProgressView().tint(.white) }
                            Text(creating ? content.t("accountCreate", "Create account") : content.t("accountSignIn", "Sign in"))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(working || username.isEmpty || password.isEmpty)
                    .listRowBackground(Theme.accent.opacity(working || username.isEmpty || password.isEmpty ? 0.45 : 1))
                    .foregroundStyle(.white)
                } footer: {
                    Text(content.t("appGoogleOnSite", "Made your account with Google? Set a password for it on tallinntastebuds.ee, under your account, and sign in here with that."))
                }
            }
            .paperBackground()
            .navigationTitle(creating ? content.t("accountCreate", "Create account") : content.t("accountSignIn", "Sign in"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(content.t("close", "Close")) { dismiss() }
                }
            }
            .onChange(of: creating) { _, _ in problem = nil }
        }
    }

    private func go() async {
        working = true
        problem = nil
        defer { working = false }
        do {
            try await account.enter(username: username.trimmingCharacters(in: .whitespaces),
                                    password: password, create: creating, saves: saves)
            dismiss()
        } catch {
            problem = content.say(error)
        }
    }
}

/// A button that opens the sign-in sheet, for the places a signed-out reader
/// meets something that needs an account.
struct SignInButton: View {
    @Environment(ContentStore.self) private var content
    var reason: String?
    var prominent = true
    @State private var open = false

    var body: some View {
        Group {
            if prominent {
                Button { open = true } label: {
                    Text(content.t("accountSignIn", "Sign in")).fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button(content.t("accountSignIn", "Sign in")) { open = true }
            }
        }
        .sheet(isPresented: $open) { SignInView(reason: reason) }
    }
}
