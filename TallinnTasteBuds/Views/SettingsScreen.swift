import SwiftUI

/// Language, style, and an honest account of where the content came from.
struct SettingsScreen: View {
    @Binding var style: StylePreference

    @Environment(ContentStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section(store.strings("language")) {
                    Picker(store.strings("language"), selection: languageBinding) {
                        ForEach(store.strings.languages) { language in
                            Text(language.name).tag(language.code)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                .listRowBackground(theme.paper)

                Section(store.app(.appearance)) {
                    Picker(store.app(.appearance), selection: $style) {
                        Text(store.app(.appearanceSystem)).tag(StylePreference.system)
                        Text(store.strings("styleRed")).tag(StylePreference.red)
                        Text(store.strings("styleGreen")).tag(StylePreference.green)
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(theme.paper)

                Section(store.app(.content)) {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        HStack {
                            Text(store.app(.refresh))
                            Spacer()
                            if store.isRefreshing { ProgressView() }
                        }
                    }
                    .disabled(store.isRefreshing)

                    Text(syncLine)
                        .font(.mono(11))
                        .foregroundStyle(theme.muted)

                    if let error = store.lastError {
                        Text(error).font(.mono(11)).foregroundStyle(theme.accent)
                    }

                    Text(store.app(.syncNote))
                        .font(.running(13))
                        .foregroundStyle(theme.muted)
                }
                .listRowBackground(theme.paper)

                Section(store.app(.about)) {
                    Text(store.app(.aboutBody))
                        .font(.running(15))
                        .foregroundStyle(theme.ink)
                    Button(store.strings("instagramHandle")) {
                        openURL(ContentSource.instagramProfile)
                    }
                    Button(store.app(.openWebsite)) {
                        openURL(ContentSource.base)
                    }
                }
                .listRowBackground(theme.paper)
            }
            .scrollContentBackground(.hidden)
            .background(theme.wash)
            .navigationTitle(store.app(.tabSettings))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// Written out rather than derived from `$store` so choosing a language
    /// also persists it, which is the whole reason `select(language:)` exists.
    private var languageBinding: Binding<String> {
        Binding(get: { store.lang }, set: { store.select(language: $0) })
    }

    private var syncLine: String {
        guard let synced = store.lastSynced else { return store.app(.neverSynced) }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return store.app(.upToDate, ["time": formatter.localizedString(for: synced, relativeTo: Date())])
    }
}
