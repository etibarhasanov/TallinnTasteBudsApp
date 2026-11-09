import SwiftUI

/// Somebody's page: who they are, where else they are, their page of links
/// and every list they published — `/u/<name>` on the website.
struct ProfileView: View {
    @Environment(ContentStore.self) private var content
    @Environment(\.openURL) private var openURL
    let name: String

    @State private var profile: Profile?
    @State private var failed = false
    @State private var gone = false

    var body: some View {
        Group {
            if let profile {
                page(profile)
            } else if gone {
                EmptyNote(title: content.t("appProfileGone", "Nobody by that name"),
                          text: content.t("appProfileGoneSay", "This account does not exist any more."),
                          systemImage: "person.crop.circle.badge.questionmark")
            } else if failed {
                VStack(spacing: 10) {
                    Text(content.t("appOffline", "Couldn’t reach tallinntastebuds.ee.")).foregroundStyle(Theme.muted)
                    Button(content.t("appRetry", "Try again")) { Task { await load() } }
                }
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: API.profileLink(name)) { Image(systemName: "square.and.arrow.up") }
            }
        }
        .task { if profile == nil { await load() } }
    }

    private func page(_ p: Profile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    face(p)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.display ?? p.name).font(.title2.bold()).foregroundStyle(Theme.ink)
                        Text("@" + p.name).font(.subheadline).foregroundStyle(Theme.muted)
                    }
                }
                if let about = p.aboutLine(content.lang) {
                    Text(about).font(.body).foregroundStyle(Theme.ink)
                }
                if !p.links.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(p.links.keys.sorted(), id: \.self) { site in
                            if let handle = p.links[site], let url = Self.link(site, handle) {
                                Button { openURL(url) } label: {
                                    Text(Self.siteName(site)).font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                if !p.lists.isEmpty {
                    SectionLabel(text: content.t("listsTitle", "Lists")).padding(.top, 6)
                    ForEach(p.lists) { list in
                        NavigationLink(value: Route.list(list.id)) { ListCard(list: list) }
                            .buttonStyle(.plain)
                    }
                }

                let rows = p.rows.filter { !$0.url.isEmpty || !$0.note.isEmpty }
                if !rows.isEmpty {
                    SectionLabel(text: content.t("appLinks", "Links")).padding(.top, 6)
                    ForEach(rows, id: \.self) { row in
                        if let url = URL(string: row.url), !row.url.isEmpty {
                            Button { openURL(url) } label: {
                                HStack {
                                    Text(row.title).font(.headline).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Image(systemName: "arrow.up.right").foregroundStyle(Theme.muted)
                                }
                                .card()
                            }
                            .buttonStyle(.plain)
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                if !row.title.isEmpty { Text(row.title).font(.headline).foregroundStyle(Theme.ink) }
                                Text(row.note).font(.subheadline).foregroundStyle(Theme.ink)
                            }
                            .card()
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func face(_ p: Profile) -> some View {
        Group {
            if let path = p.face, let url = API.absolute(path) {
                Photo(url: url)
            } else {
                Theme.wash.overlay(
                    Text(String((p.display ?? p.name).prefix(1)).uppercased())
                        .font(.title.bold()).foregroundStyle(Theme.accent)
                )
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
    }

    private func load() async {
        failed = false
        do {
            let envelope = try await API.get(ProfileEnvelope.self, "api/profile", ["name": name])
            if let p = envelope.profile { profile = p } else { gone = true }
        } catch API.Failure.notFound {
            gone = true
        } catch {
            failed = true
        }
    }

    static func siteName(_ site: String) -> String {
        switch site {
        case "tiktok": return "TikTok"
        case "youtube": return "YouTube"
        case "x", "twitter": return "X"
        default: return site.capitalized
        }
    }

    /// A handle on another site, as a link to it.
    static func link(_ site: String, _ handle: String) -> URL? {
        let h = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle
        if h.hasPrefix("http") { return URL(string: h) }
        switch site {
        case "instagram": return URL(string: "https://www.instagram.com/\(h)")
        case "tiktok": return URL(string: "https://www.tiktok.com/@\(h)")
        case "x", "twitter": return URL(string: "https://x.com/\(h)")
        case "youtube": return URL(string: "https://www.youtube.com/@\(h)")
        case "facebook": return URL(string: "https://www.facebook.com/\(h)")
        default: return nil
        }
    }
}
